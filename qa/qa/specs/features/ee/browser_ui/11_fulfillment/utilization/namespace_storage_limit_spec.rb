# frozen_string_literal: true

module QA
  RSpec.describe 'Fulfillment', :requires_admin, feature_category: :consumables_cost_management,
    only: { subdomain: :staging },
    feature_flag: { name: 'namespace_storage_limit', scope: :group } do
    describe 'Utilization' do
      include Runtime::Fixtures

      let(:group_paths) do
        %i[
          quality-e2e-tests
          quality-e2e-tests-2
          quality-e2e-tests-3
          quality-e2e-tests-4
          quality-e2e-tests-5
        ]
      end

      let(:admin_api_client) { Runtime::API::Client.as_admin }
      let(:group) do
        Resource::Sandbox.init do |resource|
          resource.api_client = admin_api_client
          resource.path = available_group_path
        end.reload!
      end

      let(:project) do
        create(:project,
          name: "project-#{SecureRandom.hex(8)}",
          group: group
        )
      end

      let(:application_settings_endpoint) do
        QA::Runtime::API::Request.new(admin_api_client, '/application/settings').url
      end

      let(:storage_warning_message) do
        "If #{group.name} exceeds the storage quota, your ability to write new data to this namespace will be " \
          "restricted."
      end

      let(:storage_limit_reached_message) do
        "#{group.name} is now read-only. Your ability to write new data to this namespace is restricted."
      end

      let(:project_test_data) { ['DO NOT MODIFY - Large Project', 'Test Limit'] }

      before do
        cleanup_group_data

        Flow::Login.sign_in

        Runtime::Feature.enable(:namespace_storage_limit, group: group)
        Runtime::Feature.enable(:namespace_storage_limit_show_preenforcement_banner, group: group)
        Runtime::Feature.enable(:reduce_aggregation_schedule_lease, group: group)

        group.visit!

        expect_storage_limit_message(storage_warning_message, 'Warning for storage limit not shown')

        create(:commit,
          project: project,
          commit_message: 'Commit 1B of data',
          actions: [{
            action: 'create',
            file_path: 'file.txt',
            content: '1' * 512
          }])

        put application_settings_endpoint, { namespace_aggregation_schedule_lease_duration_in_seconds: 30 }
      end

      after do
        put application_settings_endpoint, { namespace_aggregation_schedule_lease_duration_in_seconds: 300 }

        begin
          # This is important to have here to revert the namespace back to full-access mode and have it be ready for
          # the next test run
          project.remove_via_api!
        rescue QA::Resource::Errors::ResourceNotDeletedError => e
          # If the error message is because the project doesn't exist, that is expected. If the test passes, the project
          # will already have been deleted as part of the test steps already and this is just a fallback in case
          # something goes wrong and the project doesn't get deleted. Meanwhile, if the error message is something else,
          # we want it to raise the error and fail the test.
          raise e unless e.message.include?('404 Project Not Found')
        end
      end

      context 'when namespace storage usage hits the limit' do
        it(
          'puts the namespace into read-only mode and reverts back to full-access mode after making space',
          quarantine: {
            issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24041',
            type: :investigating
          }
        ) do
          expect_storage_limit_message(storage_limit_reached_message, 'Alert for storage limit exceeded not shown')

          project.remove_via_api!
          group.visit!

          expect_storage_limit_message(storage_warning_message, 'Warning for storage limit not shown')
        end
      end

      def expect_storage_limit_message(message, error_message)
        EE::Page::Alert::StorageLimit.perform do |storage_limit_alert|
          Support::Retrier.retry_until(
            max_duration: 300,
            sleep_interval: 10,
            retry_on_exception: true,
            reload_page: page,
            message: error_message) do
            expect(storage_limit_alert.storage_limit_message).to have_content(message)
          end
        end
      end

      # Guide on how to create a group for this test with the necessary test data can be found in this runbook:
      # https://gitlab.com/gitlab-org/quality/runbooks/-/blob/main/storage-limit-test-data/index.md
      def available_group_path
        group_paths.each do |group_path|
          current_group = Resource::Sandbox.init do |resource|
            resource.api_client = admin_api_client
            resource.path = group_path
          end.reload!

          extra_projects = current_group.projects.select { |project| project_test_data.exclude?(project.name) }

          return group_path.to_s if extra_projects.empty?
        end

        raise "All groups are all either currently in use or has old data that needs to be cleared"
      end

      def cleanup_group_data
        group_paths.each do |group_path|
          current_group = Resource::Sandbox.init do |resource|
            resource.api_client = admin_api_client
            resource.path = group_path
          end.reload!

          current_group.projects.each do |project|
            project.inspect # Forces project attributes to be loaded reliably
            next if project_test_data.include?(project.name)

            # Check if project's created_at timestamp was more than 10 minutes ago
            time_difference = (Time.now.utc - Time.parse(project.created_at)).abs
            project.remove_via_api! if time_difference > 600
          end
        end
      end
    end
  end
end

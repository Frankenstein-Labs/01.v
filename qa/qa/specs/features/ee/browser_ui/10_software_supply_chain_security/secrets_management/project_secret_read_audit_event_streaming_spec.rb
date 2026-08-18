# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    :requires_admin,
    :skip_live_env, # local mock streaming server requires local requests to be enabled
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'

    # Read events are stream-only (saved_to_database: false), so they never reach the audit
    # events table or REST API - they can only be observed at a streaming destination. Project
    # read events are scoped to the project, so an instance-level destination is used to capture
    # them (there is no project-level streaming destination).
    describe 'Project Secret read audit event streaming' do
      let(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(number: 8)}" }
      let(:secret_name) { 'Test' }
      let(:secret_value) { 'my-secret-value-for-ci' }
      let!(:runner) { create(:project_runner, project: project, name: executor, tags: [executor]) }
      let(:pipeline) { create(:pipeline, project: project) }
      let(:warmup_member) { create(:user) }
      let!(:mock_service) { QA::Support::AuditEventStreamingService.new }
      let!(:stream_destination_url) { mock_service.destination_url }

      let(:stream_destination) do
        EE::Resource::InstanceExternalStreamingDestination.fabricate_via_api! do |resource|
          resource.config = { 'url' => stream_destination_url }
        end
      end

      let(:add_ci_file) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              default:
                tags: [#{executor}]

              secrets_manager_job:
                secrets:
                  TEST_SECRET:
                    gitlab_secrets_manager:
                      name: #{secret_name}
                script:
                  - cat $TEST_SECRET
            YAML
          }
        ])
      end

      let(:add_secret) do
        Flow::Login.while_signed_in(as: owner) do
          project.visit!

          Page::Project::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: secret_value,
              description: 'Project secret for read audit streaming test',
              environment: '*',
              branch: 'main'
            )
          end
        end
      end

      before do
        ensure_local_requests_enabled!

        stream_destination.add_filters(%w[secrets_manager_read_project_secret member_created])

        # Confirm streaming is live before relying on the single, expensive pipeline read event.
        mock_service.wait_for_streaming_to_start(event_type: 'member_created', entity_type: 'Project') do
          project.add_member(warmup_member)
        end

        add_secret
        add_ci_file
        pipeline
        wait_for_pipeline
      end

      after do |example|
        mock_service.container_logs if example.exception
        stream_destination.remove_via_api!
        mock_service.teardown!
        runner.remove_via_api!
      end

      it 'streams a read audit event when the project secret is consumed in CI' do
        event_record = mock_service.wait_for_event(
          'secrets_manager_read_project_secret', 'Project', project.full_path, wait: 60
        )

        expect(event_record[:body]).to include(
          event_type: 'secrets_manager_read_project_secret',
          entity_type: 'Project',
          entity_path: project.full_path
        )
      end

      private

      def wait_for_pipeline
        Support::Waiter.wait_until(max_duration: 180, sleep_interval: 5) do
          pipelines = project.pipelines
          pipelines.present? && %w[success failed].include?(pipelines.first[:status])
        end

        project.pipelines.first
      end

      def ensure_local_requests_enabled!
        Runtime::ApplicationSettings.set_application_settings(
          allow_local_requests_from_web_hooks_and_services: true
        )

        QA::Support::Retrier.retry_until(
          max_duration: 10,
          sleep_interval: 1,
          message: 'Waiting for local requests setting to be enabled'
        ) do
          Runtime::ApplicationSettings.get_application_setting(
            :allow_local_requests_from_web_hooks_and_services
          ) == true
        end
      end
    end
  end
end

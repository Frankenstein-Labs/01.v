# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :requires_admin,
    :skip_live_env, # We need to enable local requests to use a local mock streaming server
    feature_category: :compliance_management
  ) do
    describe 'Instance audit event streaming' do
      let!(:mock_service) { QA::Support::AuditEventStreamingService.new }
      let!(:stream_destination_url) { mock_service.destination_url }

      let(:target_details) { entity_path }
      let(:event_types) do
        %w[remove_ssh_key group_created project_created user_created repository_git_operation
          application_setting_updated]
      end

      let(:headers) do
        {
          'Test-Header1': 'instance event streaming',
          'Test-Header2': 'destination via api'
        }
      end

      let(:stream_destination) do
        EE::Resource::InstanceExternalStreamingDestination.fabricate_via_api! do |resource|
          resource.config = { 'url' => stream_destination_url }
        end
      end

      before do
        ensure_local_requests_enabled!
        stream_destination.add_headers(headers)
        stream_destination.add_filters(event_types)

        mock_service.wait_for_streaming_to_start(event_type: 'remove_ssh_key', entity_type: 'User') do
          Resource::SSHKey.fabricate_via_api!.remove_via_api!
        end
      end

      after do |example|
        stream_destination.remove_via_api!

        mock_service.container_logs if example.exception
        mock_service.teardown!
      end

      context 'when a group is created' do
        let(:entity_path) { create(:group).full_path }

        include_examples 'streamed events', 'group_created', 'Group'
      end

      context 'when a project is created', quarantine: {
        type: :investigating,
        issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24034'
      } do
        # Create a group first so its audit event is streamed before we check for the create project event
        let!(:group) { create(:group) }
        let(:entity_path) { create(:project, group: group).full_path }

        include_examples 'streamed events', 'project_created', 'Project'
      end

      context 'when a user is created', quarantine: {
        type: :investigating,
        issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24034'
      } do
        let(:entity_path) { create(:user).username }

        include_examples 'streamed events', 'user_created', 'User'
      end

      context 'when a repository is cloned via SSH' do
        # Create the project and key first so their audit events are streamed before we check for the clone event
        let!(:key) { Resource::SSHKey.fabricate_via_api! }
        let!(:project) { create(:project, :with_readme) }

        # Clone the repo via SSH and then use the project path and name to confirm the event details
        let(:target_details) { project.name }
        let(:entity_path) do
          Git::Repository.perform do |repository|
            repository.uri = project.repository_ssh_location.uri
            repository.use_ssh_key(key)
            repository.clone
          end

          project.full_path
        end

        include_examples 'streamed events', 'repository_git_operation', 'Project'

        it 'is streamed but not persisted to the database' do
          started_at = DateTime.now.iso8601
          entity_path # trigger the clone

          # Observing the streamed event is a sufficient fence: the Auditor writes to the database
          # (when applicable) synchronously before the streaming worker is enqueued, so once the
          # event has streamed any database write would already be committed.
          mock_service.wait_for_event('repository_git_operation', 'Project', project.full_path)

          persisted = EE::Resource::AuditEvents.all(entity_type: 'Project', created_after: started_at)
          matching = persisted.select do |event|
            event[:entity_id] == project.id &&
              event.dig(:details, :event_name) == 'repository_git_operation'
          end

          expect(matching).to be_empty,
            "Expected stream-only 'repository_git_operation' not to be persisted, but the audit " \
              "events API returned: #{matching}"
        end
      end

      context 'when an instance-level setting is changed' do
        # default_projects_limit is a global setting; restore it so it doesn't leak to later tests
        let(:original_limit) { Runtime::ApplicationSettings.get_application_setting(:default_projects_limit).to_i }

        after do
          Runtime::ApplicationSettings.set_application_settings(default_projects_limit: original_limit)
        end

        it 'streams the instance-scoped audit event' do
          Runtime::ApplicationSettings.set_application_settings(default_projects_limit: original_limit + 1)

          event = mock_service.wait_for_event('application_setting_updated', 'Gitlab::Audit::InstanceScope')

          expect(event.dig(:body, :details, :change)).to eq('default_projects_limit')
        end
      end

      context 'when multiple destinations are configured' do
        let!(:second_mock_service) { QA::Support::AuditEventStreamingService.new }
        let(:second_stream_destination) do
          EE::Resource::InstanceExternalStreamingDestination.fabricate_via_api! do |resource|
            resource.config = { 'url' => second_mock_service.destination_url }
          end
        end

        let(:entity_path) { create(:group).full_path }

        before do
          second_stream_destination.add_filters(event_types)

          second_mock_service.wait_for_streaming_to_start(event_type: 'remove_ssh_key', entity_type: 'User') do
            Resource::SSHKey.fabricate_via_api!.remove_via_api!
          end
        end

        after do |example|
          second_stream_destination.remove_via_api!
          second_mock_service.container_logs if example.exception
          second_mock_service.teardown!
        end

        it 'streams the event to every configured destination' do
          group_path = entity_path

          first_event = mock_service.wait_for_event('group_created', 'Group', group_path)
          second_event = second_mock_service.wait_for_event('group_created', 'Group', group_path)

          # Both destinations must receive the same event
          event_id = first_event.dig(:body, :id)
          expect(event_id).to be_present
          expect(second_event.dig(:body, :id)).to eq(event_id)
        end
      end

      context 'when a namespace filter is configured' do
        let(:filtered_group) { create(:group) }
        let(:other_group) { create(:group) }

        before do
          stream_destination.add_namespace_filters([filtered_group.full_path])
        end

        it 'streams only events within the filtered namespace' do
          # out_of_scope is created first so it fences the negative check: once the in_scope event
          # streams, out_of_scope would have streamed too were it not filtered out
          out_of_scope = create(:group, sandbox: other_group).full_path
          in_scope = create(:group, sandbox: filtered_group).full_path

          mock_service.wait_for_event('group_created', 'Group', in_scope)

          expect(
            mock_service.wait_for_event('group_created', 'Group', out_of_scope, wait: 5, raise_on_failure: false)
          ).to be_nil
        end
      end

      context 'when an event type filter is configured' do
        # Filter to a subset; application_setting_updated is deliberately excluded
        let(:event_types) { %w[remove_ssh_key group_created] }
        # default_projects_limit is a global setting; restore it so it doesn't leak to later tests
        let(:original_limit) { Runtime::ApplicationSettings.get_application_setting(:default_projects_limit).to_i }

        after do
          Runtime::ApplicationSettings.set_application_settings(default_projects_limit: original_limit)
        end

        it 'drops event types that are not in the filter' do
          # application_setting_updated is not in the filter; group_created is and fences the check
          Runtime::ApplicationSettings.set_application_settings(default_projects_limit: original_limit + 1)
          fenced_group = create(:group).full_path

          mock_service.wait_for_event('group_created', 'Group', fenced_group)

          expect(
            mock_service.wait_for_event('application_setting_updated', 'Gitlab::Audit::InstanceScope',
              wait: 5, raise_on_failure: false)
          ).to be_nil
        end
      end

      private

      # Ensure local requests are enabled before each test example.
      # This is called in before(:each) rather than before(:context) to handle cases where
      # the setting may be reset by other tests or environment changes during parallel execution.
      #
      # @return [void]
      def ensure_local_requests_enabled!
        QA::Runtime::Logger.info("Ensuring local requests are enabled for audit event streaming test")

        Runtime::ApplicationSettings.set_application_settings(
          allow_local_requests_from_web_hooks_and_services: true
        )

        # Verify the setting was actually applied to avoid race conditions
        QA::Support::Retrier.retry_until(
          max_duration: 10,
          sleep_interval: 1,
          message: 'Waiting for local requests setting to be enabled'
        ) do
          Runtime::ApplicationSettings.get_application_setting(
            :allow_local_requests_from_web_hooks_and_services
          ) == true
        end
      rescue StandardError => e
        QA::Runtime::Logger.error("Failed to enable local requests: #{e.message}")
        raise
      end
    end
  end
end

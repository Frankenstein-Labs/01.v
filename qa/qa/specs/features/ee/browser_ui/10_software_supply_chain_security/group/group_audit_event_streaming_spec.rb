# frozen_string_literal: true

# The mock service can cause flakiness if it's started and stopped for each test, so we create it once before
# all tests and access it via an instance variable
module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :requires_admin,
    :skip_live_env, # We need to enable local requests to use a local mock streaming server
    # and we can't create top-level groups in the paid tier on production
    feature_category: :compliance_management
  ) do
    describe 'Group audit event streaming' do
      let(:root_group) { create(:sandbox) }
      let!(:mock_service) { QA::Support::AuditEventStreamingService.new }
      let!(:stream_destination_url) { mock_service.destination_url }

      before do
        ensure_local_requests_enabled!
      end

      after do |example|
        mock_service.container_logs if example.exception
        mock_service.teardown!
      end

      context 'with no destination' do
        let(:event_types) { %w[create_compliance_framework] }
        let(:headers) do
          {
            'Test-Header1': 'event streaming',
            'Test-Header2': 'group destination via ui'
          }
        end

        it(
          'adds a streaming destination'
        ) do
          Flow::Login.sign_in
          root_group.visit!
          Page::Group::Menu.perform(&:go_to_audit_events)

          created_destination_name = 'Smocker'

          EE::Page::Group::Secure::AuditEvents.perform do |audit_events|
            audit_events.click_streams_tab
            audit_events.add_streaming_destination(created_destination_name, stream_destination_url)

            expect(audit_events).to have_stream_destination(created_destination_name)
          end

          # Fetch the created destination via API to add headers and filters
          stream_destination = EE::Resource::GroupExternalStreamingDestination.find_by_name(
            group: root_group,
            name: created_destination_name
          )

          expect(stream_destination).not_to be_nil
          expect(stream_destination.secret_token).not_to be_nil

          stream_destination.add_headers(headers)
          stream_destination.add_filters(event_types)

          # We add a compliance framework to the group as a way to generate a streamed audit event so that we can
          # confirm that the mock service is ready to receive events.
          event_record = mock_service.wait_for_streaming_to_start(
            event_type: 'create_compliance_framework',
            entity_type: 'Group'
          ) do
            EE::Resource::ComplianceFramework.fabricate_via_api! do |framework|
              framework.group = root_group
            end.remove_via_api!
          end

          verify_response = mock_service.verify
          aggregate_failures do
            # Smocker treats header values as arrays
            # Secret tokens are created automatically for HTTP destinations
            expect(event_record[:headers]).to include(
              headers.transform_keys { |k| k.to_s.tr('_', '-').to_sym }
                .transform_values { |v| [v] }
                .merge("X-Gitlab-Event-Streaming-Token": [stream_destination.secret_token])
            )
            expect(verify_response).to be_success,
              "Failures when verifying events received:\n#{JSON.pretty_generate(verify_response.failures)}"
          end

          stream_destination.remove_via_api!
        end
      end

      context 'with a destination configured' do
        let(:target_details) { entity_path }
        let(:event_types) { %w[create_compliance_framework group_created project_group_link_created member_created] }
        let(:headers) do
          {
            'Test-Header1': 'test-header-value1',
            'Test-Header2': 'test-header-value2'
          }
        end

        let(:stream_destination) do
          EE::Resource::GroupExternalStreamingDestination.fabricate_via_api! do |resource|
            resource.config = { 'url' => stream_destination_url }
            resource.group = root_group
          end
        end

        before do
          stream_destination.add_headers(headers)
          stream_destination.add_filters(event_types)

          # We add a compliance framework to the group as a way to generate a streamed audit event so that we can
          # confirm that the mock service is ready to receive events.
          mock_service.wait_for_streaming_to_start(
            event_type: 'create_compliance_framework',
            entity_type: 'Group'
          ) do
            EE::Resource::ComplianceFramework.fabricate_via_api! do |framework|
              framework.group = root_group
            end.remove_via_api!
          end
        end

        after do
          stream_destination.remove_via_api!
        end

        context 'when a group is created' do
          let(:entity_path) do
            create(:group,
              sandbox: root_group,
              name: "audit-event-streaming-#{Faker::Alphanumeric.alphanumeric(number: 8)}").full_path
          end

          include_examples 'streamed events', 'group_created', 'Group'
        end

        context 'when a project is shared with a group' do
          let(:project) { create(:project) }
          let(:target_details) { project.full_path }
          let(:entity_path) { root_group.full_path }

          before do
            project.invite_group(root_group)
          end

          include_examples 'streamed events', 'project_group_link_created', 'Group'
        end

        context 'when a user is added to a group' do
          let(:user) { create(:user) }
          let(:target_details) { user.name }
          let(:entity_path) { root_group.full_path }

          before do
            root_group.add_member(user)
          end

          include_examples 'streamed events', 'member_created', 'Group'
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

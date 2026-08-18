# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::UsageData, feature_category: :service_ping do
  let_it_be_with_reload(:personal_namespace) { create(:namespace) }
  let_it_be_with_reload(:user) do
    create(:user, namespace: personal_namespace, organizations: [personal_namespace.organization])
  end

  describe 'POST /usage_data/track_event' do
    let(:endpoint) { '/usage_data/track_event' }
    let(:project) { nil }
    let(:namespace) { nil }

    shared_examples 'ai event endpoint' do
      let(:additional_properties) do
        {
          unique_tracking_id: "abc",
          suggestion_size: 100,
          language: 'ruby',
          timestamp: 1.month.ago.to_s,
          branch_name: 'foo',
          ide_name: 'IDE',
          ide_vendor: 'Vendor',
          ide_version: '1.2.3',
          extension_name: 'extension',
          extension_version: '2.3.4',
          language_server_version: '3.4.5',
          model_name: 'ModelName',
          model_engine: 'ModelEngine'
        }
      end

      before do
        stub_application_setting(usage_ping_enabled: true, use_clickhouse_for_analytics: true)
      end

      def expect_track_events
        expect(Gitlab::InternalEvents).to receive(:track_event)
          .with(
            event_name,
            additional_properties: additional_properties,
            project: project,
            namespace: namespace,
            user: user,
            send_snowplow_event: false
          ).and_call_original

        # rubocop:disable RSpec/ExpectGitlabTracking -- Need to verify Snowplow params directly here
        expect(Gitlab::Tracking).not_to receive(:event).with(anything, event_name, anything)
        # rubocop:enable RSpec/ExpectGitlabTracking
      end

      def assert_db_events
        UsageEvents::DumpWriteBufferCronWorker.new.perform
        ClickHouse::DumpWriteBufferWorker.new.perform(Ai::UsageEvent.clickhouse_table_name)
        expect(Ai::UsageEvent.first.attributes).to match(hash_including(expected_pg_event))
        expect(ClickHouse::Client.select("SELECT * FROM #{Ai::UsageEvent.clickhouse_table_name}", :main).first)
          .to match(hash_including(expected_ch_event))
      end

      def make_request
        post api(endpoint, user), as: :json, params: {
          event: event_name,
          project_id: project&.id,
          namespace_id: namespace&.id,
          additional_properties: additional_properties
        }
      end

      let(:expected_pg_event) do
        {
          user_id: user.id,
          event: event_name,
          timestamp: DateTime.parse(additional_properties[:timestamp]),
          namespace_id: project&.reload&.project_namespace&.id || namespace&.id,
          extras: additional_properties.except(:timestamp),
          organization_id: personal_namespace.organization&.id
        }.with_indifferent_access
      end

      let(:expected_ch_event) do
        {
          user_id: user.id,
          event: Ai::UsageEvent.events[event_name],
          timestamp: DateTime.parse(additional_properties[:timestamp]),
          namespace_path: project&.reload&.project_namespace&.traversal_path(with_organization: false) ||
            namespace&.traversal_path(with_organization: false) || '0/',
          extras: additional_properties.except(:timestamp).to_json
        }.with_indifferent_access
      end

      it 'triggers AI tracking without project or namespace' do
        expect_track_events
        make_request
        expect(response).to have_gitlab_http_status(:ok)
        assert_db_events
      end

      context 'when project is passed' do
        let_it_be(:project) { create(:project) }

        it 'triggers AI tracking with project' do
          expect_track_events
          make_request
          expect(response).to have_gitlab_http_status(:ok)
          assert_db_events
        end
      end

      context 'when namespace is passed' do
        let_it_be(:namespace) { create(:namespace) }

        it 'triggers AI tracking with namespace' do
          expect_track_events
          make_request
          expect(response).to have_gitlab_http_status(:ok)
          assert_db_events
        end
      end

      context 'when both project and namespace are passed' do
        let_it_be(:project) { create(:project) }
        let_it_be(:namespace) { create(:namespace) }

        it 'triggers AI tracking with both project and namespace' do
          expect_track_events
          make_request
          expect(response).to have_gitlab_http_status(:ok)
          assert_db_events
        end
      end
    end

    %w[code_suggestion_shown_in_ide
      code_suggestion_accepted_in_ide
      code_suggestion_rejected_in_ide].each do |event|
      context "for #{event} event", :click_house do
        let(:event_name) { event }

        it_behaves_like 'ai event endpoint'
      end
    end
  end
end

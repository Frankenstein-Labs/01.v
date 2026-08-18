# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::AgentPlatform::EventCountService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(
      current_user,
      namespace: container,
      from: from,
      to: to,
      fields: fields,
      **extra_params
    ).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:project_namespace) { project.reload.project_namespace }
  let_it_be(:user1) { create(:user, developer_of: group) }
  let_it_be(:user2) { create(:user, developer_of: group) }

  let(:current_user) { user1 }
  let(:from) { Time.current }
  let(:to) { Time.current }
  let(:fields) { [] }
  let(:extra_params) { {} }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'common ai usage rate service' do
    # This shared examples requires the following variables
    # :expected_results
    # :expected_language_filtered_results

    context 'when the clickhouse is not available for analytics' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(container).and_return(false)
      end

      it 'returns service error' do
        expect(service_response).to be_error

        message = s_('AiAnalytics|the ClickHouse data store is not available')
        expect(service_response.message).to eq(message)
      end
    end

    context 'when the feature is available', :click_house, :freeze_time do
      let(:from) { 5.days.ago }
      let(:to) { 1.day.ago }

      context 'with only few fields selected' do
        let(:fields) { %i[created_session_event_count foo] }
        let(:extra_params) { {} }

        before do
          clickhouse_fixture(:ai_usage_events, [
            {
              user_id: user1.id,
              namespace_path: project_namespace.traversal_path(with_organization: false),
              event: 8, # created
              extras: {
                session_id: 1,
                flow_type: 'chat',
                project_id: project.id,
                environment: 'production'
              }.to_json,
              timestamp: to - 1.day
            }
          ]
          )
        end

        it 'calculates only valid fields' do
          service_response.payload

          expect(service_response.payload).to match({ created_session_event_count: 1 })
        end
      end

      context 'with no selected fields' do
        let(:fields) { [] }

        it 'returns empty stats hash' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq({})
        end
      end

      context 'with data' do
        let(:fields) { described_class::FIELDS }

        include_context 'with ai agent platform events'

        it 'returns AI usage events counts' do
          expect(service_response).to be_success

          expect(service_response.payload).to eq(expected_results)
        end
      end
    end
  end

  context 'for group' do
    let_it_be(:container) { group }

    let(:expected_results) do
      {
        created_session_event_count: 6,
        started_session_event_count: 6,
        finished_session_event_count: 5,
        dropped_session_event_count: 1,
        resumed_session_event_count: 0,
        stopped_session_event_count: 0
      }
    end

    it_behaves_like 'common ai usage rate service'

    context 'with optional filters' do
      context 'for flow type' do
        let(:extra_params) { { flow_types: ['chat'] } }

        let(:expected_results) do
          {
            created_session_event_count: 3,
            started_session_event_count: 3,
            finished_session_event_count: 3,
            dropped_session_event_count: 0,
            resumed_session_event_count: 0,
            stopped_session_event_count: 0
          }
        end

        it_behaves_like 'common ai usage rate service'
      end

      context 'for negated flow type' do
        let(:extra_params) { { not: { flow_types: ['chat'] } } }

        let(:expected_results) do
          {
            created_session_event_count: 3,
            started_session_event_count: 3,
            finished_session_event_count: 2,
            dropped_session_event_count: 1,
            resumed_session_event_count: 0,
            stopped_session_event_count: 0
          }
        end

        it_behaves_like 'common ai usage rate service'
      end
    end
  end

  context 'for project' do
    let_it_be(:container) { project.project_namespace.reload }

    let(:expected_results) do
      {
        created_session_event_count: 2,
        started_session_event_count: 2,
        finished_session_event_count: 2,
        dropped_session_event_count: 0,
        resumed_session_event_count: 0,
        stopped_session_event_count: 0
      }
    end

    it_behaves_like 'common ai usage rate service'
  end
end

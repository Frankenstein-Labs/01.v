# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::AgentPlatform::FlowMetricsService, feature_category: :value_stream_management do
  using RSpec::Parameterized::TableSyntax

  subject(:service_response) do
    described_class.new(
      current_user,
      namespace: container,
      from: from,
      to: to,
      fields: fields,
      **optional_params
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
  let(:optional_params) { {} }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'a service which returns data', :click_house do
    let(:fields) { described_class::FIELDS }

    before do
      clickhouse_fixture(:ai_usage_events, [
        # Session 1 - chat flow - created event
        {
          user_id: user1.id,
          namespace_path: group.traversal_path(with_organization: false),
          event: 8, # created
          extras: {
            session_id: 1,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 10.seconds
        },
        # Session 1 - chat flow - started event
        {
          user_id: user1.id,
          namespace_path: group.traversal_path(with_organization: false),
          event: 9, # started
          extras: {
            session_id: 1,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 20.seconds
        },
        # Session 1 - chat flow - finished event
        {
          user_id: user1.id,
          namespace_path: group.traversal_path(with_organization: false),
          event: 19, # finished
          extras: {
            session_id: 1,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 30.seconds
        },

        # Session 2 - fix_pipeline flow - created event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 8, # created
          extras: {
            session_id: 2,
            flow_type: 'fix_pipeline',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: to - 3.days
        },
        # Session 2 - fix_pipeline flow - started event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 9, # started
          extras: {
            session_id: 2,
            flow_type: 'fix_pipeline',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: (to - 3.days) + 10.seconds
        },
        # Session 2 - fix_pipeline flow - finished event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 19, # finished
          extras: {
            session_id: 2,
            flow_type: 'fix_pipeline',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: to - 2.days
        },

        # Session 3 - fix_pipeline flow - created event
        {
          user_id: user1.id,
          namespace_path: group.traversal_path(with_organization: false),
          event: 8, # created
          extras: {
            session_id: 3,
            flow_type: 'fix_pipeline',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: to - 2.days
        },
        # Session 3 - fix_pipeline flow - started event
        {
          user_id: user1.id,
          namespace_path: group.traversal_path(with_organization: false),
          event: 9, # started
          extras: {
            session_id: 3,
            flow_type: 'fix_pipeline',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: (to - 2.days) + 5.seconds
        },
        # Session 3 - fix_pipeline flow - dropped event (no finished)
        {
          user_id: user1.id,
          namespace_path: group.traversal_path(with_organization: false),
          event: 20, # dropped
          extras: {
            session_id: 3,
            flow_type: 'fix_pipeline',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: (to - 2.days) + 30.seconds
        },

        # Session 4 - code_review flow - created event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 8, # created
          extras: {
            session_id: 4,
            flow_type: 'code_review',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: to - 2.days
        },
        # Session 4 - code_review flow - started event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 9, # started
          extras: {
            session_id: 4,
            flow_type: 'code_review',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: (to - 2.days) + 3.seconds
        },
        # Session 4 - code_review flow - finished event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 19, # finished
          extras: {
            session_id: 4,
            flow_type: 'code_review',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: (to - 2.days) + 120.seconds
        },

        # Session 5 - code_review flow - outside timeframe - created event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 8, # created
          extras: {
            session_id: 5,
            flow_type: 'code_review',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: to - 6.days
        },
        # Session 5 - code_review flow - started event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 9, # started
          extras: {
            session_id: 5,
            flow_type: 'code_review',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: (to - 6.days) + 5.seconds
        },
        # Session 5 - code_review flow - finished event
        {
          user_id: user2.id,
          namespace_path: project_namespace.traversal_path(with_organization: false),
          event: 19, # finished
          extras: {
            session_id: 5,
            flow_type: 'code_review',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: (to - 6.days) + 90.seconds
        },

        # Session 6 - chat flow in subgroup - created event
        {
          user_id: user1.id,
          namespace_path: subgroup.traversal_path(with_organization: false),
          event: 8, # created
          extras: {
            session_id: 6,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 10.seconds
        },
        # Session 6 - chat flow in subgroup - started event
        {
          user_id: user1.id,
          namespace_path: subgroup.traversal_path(with_organization: false),
          event: 9, # started
          extras: {
            session_id: 6,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 20.seconds
        },
        # Session 6 - chat flow in subgroup - finished event
        {
          user_id: user1.id,
          namespace_path: subgroup.traversal_path(with_organization: false),
          event: 19, # finished
          extras: {
            session_id: 6,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 40.seconds
        },
        # Session 7 - chat flow in subgroup - created event
        {
          user_id: user1.id,
          namespace_path: subgroup.traversal_path(with_organization: false),
          event: 8, # created
          extras: {
            session_id: 7,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 10.seconds
        },
        # Session 7 - chat flow in subgroup - started event
        {
          user_id: user1.id,
          namespace_path: subgroup.traversal_path(with_organization: false),
          event: 9, # started
          extras: {
            session_id: 7,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 15.seconds
        },
        # Session 7 - chat flow in subgroup - finished event
        {
          user_id: user1.id,
          namespace_path: subgroup.traversal_path(with_organization: false),
          event: 19, # finished
          extras: {
            session_id: 7,
            flow_type: 'chat',
            project_id: project.id,
            environment: 'production'
          }.to_json,
          timestamp: from + 1.day
        }
      ])
    end

    it 'returns AI usage events counts' do
      expect(service_response).to be_success

      expect(service_response.payload).to eq(expected_results)
    end
  end

  shared_examples 'common ai usage rate service' do
    # This shared examples requires the following variables
    # :expected_results

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
        let(:fields) { %i[sessions_count foo] }

        before do
          clickhouse_fixture(:ai_usage_events, [
            # Session 1 - chat flow - created event
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

          expect(service_response.payload).to match([{ "sessions_count" => 1 }])
        end
      end

      context 'with no selected fields' do
        let(:fields) { [] }

        it 'returns empty stats hash' do
          expect(service_response).to be_success
          expect(service_response.payload).to eq([])
        end
      end

      context 'with data' do
        let(:fields) { described_class::FIELDS }

        include_context 'with ai agent platform events'

        it 'returns AI usage events counts' do
          expect(service_response).to be_success

          expect(service_response.payload).to match_array(expected_results)
        end
      end
    end
  end

  context 'for group' do
    let_it_be(:container) { group }

    let_it_be(:result_1) do
      {
        'flow_type' => 'chat',
        'sessions_count' => 3,
        'median_execution_time' => 20,
        'users_count' => 1,
        'completion_rate' => 100
      }
    end

    let_it_be(:result_2) do
      {
        'flow_type' => 'code_review',
        'sessions_count' => 1,
        'median_execution_time' => 117,
        'users_count' => 1,
        'completion_rate' => 100
      }
    end

    let_it_be(:result_3) do
      {
        'flow_type' => 'fix_pipeline',
        'sessions_count' => 2,
        'median_execution_time' => 86390,
        'users_count' => 2,
        'completion_rate' => 50
      }
    end

    let(:expected_results) do
      [result_1, result_2, result_3] # Default order by flow_type
    end

    it_behaves_like 'common ai usage rate service'

    context 'when sorting' do
      let(:from) { 5.days.ago }
      let(:to) { 1.day.ago }

      using RSpec::Parameterized::TableSyntax
      where(:sort_param, :result) do
        :sessions_count_asc  | lazy { [result_2, result_3, result_1] }
        :sessions_count_desc | lazy { [result_1, result_3, result_2] }
        :users_count_asc     | lazy { [result_1, result_2, result_3] }
        :users_count_desc    | lazy { [result_3, result_1, result_2] }
        :median_time_asc     | lazy { [result_1, result_2, result_3] }
        :median_time_desc    | lazy { [result_3, result_2, result_1] }
      end
      with_them do
        let(:optional_params) { { sort: sort_param } }
        let(:expected_results) { result }

        it_behaves_like 'a service which returns data'
      end
    end
  end

  context 'for project' do
    let_it_be(:container) { project.project_namespace.reload }

    let(:expected_results) do
      [
        {
          'flow_type' => 'code_review',
          'sessions_count' => 1,
          'median_execution_time' => 117,
          'users_count' => 1,
          'completion_rate' => 100
        },
        {
          'flow_type' => 'fix_pipeline',
          'sessions_count' => 1,
          'median_execution_time' => 86390,
          'users_count' => 1,
          'completion_rate' => 100
        }
      ]
    end

    it_behaves_like 'common ai usage rate service'
  end
end

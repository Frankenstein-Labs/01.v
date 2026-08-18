# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying aiGovernanceMetrics', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  # :read_agent_artifacts is a custom ability granted via member roles (requires
  # the custom_roles license), mirroring the duoWorkflowSessionArtifacts field on
  # the same dashboard. A group-level role cascades to the group's projects.
  let_it_be(:member_role) { create(:member_role, :guest, :read_agent_artifacts, namespace: group) }
  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:group_membership) do
    create(:group_member, :guest, member_role: member_role, user: authorized_user, group: group)
  end

  let_it_be(:unauthorized_user) { create(:user) }

  # 2 current-window sessions (same definition, so agents < sessions), 1
  # previous-window session, and 1 chat session excluded from every metric.
  let_it_be(:current_session_1) do
    create(:duo_workflows_workflow, project: project, user: authorized_user,
      workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 1, 10))
  end

  let_it_be(:current_session_2) do
    create(:duo_workflows_workflow, project: project, user: authorized_user,
      workflow_definition: 'software_development', created_at: Time.utc(2026, 7, 1, 12))
  end

  let_it_be(:previous_session) do
    create(:duo_workflows_workflow, project: project, user: authorized_user,
      workflow_definition: 'software_development', created_at: Time.utc(2026, 6, 20))
  end

  let_it_be(:excluded_chat_session) do
    create(:duo_workflows_workflow, project: project, user: authorized_user,
      workflow_definition: 'chat', created_at: Time.utc(2026, 7, 1))
  end

  let(:timeframe) { :LAST_7_DAYS }

  let(:metrics_fields) do
    <<~FIELDS
      sessions { count previousCount trend { bucketStart count } }
      agents { count previousCount trend { bucketStart count } }
    FIELDS
  end

  before do
    stub_licensed_features(
      custom_roles: true,
      group_level_compliance_dashboard: true,
      project_level_compliance_dashboard: true
    )
  end

  around do |example|
    travel_to(Time.utc(2026, 7, 3, 15, 30)) { example.run }
  end

  shared_examples 'an aiGovernanceMetrics field' do
    let(:query_args) { { timeframe: timeframe } }

    let(:query) do
      graphql_query_for(parent_type, { full_path: container.full_path },
        query_graphql_field(:ai_governance_metrics, query_args, metrics_fields))
    end

    let(:metrics) { graphql_data_at(parent_type, :ai_governance_metrics) }

    context 'when the user is authorized and the feature flag is enabled' do
      it 'returns session and agent KPIs from the PostgreSQL path', :aggregate_failures do
        post_graphql(query, current_user: authorized_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil
        expect(metrics['sessions']).to include('count' => 2, 'previousCount' => 1)
        expect(metrics['agents']).to include('count' => 1, 'previousCount' => 1)
      end

      context 'with an explicit INTERNAL_DAP agentClass' do
        let(:query_args) { { timeframe: timeframe, agent_class: :INTERNAL_DAP } }

        it 'returns the same KPIs as the default (ALL) today', :aggregate_failures do
          post_graphql(query, current_user: authorized_user)

          expect(graphql_errors).to be_nil
          expect(metrics['sessions']).to include('count' => 2, 'previousCount' => 1)
          expect(metrics['agents']).to include('count' => 1, 'previousCount' => 1)
        end
      end

      context 'with an EXTERNAL agentClass' do
        let(:query_args) { { timeframe: timeframe, agent_class: :EXTERNAL } }

        it 'returns zero counts with a full bucket-shaped trend', :aggregate_failures do
          post_graphql(query, current_user: authorized_user)

          expect(graphql_errors).to be_nil
          expect(metrics['sessions']).to include('count' => 0, 'previousCount' => 0)
          expect(metrics['agents']).to include('count' => 0, 'previousCount' => 0)

          trend = metrics.dig('sessions', 'trend')
          # 8 day-aligned buckets, every one present and zero-filled.
          expect(trend.length).to eq(8)
          expect(trend).to all(include('count' => 0))
        end
      end

      context 'with external sessions present' do
        # Three agent types in one environment, plus a repeat of the first type
        # in a different environment. Keyed on agent_type that is 3 instances;
        # keyed on environment it would be 2, so the counts discriminate.
        let_it_be(:external_sessions) do
          [
            ['claude_code', :ide],
            ['opencode', :ide],
            ['cursor', :ide],
            ['claude_code', :ambient]
          ].each_with_index.map do |(agent_type, environment), index|
            create(:duo_workflows_workflow, project: project, user: authorized_user,
              agent_type: agent_type, environment: environment,
              workflow_definition: 'software_development',
              created_at: Time.utc(2026, 7, 1, 13 + index))
          end
        end

        context 'with an EXTERNAL agentClass' do
          let(:query_args) { { timeframe: timeframe, agent_class: :EXTERNAL } }

          it 'counts external sessions and keys their agents on agent_type', :aggregate_failures do
            post_graphql(query, current_user: authorized_user)

            expect(graphql_errors).to be_nil
            expect(metrics['sessions']).to include('count' => 4, 'previousCount' => 0)
            # claude_code, opencode and cursor. The second claude_code session is
            # the same agent instance even though its environment differs.
            expect(metrics['agents']).to include('count' => 3, 'previousCount' => 0)
          end
        end

        context 'with an INTERNAL_DAP agentClass' do
          let(:query_args) { { timeframe: timeframe, agent_class: :INTERNAL_DAP } }

          it 'excludes external sessions', :aggregate_failures do
            post_graphql(query, current_user: authorized_user)

            expect(metrics['sessions']).to include('count' => 2, 'previousCount' => 1)
            expect(metrics['agents']).to include('count' => 1, 'previousCount' => 1)
          end
        end

        it 'partitions agents so that ALL equals INTERNAL_DAP plus EXTERNAL', :aggregate_failures do
          post_graphql(query, current_user: authorized_user)

          expect(metrics['sessions']).to include('count' => 6)
          expect(metrics['agents']).to include('count' => 4)
        end
      end

      it 'returns a full-length zero-filled trend for the timeframe', :aggregate_failures do
        post_graphql(query, current_user: authorized_user)

        trend = metrics.dig('sessions', 'trend')

        # 8 day-aligned buckets from 2026-06-26 through 2026-07-03 (inclusive endpoints).
        expect(trend.length).to eq(8)
        expect(trend.sum { |point| point['count'] }).to eq(2)
      end

      context 'with a LAST_24_HOURS timeframe' do
        let(:timeframe) { :LAST_24_HOURS }

        it 'accepts the argument and returns hourly buckets' do
          post_graphql(query, current_user: authorized_user)

          # 25 hour-aligned buckets from 2026-07-02 15:00 through 2026-07-03 15:00 (inclusive).
          expect(metrics.dig('sessions', 'trend').length).to eq(25)
        end
      end
    end

    context 'when the metrics service fails' do
      before do
        allow_next_instance_of(::Ai::Governance::MetricsService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'backend unavailable'))
        end
      end

      it 'returns null rather than an empty-looking payload', :aggregate_failures do
        post_graphql(query, current_user: authorized_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil
        expect(metrics).to be_nil
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(ai_governance_dashboard: false)
      end

      it 'returns null without errors', :aggregate_failures do
        post_graphql(query, current_user: authorized_user)

        expect(graphql_errors).to be_nil
        expect(metrics).to be_nil
      end
    end

    context 'when the user is not authorized' do
      it 'returns null without errors', :aggregate_failures do
        post_graphql(query, current_user: unauthorized_user)

        expect(graphql_errors).to be_nil
        expect(metrics).to be_nil
      end
    end

    context 'when the user is anonymous' do
      it 'returns null without errors', :aggregate_failures do
        post_graphql(query, current_user: nil)

        expect(graphql_errors).to be_nil
        expect(metrics).to be_nil
      end
    end
  end

  context 'for a group' do
    let(:parent_type) { :group }
    let(:container) { group }

    it_behaves_like 'an aiGovernanceMetrics field'
  end

  context 'for a project' do
    let(:parent_type) { :project }
    let(:container) { project }

    it_behaves_like 'an aiGovernanceMetrics field'
  end
end

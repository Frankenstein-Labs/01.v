# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.pipelineExecutionSchedulePolicyTestRun(id)',
  feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:policy_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_project)
  end

  let_it_be(:policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      security_orchestration_policy_configuration: policy_configuration,
      security_policy_management_project: policy_project)
  end

  let_it_be(:target_project) { create(:project) }
  let_it_be(:test_run) do
    create(:security_pipeline_execution_policy_test_run,
      project: target_project,
      security_policy: policy,
      state: :complete)
  end

  let(:test_run_id) { test_run.to_global_id.to_s }

  let(:query) do
    <<~QUERY
      query($id: SecurityScheduledPipelineExecutionPolicyTestRunID!) {
        pipelineExecutionSchedulePolicyTestRun(id: $id) {
          id
          state
          startedAt
          finishedAt
          duration
          errorMessage
          completed
        }
      }
    QUERY
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  context 'when user has access to both policy project and target project' do
    let_it_be(:current_user) { create(:user, developer_of: [policy_project, target_project]) }

    it 'returns the test run' do
      post_graphql(query, current_user: current_user, variables: { id: test_run_id })

      expect(response).to have_gitlab_http_status(:ok)

      test_run_data = graphql_data_at(:pipelineExecutionSchedulePolicyTestRun)
      expect(test_run_data).to include(
        'id' => test_run.to_global_id.to_s,
        'state' => 'COMPLETE',
        'completed' => true
      )
    end

    context 'when the test run does not exist' do
      let(:test_run_id) do
        ::Gitlab::GlobalId.as_global_id(
          non_existing_record_id,
          model_name: 'Security::ScheduledPipelineExecutionPolicyTestRun'
        ).to_s
      end

      it 'returns null' do
        post_graphql(query, current_user: current_user, variables: { id: test_run_id })

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_data_at(:pipelineExecutionSchedulePolicyTestRun)).to be_nil
      end
    end
  end

  context 'when user cannot push to the policy project' do
    let_it_be(:current_user) { create(:user) }

    it 'returns null' do
      post_graphql(query, current_user: current_user, variables: { id: test_run_id })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:pipelineExecutionSchedulePolicyTestRun)).to be_nil
    end
  end

  context 'when unauthenticated' do
    it 'returns null' do
      post_graphql(query, variables: { id: test_run_id })

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_data_at(:pipelineExecutionSchedulePolicyTestRun)).to be_nil
    end
  end
end

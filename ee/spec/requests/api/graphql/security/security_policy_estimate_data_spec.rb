# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).securityPolicies.linkedProjectsCount',
  feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:policy_management_project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:commit) { create(:commit, committed_date: Time.zone.now) }

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project,
      experiments: { 'pipeline_execution_schedule_policy' => { 'enabled' => true } })
  end

  let_it_be(:security_policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      name: 'test-schedule-policy',
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:policy_yaml_data) do
    build(:pipeline_execution_schedule_policy, name: 'test-schedule-policy')
  end

  let_it_be(:policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_schedule_policy: [policy_yaml_data])
  end

  let(:query) do
    <<~QUERY
      query($fullPath: ID!) {
        project(fullPath: $fullPath) {
          securityPolicies(type: PIPELINE_EXECUTION_SCHEDULE_POLICY) {
            nodes {
              name
              linkedProjectsCount
              policyAttributes {
                ... on PipelineExecutionScheduledPolicyAttributesType {
                  scheduleTimeWindowSeconds
                }
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) { { fullPath: project.full_path } }

  subject(:policy_data) do
    nodes = graphql_data_at(:project, :securityPolicies, :nodes)
    nodes&.find { |n| n['name'] == 'test-schedule-policy' }
  end

  before_all do
    project.add_maintainer(user)
    policy_management_project.add_developer(user)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive_messages(blob_data_at: policy_yaml, last_commit_for_path: commit)
    end
  end

  context 'with linked projects' do
    let_it_be(:linked_project_1) { create(:project) }
    let_it_be(:linked_project_2) { create(:project) }

    before_all do
      create(:security_policy_project_link, security_policy: security_policy, project: linked_project_1)
      create(:security_policy_project_link, security_policy: security_policy, project: linked_project_2)
    end

    before do
      post_graphql(query, current_user: user, variables: variables)
    end

    it 'returns linked_projects_count and schedule_time_window_seconds', :aggregate_failures do
      expect(policy_data).to include('linkedProjectsCount' => 2)
      expect(policy_data.dig('policyAttributes', 'scheduleTimeWindowSeconds')).to eq(4000)
    end
  end

  context 'with no linked projects' do
    before do
      post_graphql(query, current_user: user, variables: variables)
    end

    it 'returns zero for linked projects count' do
      expect(policy_data).to include('linkedProjectsCount' => 0)
    end
  end

  context 'with multiple policies' do
    let_it_be(:security_policy_2) do
      create(:security_policy, :pipeline_execution_schedule_policy,
        name: 'test-schedule-policy-2',
        policy_index: 1,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:policy_yaml_data_2) do
      build(:pipeline_execution_schedule_policy, name: 'test-schedule-policy-2')
    end

    # shadow the outer let_it_be so the before block sees both policies in YAML
    let(:policy_yaml) do
      build(:orchestration_policy_yaml,
        pipeline_execution_schedule_policy: [policy_yaml_data, policy_yaml_data_2])
    end

    it 'batches linked_projects_count across all policies in a single query' do
      control = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: user, variables: variables)
      end

      create(:security_policy_project_link,
        security_policy: security_policy_2, project: create(:project))

      expect do
        post_graphql(query, current_user: user, variables: variables)
      end.not_to exceed_query_limit(control)
    end
  end

  context 'when user does not have permission' do
    let_it_be(:unauthorized_user) { create(:user) }

    before do
      post_graphql(query, current_user: unauthorized_user, variables: variables)
    end

    it 'returns nil for the project' do
      expect(graphql_data_at(:project)).to be_nil
    end
  end
end

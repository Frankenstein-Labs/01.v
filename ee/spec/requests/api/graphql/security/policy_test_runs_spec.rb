# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).securityPolicies.testRuns', feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:policy_management_project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:committed_date) { Time.zone.now }
  let_it_be(:commit) { create(:commit, committed_date: committed_date) }

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project)
  end

  let_it_be(:security_policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      name: 'test-schedule-policy',
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:test_run) do
    create(:security_pipeline_execution_policy_test_run,
      security_policy: security_policy,
      project: project,
      pipeline: nil)
  end

  let_it_be(:policy) do
    build(:pipeline_execution_schedule_policy, name: 'test-schedule-policy')
  end

  let_it_be(:policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_schedule_policy: [policy])
  end

  let(:query) do
    <<~QUERY
      query($fullPath: ID!) {
        project(fullPath: $fullPath) {
          securityPolicies {
            nodes {
              name
              type
              testRuns {
                nodes {
                  id
                  state
                  duration
                  startedAt
                  finishedAt
                  errorMessage
                  createdAt
                  project {
                    fullPath
                  }
                }
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) { { fullPath: project.full_path } }

  subject(:test_runs_data) do
    nodes = graphql_data_at(:project, :securityPolicies, :nodes)
    next unless nodes

    schedule_policy = nodes.find { |n| n['name'] == 'test-schedule-policy' }
    schedule_policy&.dig('testRuns', 'nodes')
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

  context 'when the feature flag is enabled' do
    before do
      post_graphql(query, current_user: user, variables: variables)
    end

    it 'returns test runs for the schedule policy' do
      expect(test_runs_data).to contain_exactly(
        hash_including(
          'id' => test_run.to_global_id.to_s,
          'state' => 'RUNNING',
          'project' => { 'fullPath' => project.full_path }
        )
      )
    end

    it 'does not have N+1 queries when loading multiple test runs' do
      control = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: user, variables: variables)
      end

      create_list(:security_pipeline_execution_policy_test_run, 3,
        security_policy: security_policy, project: project, pipeline: nil)

      expect do
        post_graphql(query, current_user: user, variables: variables)
      end.not_to exceed_query_limit(control)
    end
  end

  context 'when querying through a namespace' do
    let_it_be(:namespace_configuration) do
      create(:security_orchestration_policy_configuration,
        :namespace,
        namespace: group,
        security_policy_management_project: policy_management_project)
    end

    let_it_be(:namespace_policy) do
      create(:security_policy, :pipeline_execution_schedule_policy,
        name: 'namespace-schedule-policy',
        security_orchestration_policy_configuration: namespace_configuration)
    end

    let_it_be(:namespace_test_run) do
      create(:security_pipeline_execution_policy_test_run,
        security_policy: namespace_policy,
        project: project,
        pipeline: nil)
    end

    let_it_be(:namespace_policy_yaml_data) do
      build(:pipeline_execution_schedule_policy, name: 'namespace-schedule-policy')
    end

    let_it_be(:namespace_policy_yaml) do
      build(:orchestration_policy_yaml, pipeline_execution_schedule_policy: [namespace_policy_yaml_data])
    end

    let(:namespace_query) do
      <<~QUERY
        query($fullPath: ID!) {
          namespace(fullPath: $fullPath) {
            securityPolicies {
              nodes {
                name
                type
                testRuns {
                  nodes {
                    id
                    state
                    project {
                      fullPath
                    }
                  }
                }
              }
            }
          }
        }
      QUERY
    end

    let(:namespace_variables) { { fullPath: group.full_path } }

    subject(:namespace_test_runs_data) do
      nodes = graphql_data_at(:namespace, :securityPolicies, :nodes)
      next unless nodes

      schedule_policy = nodes.find { |n| n['name'] == 'namespace-schedule-policy' }
      schedule_policy&.dig('testRuns', 'nodes')
    end

    before_all do
      group.add_maintainer(user)
    end

    before do
      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive_messages(blob_data_at: namespace_policy_yaml, last_commit_for_path: commit)
      end

      post_graphql(namespace_query, current_user: user, variables: namespace_variables)
    end

    it 'returns test runs for the namespace policy' do
      expect(namespace_test_runs_data).to contain_exactly(
        hash_including(
          'id' => namespace_test_run.to_global_id.to_s,
          'state' => 'RUNNING',
          'project' => { 'fullPath' => project.full_path }
        )
      )
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

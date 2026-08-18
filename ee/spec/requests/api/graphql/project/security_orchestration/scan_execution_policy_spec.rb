# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).scanExecutionPolicies', feature_category: :security_policy_management do
  include GraphqlHelpers
  include_context 'with project level scan execution policies'

  let_it_be(:yaml) do
    YAML.dump({
      name: policy[:name],
      description: policy[:description],
      enabled: policy[:enabled],
      policy_scope: policy[:policy_scope],
      actions: policy[:actions],
      rules: policy[:rules],
      metadata: policy[:metadata]
    }.compact.deep_stringify_keys)
  end

  subject(:query_result) { graphql_data_at(:project, :scanExecutionPolicies, :nodes) }

  context 'when policy_configuration is assigned to the project' do
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([
        expected_policy_response(policy, false, yaml)
          .merge(expected_project_source_response)
          .merge(expected_edit_path_response(project))
      ])
    end

    context 'when policy_scope is present in policy' do
      include_context 'with scan execution policy and policy_scope'

      let_it_be(:yaml) do
        YAML.dump({
          name: policy[:name],
          description: policy[:description],
          enabled: policy[:enabled],
          policy_scope: policy[:policy_scope],
          actions: policy[:actions],
          rules: policy[:rules],
          metadata: policy[:metadata]
        }.compact.deep_stringify_keys)
      end

      it 'returns the policy' do
        expect(query_result).to match_array([
          expected_policy_response(policy, false, yaml)
            .merge(expected_policy_scope_response)
            .merge(expected_project_source_response)
            .merge(expected_edit_path_response(project))
        ])
      end
    end

    context 'when querying id field' do
      let_it_be(:security_policy) do
        create(:security_policy, :scan_execution_policy,
          security_orchestration_policy_configuration: policy_configuration,
          name: policy[:name],
          policy_index: 0)
      end

      let_it_be(:query) do
        <<~QUERY
          query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
            project(fullPath: $fullPath) {
              scanExecutionPolicies(relationship: $relationship) {
                nodes {
                  id
                  name
                }
              }
            }
          }
        QUERY
      end

      before do
        post_graphql(query, current_user: user, variables: project_variables)
      end

      it 'returns the policy id through the full resolver stack' do
        expect(query_result).to match_array([
          { 'id' => security_policy.to_global_id.to_s, 'name' => policy[:name] }
        ])
      end
    end
  end

  context 'when policy_configuration is assigned to the group' do
    let_it_be(:project_variables) do
      {
        fullPath: project.full_path,
        relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum.values['INHERITED'].graphql_name
      }
    end

    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: nil, namespace: group)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([expected_policy_response(policy, true, yaml)])
    end
  end
end

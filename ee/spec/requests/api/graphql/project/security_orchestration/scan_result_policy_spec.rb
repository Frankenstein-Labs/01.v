# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).scanResultPolicies', feature_category: :security_policy_management do
  include GraphqlHelpers
  include_context 'with project level approval policies'

  subject(:query_result) { graphql_data_at(:project, :scanResultPolicies, :nodes) }

  context 'when policy_configuration is assigned to the project' do
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)
    end

    let(:yaml) do
      YAML.dump({
        name: policy[:name],
        description: policy[:description],
        enabled: policy[:enabled],
        policy_scope: policy[:policy_scope],
        actions: policy[:actions],
        rules: policy[:rules],
        approval_settings: policy[:approval_settings],
        fallback_behavior: policy[:fallback_behavior],
        metadata: policy[:metadata],
        policy_tuning: policy[:policy_tuning],
        bypass_settings: policy[:bypass_settings],
        enforcement_type: policy[:enforcement_type]
      }.compact.deep_stringify_keys)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([
        expected_approval_policy_response(policy, false, yaml)
          .merge(expected_project_source_response)
          .merge(expected_edit_path_response(project, 'approval_policy'))
      ])
    end

    context 'when policy_scope is present in policy' do
      include_context 'with approval policy and policy_scope'

      it 'returns the policy' do
        expect(query_result).to match_array([
          expected_approval_policy_response(policy, false, yaml)
            .merge(expected_project_source_response)
            .merge(expected_policy_scope_response)
            .merge(expected_edit_path_response(project, 'approval_policy'))
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

    let(:yaml) do
      YAML.dump({
        name: policy[:name],
        description: policy[:description],
        enabled: policy[:enabled],
        policy_scope: policy[:policy_scope],
        actions: policy[:actions],
        rules: policy[:rules],
        approval_settings: policy[:approval_settings],
        fallback_behavior: policy[:fallback_behavior],
        metadata: policy[:metadata],
        policy_tuning: policy[:policy_tuning],
        bypass_settings: policy[:bypass_settings],
        enforcement_type: policy[:enforcement_type]
      }.compact.deep_stringify_keys)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([
        expected_approval_policy_response(policy, false, yaml)
          .merge(expected_group_source_response(true))
          .merge(expected_edit_path_response(group, 'approval_policy'))
      ])
    end
  end
end

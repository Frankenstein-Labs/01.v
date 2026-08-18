# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group(fullPath).scanExecutionPolicies', feature_category: :security_policy_management do
  include GraphqlHelpers
  include_context 'with group level scan execution policies'

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: nil, namespace: group)
  end

  let(:policy_type) { 'scan_execution_policy' }
  let(:yaml) do
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

  subject(:query_result) { graphql_data_at(:group, :scanExecutionPolicies, :nodes) }

  context 'when policy_scope is present in the policy' do
    it 'returns the policy' do
      expect(query_result).to match_array([expected_policy_response(policy, false, yaml)])
    end
  end

  context 'when policy_scope is present in policy' do
    include_context 'with scan execution policy and policy_scope'

    it 'returns the policy' do
      expect(query_result).to match_array([expected_policy_response(policy, false,
        yaml).merge(expected_policy_scope_response)])
    end
  end
end

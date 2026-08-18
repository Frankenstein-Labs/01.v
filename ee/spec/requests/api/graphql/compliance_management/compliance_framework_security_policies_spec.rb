# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.namespace.complianceFrameworks.nodes.securityPolicies',
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:policy_management_project) { create(:project, :repository) }
  let_it_be(:framework) do
    create(:compliance_framework, namespace: group, name: 'Test Framework')
  end

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: nil,
      namespace: group)
  end

  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy,
      policy_configuration: policy_configuration,
      framework: framework)
  end

  let(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }

  let(:scan_execution_policy) do
    build(:scan_execution_policy, name: 'SEP policy', policy_scope: policy_scope)
  end

  let(:approval_policy) do
    build(:approval_policy, name: 'Approval policy', policy_scope: policy_scope)
  end

  let(:pipeline_execution_policy) do
    build(:pipeline_execution_policy, name: 'PEP policy', policy_scope: policy_scope,
      content: { include: [{ project: policy_management_project.full_path,
                             file: 'policy.yml' }] })
  end

  let(:vulnerability_management_policy) do
    build(:vulnerability_management_policy, name: 'VM policy', policy_scope: policy_scope,
      content: { include: [{ project: policy_management_project.full_path,
                             file: 'policy.yml' }] })
  end

  let(:pipeline_execution_schedule_policy) do
    build(:pipeline_execution_schedule_policy, name: 'PES policy', policy_scope: policy_scope,
      content: { include: [{ project: policy_management_project.full_path,
                             file: 'policy.yml' }] })
  end

  let(:policy_yaml) do
    build(:orchestration_policy_yaml,
      scan_execution_policy: [scan_execution_policy],
      approval_policy: [approval_policy],
      pipeline_execution_policy: [pipeline_execution_policy],
      vulnerability_management_policy: [vulnerability_management_policy],
      pipeline_execution_schedule_policy: [pipeline_execution_schedule_policy])
  end

  let(:query) do
    <<~GQL
      query($fullPath: ID!, $frameworkId: ComplianceManagementFrameworkID) {
        namespace(fullPath: $fullPath) {
          complianceFrameworks(id: $frameworkId) {
            nodes {
              securityPolicies {
                nodes {
                  name
                  type
                  source {
                    __typename
                    ... on GroupSecurityPolicySource {
                      namespace { fullPath }
                    }
                    ... on ProjectSecurityPolicySource {
                      project { fullPath }
                    }
                  }
                }
              }
            }
          }
        }
      }
    GQL
  end

  let(:variables) { { fullPath: group.full_path, frameworkId: framework.to_global_id.to_s } }
  let(:security_policies) do
    graphql_data_at(:namespace, :compliance_frameworks, :nodes, 0, :security_policies, :nodes)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true, custom_compliance_frameworks: true)
    allow(Project).to receive(:find_by_full_path)
      .with(policy_management_project.full_path)
      .and_return(policy_management_project)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
    end
  end

  context 'when the user has access to the group' do
    before_all { group.add_owner(current_user) }

    it 'returns all policy types for the framework' do
      post_graphql(query, current_user: current_user, variables: variables)

      expect(security_policies).to match_array([
        a_hash_including('name' => 'SEP policy', 'type' => 'scan_execution_policy'),
        a_hash_including('name' => 'Approval policy', 'type' => 'approval_policy'),
        a_hash_including('name' => 'PEP policy', 'type' => 'pipeline_execution_policy'),
        a_hash_including('name' => 'VM policy', 'type' => 'vulnerability_management_policy'),
        a_hash_including('name' => 'PES policy', 'type' => 'pipeline_execution_schedule_policy')
      ])
    end

    it 'resolves source to the group namespace' do
      post_graphql(query, current_user: current_user, variables: variables)

      sources = security_policies.map { |p| p['source'] }
      expect(sources).to all(
        include('__typename' => 'GroupSecurityPolicySource',
          'namespace' => { 'fullPath' => group.full_path })
      )
    end

    context 'when a policy is not scoped to the framework' do
      let(:policy_yaml) do
        build(:orchestration_policy_yaml,
          scan_execution_policy: [
            build(:scan_execution_policy, name: 'Scoped policy', policy_scope: policy_scope),
            build(:scan_execution_policy, name: 'Unscoped policy',
              policy_scope: { compliance_frameworks: [] })
          ])
      end

      it 'excludes policies not scoped to the framework' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(security_policies).to contain_exactly(
          a_hash_including('name' => 'Scoped policy')
        )
      end
    end
  end

  context 'when the user has no access to the group' do
    it 'returns nil for compliance frameworks' do
      post_graphql(query, current_user: current_user, variables: variables)

      expect(graphql_data_at(:namespace, :compliance_frameworks)).to be_nil
    end
  end
end

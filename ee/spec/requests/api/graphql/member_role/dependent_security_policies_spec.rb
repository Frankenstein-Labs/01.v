# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.memberRole.dependentSecurityPolicies', feature_category: :security_policy_management do
  include GraphqlHelpers

  def member_role_query
    <<~QUERY
    query {
      memberRole(id: "#{member_role.to_global_id}") {
        id
        dependentSecurityPolicies {
          name
          description
          enabled
          editPath
        }
      }
    }
    QUERY
  end

  let_it_be(:member_role) { create(:member_role) }
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { member_role.namespace }

  subject(:dependent_policies) do
    graphql_data['memberRole']['dependentSecurityPolicies']
  end

  before do
    member_role.namespace.add_owner(user)

    stub_licensed_features(custom_roles: true, security_orchestration_policies: true)
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  context 'when member_role has dependent security policies' do
    let_it_be(:policy_config) do
      create(:security_orchestration_policy_configuration, project: nil, namespace: namespace)
    end

    let_it_be(:security_policy) do
      create(:security_policy,
        security_orchestration_policy_configuration: policy_config,
        description: 'A security policy',
        content: { actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [member_role.id] }] }
      )
    end

    before do
      policy_config.security_policy_management_project.add_owner(user)

      allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 3) do |configuration|
        allow(configuration).to receive_messages(policy_configuration_valid?: true, policy_last_updated_at: Time.now)
      end
      post_graphql(member_role_query, current_user: user)
    end

    it_behaves_like 'a working graphql query'

    it 'returns the requested member role' do
      expect(dependent_policies.first).to eq(
        'name' => security_policy.name,
        'description' => security_policy.description,
        'editPath' => Gitlab::Routing.url_helpers.edit_group_security_policy_url(
          namespace, id: CGI.escape(security_policy.name), type: 'approval_policy'
        ),
        'enabled' => true
      )
    end
  end

  context 'when member_role has no dependent security policies' do
    before do
      post_graphql(member_role_query, current_user: user)
    end

    it 'returns an empty array' do
      expect(dependent_policies).to be_empty
    end
  end
end

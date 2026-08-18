# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List group secrets permissions', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:query_name) { :group_secrets_permissions }
  let(:resource) { group }
  let(:resource_path) { group.full_path }
  let(:member_role_namespace) { group }
  let(:service_class) { SecretsManagement::GroupSecretsPermissions::ListService }

  let(:shared_resource) { create(:group) }

  let!(:group_link) do
    create(:group_group_link, shared_group: group, shared_with_group: shared_resource,
      group_access: Gitlab::Access::DEVELOPER)
  end

  let(:query) do
    graphql_query_for(
      query_name,
      { group_path: resource_path },
      "nodes { #{all_graphql_fields_for(Types::SecretsManagement::GroupSecretsPermissionType, max_depth: 2)} }"
    )
  end

  def provision_secrets_manager(secrets_manager, user)
    provision_group_secrets_manager(secrets_manager, user)
  end

  def update_permission(user:, actions:, principal:, expired_at: nil)
    update_group_secrets_permission(
      user: user,
      group: group,
      actions: actions,
      principal: principal,
      expired_at: expired_at
    )
  end

  it_behaves_like 'a GraphQL query for listing secrets permissions', 'group'

  context 'when the secrets manager entitlement denies access' do
    let(:error_message) do
      "The resource that you are attempting to access does not exist or " \
        "you don't have permission to perform this action"
    end

    before_all do
      group.add_owner(current_user)
    end

    before do
      provision_secrets_manager(secrets_manager, current_user)

      stub_feature_flags(secrets_manager_paid_experience: true)
      allow(SecretsManagement::Entitlement).to receive(:for)
        .and_return(SecretsManagement::Entitlement.new(state: :ineligible))

      post_graphql(query, current_user: current_user)
    end

    it 'returns the existing hard permission error (no resolver code change for this path)' do
      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(a_hash_including('message' => error_message))
    end
  end
end

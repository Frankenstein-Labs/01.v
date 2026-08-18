# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update Group Secrets Permission', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:shared_group) { create(:group) }
  let_it_be(:group_link) { create(:group_group_link, shared_group: group, shared_with_group: shared_group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :group_secrets_permission_update }

  let(:resource) { group }
  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:secrets_manager_namespace_path) { secrets_manager.full_group_namespace_path }
  let(:service_class) { SecretsManagement::GroupSecretsPermissions::UpdateService }
  let(:feature_flag_name) { :group_secrets_manager }

  let(:params) do
    {
      groupPath: group.full_path,
      principal: principal_params,
      actions: actions,
      expiredAt: expired_at
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  def provision_secrets_manager(secrets_manager, user)
    provision_group_secrets_manager(secrets_manager, user)
  end

  it_behaves_like 'a GraphQL mutation for updating secrets permissions', 'group'
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List project secrets permissions', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:project_group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: project_group) }
  let_it_be(:current_user) { create(:user) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:query_name) { :project_secrets_permissions }
  let(:resource) { project }
  let(:resource_path) { project.full_path }
  let(:member_role_namespace) { project.group }
  let(:service_class) { SecretsManagement::ProjectSecretsPermissions::ListService }

  let(:shared_resource) { create(:group) }

  let!(:project_group_link) do
    create(:project_group_link, project: project, group: shared_resource, group_access: Gitlab::Access::DEVELOPER)
  end

  let(:query) do
    graphql_query_for(
      query_name,
      { project_path: resource_path },
      "nodes { #{all_graphql_fields_for(Types::SecretsManagement::ProjectSecretsPermissionType, max_depth: 2)} }"
    )
  end

  def provision_secrets_manager(secrets_manager, user)
    provision_project_secrets_manager(secrets_manager, user)
  end

  def update_permission(user:, actions:, principal:, expired_at: nil)
    update_project_secrets_permission(
      user: user,
      project: project,
      actions: actions,
      principal: principal,
      expired_at: expired_at
    )
  end

  it_behaves_like 'a GraphQL query for listing secrets permissions', 'project'
end

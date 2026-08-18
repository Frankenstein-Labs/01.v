# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete Project Secrets Permission', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :project_secrets_permission_delete }

  let(:resource) { project }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service_class) { SecretsManagement::ProjectSecretsPermissions::DeleteService }
  let(:feature_flag_name) { :secrets_manager }

  let(:params) do
    {
      projectPath: project.full_path,
      principal: {
        id: principal[:id],
        type: principal[:type].upcase
      }
    }
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

  it_behaves_like 'a GraphQL mutation for deleting secrets permissions', 'project'
end

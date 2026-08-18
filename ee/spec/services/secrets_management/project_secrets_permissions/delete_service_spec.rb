# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsPermissions::DeleteService, :gitlab_secrets_manager,
  feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:owner_user) { create(:user) }
  let_it_be(:user) { create(:user) }

  let(:resource) { project }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:full_namespace_path) { secrets_manager.full_project_namespace_path }
  let(:service) { described_class.new(project, owner_user) }

  before_all do
    project.add_owner(owner_user)
    project.add_reporter(user)
  end

  def provision_secrets_manager(secrets_manager, owner_user)
    provision_project_secrets_manager(secrets_manager, owner_user)
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

  it_behaves_like 'a service for deleting secrets permissions', 'project'
end

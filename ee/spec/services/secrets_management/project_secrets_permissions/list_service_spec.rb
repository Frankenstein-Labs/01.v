# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsPermissions::ListService, :gitlab_secrets_manager,
  feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  let(:resource) { project }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:member_role_namespace) { project.group }
  let(:service) { described_class.new(project, user) }
  let(:shared_resource) { create(:group) }
  let!(:project_group_link) do
    create(:project_group_link, project: project, group: shared_resource, group_access: Gitlab::Access::DEVELOPER)
  end

  before_all do
    project.add_owner(user)
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

  it_behaves_like 'a service for listing secrets permissions', 'project'
end

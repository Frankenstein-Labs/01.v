# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsPermissions::ListService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:resource) { group }
  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:member_role_namespace) { group }
  let(:service) { described_class.new(group, user) }
  let(:shared_resource) { create(:group) }
  let!(:group_link) do
    create(:group_group_link, shared_group: group, shared_with_group: shared_resource,
      group_access: Gitlab::Access::DEVELOPER)
  end

  before_all do
    group.add_owner(user)
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

  it_behaves_like 'a service for listing secrets permissions', 'group'
end

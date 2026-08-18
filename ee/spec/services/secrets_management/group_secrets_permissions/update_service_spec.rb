# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe SecretsManagement::GroupSecretsPermissions::UpdateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:owner_user) { create(:user) }
  let_it_be(:user) { create(:user) }

  let(:resource) { group }
  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:secrets_manager_namespace_path) { secrets_manager.full_group_namespace_path }
  let(:service) { described_class.new(group, owner_user) }

  before_all do
    group.add_owner(user)
    group.add_developer(user)
  end

  def provision_secrets_manager(secrets_manager, owner_user)
    provision_group_secrets_manager(secrets_manager, owner_user)
  end

  it_behaves_like 'a service for updating secrets permissions', 'group'
end

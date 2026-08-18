# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagers::DeprovisionService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:maintenance_task) do
    create(:group_secrets_manager_maintenance_task, :deprovision,
      group: group,
      user: user
    )
  end

  let(:service) { described_class.new(maintenance_task, user) }

  subject(:result) { service.execute }

  describe '#execute' do
    before do
      provision_group_secrets_manager(secrets_manager, user)
    end

    let(:payload_key) { :group_secrets_manager_maintenance_task }
    let(:find_sm_target) { SecretsManagement::GroupSecretsManager }
    let(:parent_fk_column) { :group_id }

    def expect_no_policies_at(full_path)
      expect_group_to_have_no_policies(full_path)
    end

    it_behaves_like 'a secrets manager deprovision service'
    it_behaves_like 'an operation requiring an exclusive group secret operation lease', 120.seconds

    it 'enqueues a namespace secret count refresh after destroying the manager' do
      expect(SecretsManagement::ReconcileNamespaceSecretCountWorker)
        .to receive(:perform_async)
        .with(secrets_manager.namespace_id_for_secret_count, user.id)

      expect(result).to be_success
    end

    context 'when group namespace has child namespaces' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let(:subgroup_secrets_manager) { create(:group_secrets_manager, group: subgroup) }

      before do
        provision_group_secrets_manager(subgroup_secrets_manager, user)
      end

      it 'only deprovisions the namespace for the group' do
        expect(result).to be_success

        expect_namespace_not_to_exist(secrets_manager.full_namespace_path)
        expect_namespace_to_exist(
          [secrets_manager.org_path, secrets_manager.root_namespace_path].join('/')
        )
        expect_namespace_to_exist(subgroup_secrets_manager.full_namespace_path)

        expect(SecretsManagement::GroupSecretsManager.find_by(id: secrets_manager.id)).to be_nil
        expect(SecretsManagement::GroupSecretsManager.find_by(id: subgroup_secrets_manager.id)).to be_present
      end
    end

    context 'when group is a child namespace with sibling namespaces' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: root_group) }
      let_it_be(:sibling_group) { create(:group, parent: root_group) }

      let(:child_secrets_manager) { create(:group_secrets_manager, group: child_group) }
      let(:sibling_secrets_manager) { create(:group_secrets_manager, group: sibling_group) }
      let(:maintenance_task) do
        create(:group_secrets_manager_maintenance_task, :deprovision,
          group: child_group,
          user: user
        )
      end

      before do
        provision_group_secrets_manager(child_secrets_manager, user)
        provision_group_secrets_manager(sibling_secrets_manager, user)
      end

      it 'only deprovisions the namespace for the child group' do
        expect(result).to be_success

        expect_namespace_not_to_exist(child_secrets_manager.full_namespace_path)
        expect_namespace_to_exist(
          [child_secrets_manager.org_path, child_secrets_manager.root_namespace_path].join('/')
        )
        expect_namespace_to_exist(sibling_secrets_manager.full_namespace_path)

        expect(SecretsManagement::GroupSecretsManager.find_by(id: child_secrets_manager.id)).to be_nil
        expect(SecretsManagement::GroupSecretsManager.find_by(id: sibling_secrets_manager.id)).to be_present
      end
    end
  end
end

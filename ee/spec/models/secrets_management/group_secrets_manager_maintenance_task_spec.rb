# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagerMaintenanceTask, feature_category: :secrets_management do
  subject(:task) { build(:group_secrets_manager_maintenance_task) }

  let(:factory_name) { :group_secrets_manager_maintenance_task }

  it_behaves_like 'a secrets manager maintenance task'

  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group_id) }
    it { is_expected.to validate_presence_of(:organization_id) }

    it 'validates uniqueness of group_id' do
      create(:group_secrets_manager_maintenance_task)

      expect(task).to validate_uniqueness_of(:group_id)
    end

    it 'validates uniqueness of group_id' do
      group = create(:group)
      user = create(:user)

      create(:group_secrets_manager_maintenance_task,
        group: group,
        root_namespace_id: group.root_ancestor.id,
        user: user,
        action: :provision
      )

      duplicate = build(:group_secrets_manager_maintenance_task,
        group: group,
        root_namespace_id: group.root_ancestor.id,
        user: user,
        action: :deprovision
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:group_id]).to include('has already been taken')
    end

    it 'enforces uniqueness on group_id at the database level' do
      existing = create(:group_secrets_manager_maintenance_task, action: :provision)

      duplicate = build(:group_secrets_manager_maintenance_task,
        user: existing.user,
        group: existing.group,
        root_namespace_id: existing.root_namespace_id,
        action: :deprovision,
        retry_count: 0
      )

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '.deprovision_pending_for?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:other_group) { create(:group) }

    it 'returns false when group_id is nil' do
      expect(described_class.deprovision_pending_for?(nil)).to be(false)
    end

    it 'returns false when no maintenance task exists for the group' do
      expect(described_class.deprovision_pending_for?(group.id)).to be(false)
    end

    it 'returns false when only a provision task exists' do
      create(:group_secrets_manager_maintenance_task, :provision, group: group)

      expect(described_class.deprovision_pending_for?(group.id)).to be(false)
    end

    it 'returns true when a deprovision task exists for the group' do
      create(:group_secrets_manager_maintenance_task, :deprovision, group: group)

      expect(described_class.deprovision_pending_for?(group.id)).to be(true)
    end

    it 'does not pick up a deprovision task for a different group' do
      create(:group_secrets_manager_maintenance_task, :deprovision, group: other_group)

      expect(described_class.deprovision_pending_for?(group.id)).to be(false)
    end
  end

  describe 'path helpers' do
    subject(:task) do
      build(:group_secrets_manager_maintenance_task,
        organization_id: 7, root_namespace_id: 42, group_id: 99)
    end

    describe '#org_path' do
      it 'builds the level-1 path from organization_id' do
        expect(task.org_path).to eq('org_7')
      end
    end

    describe '#root_namespace_path' do
      it 'builds the level-2 path from root_namespace_id' do
        expect(task.root_namespace_path).to eq('group_42')
      end
    end

    describe '#group_path' do
      it 'builds the level-3 path from group_id' do
        expect(task.group_path).to eq('group_99')
      end
    end

    describe '#full_group_namespace_path' do
      it 'joins the three levels with /' do
        expect(task.full_group_namespace_path).to eq('org_7/group_42/group_99')
      end
    end
  end
end

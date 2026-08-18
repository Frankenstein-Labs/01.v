# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagerMaintenanceTask, feature_category: :secrets_management do
  subject(:task) { build(:project_secrets_manager_maintenance_task) }

  let(:factory_name) { :project_secrets_manager_maintenance_task }

  it_behaves_like 'a secrets manager maintenance task'

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project_id) }

    it 'validates uniqueness of project_id' do
      create(:project_secrets_manager_maintenance_task)

      expect(task).to validate_uniqueness_of(:project_id)
    end

    it 'enforces uniqueness on project_id at the database level' do
      existing = create(:project_secrets_manager_maintenance_task, action: :provision)

      duplicate = build(:project_secrets_manager_maintenance_task,
        user: existing.user,
        project: existing.project,
        action: :deprovision,
        retry_count: 0
      )

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '.deprovision_pending_for?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:other_project) { create(:project) }

    it 'returns false when project_id is nil' do
      expect(described_class.deprovision_pending_for?(nil)).to be(false)
    end

    it 'returns false when no maintenance task exists for the project' do
      expect(described_class.deprovision_pending_for?(project.id)).to be(false)
    end

    it 'returns false when only a provision task exists' do
      create(:project_secrets_manager_maintenance_task, :provision, project: project)

      expect(described_class.deprovision_pending_for?(project.id)).to be(false)
    end

    it 'returns true when a deprovision task exists for the project' do
      create(:project_secrets_manager_maintenance_task, :deprovision, project: project)

      expect(described_class.deprovision_pending_for?(project.id)).to be(true)
    end

    it 'does not pick up a deprovision task for a different project' do
      create(:project_secrets_manager_maintenance_task, :deprovision, project: other_project)

      expect(described_class.deprovision_pending_for?(project.id)).to be(false)
    end
  end

  describe 'path helpers' do
    subject(:task) do
      build(:project_secrets_manager_maintenance_task,
        organization_id: 7, root_namespace_id: 42, project_id: 99)
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

    describe '#project_path' do
      it 'builds the level-3 path from project_id' do
        expect(task.project_path).to eq('project_99')
      end
    end

    describe '#full_project_namespace_path' do
      it 'joins the three levels with /' do
        expect(task.full_project_namespace_path).to eq('org_7/group_42/project_99')
      end
    end
  end
end

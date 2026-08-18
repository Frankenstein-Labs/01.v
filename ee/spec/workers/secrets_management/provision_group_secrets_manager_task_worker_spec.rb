# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProvisionGroupSecretsManagerTaskWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:worker) { described_class.new }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let!(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let!(:maintenance_task) do
    create(:group_secrets_manager_maintenance_task, :provision,
      group: group,
      user: user
    )
  end

  let(:provision_service_class) { SecretsManagement::GroupSecretsManagers::ProvisionService }
  let(:maintenance_task_class) { SecretsManagement::GroupSecretsManagerMaintenanceTask }

  before do
    stub_feature_flags(secrets_manager_paid_experience: false)
  end

  describe '#perform' do
    it_behaves_like 'a secrets manager provision worker'

    context 'when integration-testing the full provisioning path' do
      it_behaves_like 'an idempotent worker' do
        let(:job_args) { [maintenance_task.id] }

        it 'enables the secret engine and clears the maintenance task' do
          expect { perform_idempotent_work }.not_to raise_error

          expect(secrets_manager.reload).to be_active
          expect(maintenance_task_class.find_by(id: maintenance_task.id)).to be_nil

          expect_kv_secret_engine_to_be_mounted(secrets_manager.full_group_namespace_path,
            secrets_manager.ci_secrets_mount_path)
        end
      end
    end
  end
end

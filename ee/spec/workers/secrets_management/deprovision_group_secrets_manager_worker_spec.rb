# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::DeprovisionGroupSecretsManagerWorker, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:user) { create(:user, owner_of: group) }

    let(:secrets_manager) { create(:group_secrets_manager, group: group) }
    let(:maintenance_task) do
      create(:group_secrets_manager_maintenance_task, :deprovision,
        group: group,
        user: user
      )
    end

    let(:maintenance_task_class) { SecretsManagement::GroupSecretsManagerMaintenanceTask }
    let(:deprovision_service_class) { SecretsManagement::GroupSecretsManagers::DeprovisionService }

    before do
      provision_group_secrets_manager(secrets_manager, user)
    end

    it_behaves_like 'a secrets manager deprovision worker'

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [maintenance_task.id] }

      it 'completely deprovisions the group secrets manager' do
        expect { perform_idempotent_work }.not_to raise_error

        expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_namespace_path,
          secrets_manager.ci_secrets_mount_path)
        expect_group_to_have_no_policies(secrets_manager.full_namespace_path)
        expect(SecretsManagement::GroupSecretsManager.find_by(id: secrets_manager.id)).to be_nil
        expect(SecretsManagement::GroupSecretsManagerMaintenanceTask.find_by(id: maintenance_task.id)).to be_nil
      end
    end

    # Exercises the full trigger flow end-to-end: delete the SM (which
    # is what `EE::Groups::DestroyService` does today via the worker's
    # `delete_secrets_manager`, and what the post-MR-6 CASCADE will do
    # directly), let the AFTER DELETE trigger insert a fresh deprovision
    # task with NULL `user_id`, then run the worker on that task.
    context 'when the trigger inserts the task on SM delete' do
      it 'processes the trigger-created task and cleans OpenBao up' do
        sm_id = secrets_manager.id
        secrets_manager.destroy!

        trigger_task = maintenance_task_class
          .find_by(group_id: group.id, action: maintenance_task_class.actions[:deprovision])

        expect(trigger_task).to be_present
        expect(trigger_task.user_id).to be_nil

        expect { worker.perform(trigger_task.id) }.not_to raise_error

        expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_namespace_path,
          secrets_manager.ci_secrets_mount_path)
        expect(SecretsManagement::GroupSecretsManager.find_by(id: sm_id)).to be_nil
        expect(maintenance_task_class.find_by(id: trigger_task.id)).to be_nil
      end
    end
  end
end

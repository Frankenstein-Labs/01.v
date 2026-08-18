# frozen_string_literal: true

# Drives the shared parts of project + group deprovision specs.
#
# Including specs must provide:
# - `secrets_manager`         -- AR record being deprovisioned
# - `maintenance_task`        -- the task record (factory creates with snapshot IDs)
# - `service`                 -- described_class.new(maintenance_task, user)
# - `result`                  -- service.execute (subject)
# - `payload_key`             -- :project_secrets_manager_maintenance_task /
#                                :group_secrets_manager_maintenance_task
# - `find_sm_target`          -- class used to stub `find_by`/`find_by_id` when
#                                simulating "SM gone" (ProjectSecretsManager /
#                                GroupSecretsManager)
# - `parent_fk_column`        -- :project_id / :group_id (the FK column that
#                                the destroy hook nulls out via ON DELETE SET NULL)
# - `expect_no_policies_at(full_path)` -- scope-specific policy check helper
RSpec.shared_examples 'a secrets manager deprovision service' do
  it 'returns the maintenance task in the payload' do
    expect(result).to be_success
    expect(result.payload[payload_key]).to eq(maintenance_task)
  end

  it 'tears down OpenBao resources and removes the secrets manager record' do
    expect(result).to be_success

    expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_namespace_path,
      secrets_manager.ci_auth_mount)
    expect_jwt_auth_engine_not_to_be_mounted(secrets_manager.full_namespace_path,
      secrets_manager.user_auth_mount)
    expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_namespace_path,
      secrets_manager.ci_secrets_mount_path)
    expect_no_policies_at(secrets_manager.full_namespace_path)

    expect(secrets_manager.class.find_by(id: secrets_manager.id)).to be_nil
    expect(maintenance_task.class.find_by(id: maintenance_task.id)).to be_nil
  end

  it 'tears down the level-1 and level-2 namespaces when no siblings remain' do
    expect(result).to be_success

    expect_namespace_not_to_exist(secrets_manager.full_namespace_path)
    expect_namespace_not_to_exist(
      [maintenance_task.org_path, maintenance_task.root_namespace_path].join('/')
    )
    expect_namespace_not_to_exist(maintenance_task.org_path)
  end

  context 'when the secrets manager record is already gone' do
    before do
      maintenance_task # eager-evaluate before nilifying the lookup
      allow(find_sm_target).to receive_messages(find_by_id: nil, find_by_project_id: nil, find_by_group_id: nil)
    end

    it 'still deprovisions OpenBao using paths from the maintenance task' do
      expect(result).to be_success

      expect_kv_secret_engine_not_to_be_mounted(
        maintenance_task.full_namespace_path,
        secrets_manager.ci_secrets_mount_path
      )
      expect(maintenance_task.class.find_by(id: maintenance_task.id)).to be_nil
    end
  end

  # Under the bulk transfer flow many workers run in parallel and each
  # tries to lazily disable the shared level-2 (root) and level-1 (org)
  # namespaces. The first worker that finds those parents empty
  # succeeds; the rest hit "route entry not found" because the parent
  # is already gone. That error must be rescued the same way as the
  # existing "containing child namespaces" sibling case.
  context 'when a parent namespace was already disabled by a concurrent worker' do
    let(:already_gone_error) do
      SecretsManagement::SecretsManagerClient::ApiError.new(
        'no handler for route "<path>". route entry not found.'
      )
    end

    context 'when the conflict is at the root (level-2) namespace' do
      before do
        flaky = instance_double(SecretsManagement::SecretsManagerClient)
        allow(flaky).to receive(:disable_namespace).and_raise(already_gone_error)

        allow_next_instance_of(described_class) do |svc|
          allow(svc).to receive(:org_secrets_manager_client).and_return(flaky)
        end
      end

      it 'rescues the error and completes the deprovision' do
        expect { result }.not_to raise_error
        expect(result).to be_success
        expect(secrets_manager.class.find_by(id: secrets_manager.id)).to be_nil
        expect(maintenance_task.class.find_by(id: maintenance_task.id)).to be_nil
      end
    end

    context 'when the conflict is at the org (level-1) namespace' do
      before do
        allow_next_instance_of(described_class) do |svc|
          allow(svc).to receive(:base_secrets_manager_client).and_wrap_original do |orig|
            client = orig.call
            allow(client).to receive(:disable_namespace).and_raise(already_gone_error)
            client
          end
        end
      end

      it 'rescues the error and completes the deprovision' do
        expect { result }.not_to raise_error
        expect(result).to be_success
        expect(secrets_manager.class.find_by(id: secrets_manager.id)).to be_nil
        expect(maintenance_task.class.find_by(id: maintenance_task.id)).to be_nil
      end
    end
  end
end

RSpec.shared_examples 'a secrets manager deprovision worker' do
  it 'looks up the maintenance task and runs the deprovision service' do
    expect(maintenance_task_class)
      .to receive(:find_by_id).with(maintenance_task.id).and_return(maintenance_task)
    expect(User).to receive(:find_by_id).with(user.id).and_return(user)

    service = instance_double(deprovision_service_class)
    expect(deprovision_service_class)
      .to receive(:new).with(maintenance_task, user).and_return(service)
    expect(service).to receive(:execute)

    worker.perform(maintenance_task.id)
  end

  context 'when the maintenance task is gone' do
    it 'returns without calling the service (idempotent)' do
      expect(deprovision_service_class).not_to receive(:new)
      expect { worker.perform(non_existing_record_id) }.not_to raise_error
    end
  end

  context 'when the user is gone' do
    before do
      allow(User).to receive(:find_by_id).with(user.id).and_return(nil)
    end

    it 'runs the deprovision service with a nil user (system context)' do
      service = instance_double(deprovision_service_class)
      expect(deprovision_service_class)
        .to receive(:new).with(maintenance_task, nil).and_return(service)
      expect(service).to receive(:execute)

      worker.perform(maintenance_task.id)
    end
  end

  context 'when the maintenance task has no user_id (trigger-created)' do
    before do
      maintenance_task.update_column(:user_id, nil)
    end

    it 'runs the deprovision service with a nil user without a user lookup' do
      expect(User).not_to receive(:find_by_id)

      service = instance_double(deprovision_service_class)
      expect(deprovision_service_class)
        .to receive(:new).with(maintenance_task, nil).and_return(service)
      expect(service).to receive(:execute)

      worker.perform(maintenance_task.id)
    end
  end
end

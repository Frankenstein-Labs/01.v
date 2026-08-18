# frozen_string_literal: true

# Drives the shared parts of project + group provision (task-based) worker
# specs.
#
# Including specs must provide:
# - `worker`                  -- described_class.new
# - `user`                    -- persisted user (referenced by maintenance_task.user)
# - `secrets_manager`         -- persisted SM record (returned by task.secrets_manager)
# - `maintenance_task`        -- persisted task with action: :provision
# - `provision_service_class` -- the scope-specific ProvisionService
# - `maintenance_task_class`  -- the scope-specific maintenance task model
RSpec.shared_examples 'a secrets manager provision worker' do
  let(:service) { instance_double(provision_service_class, execute: ServiceResponse.success) }

  it 'runs the provision service via the task and destroys the task on success' do
    expect(maintenance_task_class)
      .to receive(:find_by_id).with(maintenance_task.id).and_return(maintenance_task)
    expect(provision_service_class).to receive(:new).with(secrets_manager, user).and_return(service)
    expect(maintenance_task).to receive(:destroy)

    worker.perform(maintenance_task.id)
  end

  it 'does not destroy the task when the service fails' do
    allow(maintenance_task_class).to receive(:find_by_id).and_return(maintenance_task)
    allow(provision_service_class).to receive(:new).and_return(service)
    allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'boom'))

    expect(maintenance_task).not_to receive(:destroy)

    worker.perform(maintenance_task.id)
  end

  context 'when the maintenance task is gone' do
    it 'returns without calling the service (idempotent)' do
      expect(provision_service_class).not_to receive(:new)
      expect { worker.perform(non_existing_record_id) }.not_to raise_error
    end
  end

  context 'when the maintenance task is for the wrong action' do
    let(:wrong_action_task) do
      instance_double(maintenance_task_class, id: maintenance_task.id, provision?: false)
    end

    before do
      allow(maintenance_task_class).to receive(:find_by_id).with(wrong_action_task.id).and_return(wrong_action_task)
    end

    it 'returns without calling the service' do
      expect(provision_service_class).not_to receive(:new)
      worker.perform(wrong_action_task.id)
    end
  end

  context 'when the secrets manager is gone' do
    before do
      allow(maintenance_task_class).to receive(:find_by_id).and_return(maintenance_task)
      allow(maintenance_task).to receive(:secrets_manager).and_return(nil)
    end

    it 'returns without calling the service' do
      expect(provision_service_class).not_to receive(:new)
      worker.perform(maintenance_task.id)
    end
  end

  context 'when the user is gone' do
    before do
      allow(maintenance_task_class).to receive(:find_by_id).and_return(maintenance_task)
      allow(maintenance_task).to receive(:user).and_return(nil)
    end

    it 'returns without calling the service' do
      expect(provision_service_class).not_to receive(:new)
      worker.perform(maintenance_task.id)
    end
  end
end

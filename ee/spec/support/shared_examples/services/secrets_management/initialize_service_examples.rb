# frozen_string_literal: true

# Drives the cross-cutting parts of project + group InitializeService specs.
# Scope-specific assertions (snapshot id columns on the maintenance task,
# scope-only guard responses like the project's user-namespace rule) stay
# in the per-class spec.
#
# Including specs must provide:
# - `resource`                 -- project or group record
# - `service`                  -- described_class.new(resource, user)
# - `user`                     -- persisted user
# - `secrets_manager_class`    -- ProjectSecretsManager / GroupSecretsManager
# - `maintenance_task_class`   -- the scope-specific maintenance task model
# - `provision_worker_class`   -- the scope-specific provision worker
# - `payload_key`              -- :project_secrets_manager / :group_secrets_manager
# - `resource_type`            -- 'project' / 'group' (matches the
#                                 concern's derivation from `resource.class.name`)
# - `create_existing_secrets_manager` -- lambda that creates an SM tied to `resource`
RSpec.shared_examples 'a secrets manager initialize service' do
  subject(:result) { service.execute }

  let(:provision_worker_spy) { class_spy(provision_worker_class) }

  before do
    stub_const(provision_worker_class.name, provision_worker_spy)
  end

  context 'when the resource has no secrets manager' do
    it 'creates a provisioning secrets manager record', :aggregate_failures do
      expect(result).to be_success

      secrets_manager = result.payload[payload_key]
      expect(secrets_manager).to be_present
      expect(secrets_manager).to be_provisioning
    end

    it 'creates a provision maintenance task tied to the new SM', :aggregate_failures do
      expect { result }.to change { maintenance_task_class.count }.by(1)

      task = maintenance_task_class.last
      expect(task.user).to eq(user)
      expect(task.action).to eq('provision')
      expect(task.retry_count).to eq(0)
      expect(task.last_processed_at).to be_within(1.second).of(Time.current)
    end

    it 'enqueues the provision worker with the task id' do
      result

      task = maintenance_task_class.last
      expect(provision_worker_spy).to have_received(:perform_async).with(task.id)
    end

    it 'does not enqueue the worker until the transaction commits' do
      expect(maintenance_task_class).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'boom')

      expect { result }.to raise_error(ActiveRecord::StatementInvalid)
      expect(provision_worker_spy).not_to have_received(:perform_async)
      expect(resource.reload.secrets_manager).to be_nil
    end

    it 'keeps the SM and task persisted if the worker enqueue raises' do
      # Enqueue is outside the transaction so a Redis blip (or any other
      # failure on `perform_async`) does NOT roll back the SM or task
      # record. The next cron tick picks up the stale task and re-enqueues.
      allow(provision_worker_spy).to receive(:perform_async).and_raise(StandardError, 'redis down')

      expect { service.execute }.to raise_error(StandardError, 'redis down')

      expect(resource.reload.secrets_manager).to be_present
      expect(resource.secrets_manager).to be_provisioning
      expect(maintenance_task_class.count).to eq(1)
      expect(maintenance_task_class.last.action).to eq('provision')
    end
  end

  context 'when the resource already has a secrets manager' do
    before do
      create_existing_secrets_manager.call
      resource.reload
    end

    it 'fails' do
      expect(result).to be_error
      expect(result.message).to eq("Secrets manager already initialized for the #{resource_type}.")
      expect(provision_worker_spy).not_to have_received(:perform_async)
      expect(maintenance_task_class.count).to eq(0)
    end
  end
end

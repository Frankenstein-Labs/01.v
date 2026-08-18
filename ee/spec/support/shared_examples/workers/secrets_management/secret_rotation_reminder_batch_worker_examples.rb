# frozen_string_literal: true

RSpec.shared_examples 'a secret rotation reminder batch worker' do
  # Note: The including spec must define:
  # - service_class: the concrete service class
  # - resource: the project or group owning the secrets
  # - owner: the owner user
  # - secrets_manager: the secrets manager record
  # - mail_name: the mailer method name string
  # - rotation_infos: AR relation for rotation info records
  # - def provision_secrets_manager: provisions the secrets manager
  # - def create_pending_secrets: creates 3 overdue secrets (next_reminder_at in the past)

  before do
    stub_const('SecretsManagement::BaseSecretRotationBatchReminderService::BATCH_SIZE', 2)
  end

  describe '#perform' do
    let(:worker) { described_class.new }

    subject(:run_worker) { worker.perform }

    it 'continues processing until processed_count + skipped_count is less than batch size' do
      batch_size = SecretsManagement::BaseSecretRotationBatchReminderService::BATCH_SIZE

      expect_next_instance_of(service_class) do |service|
        expect(service).to receive(:execute)
          .exactly(3).times
          .and_return(
            { processed_count: batch_size - 1, skipped_count: 1 },
            { processed_count: batch_size - 3, skipped_count: 3 },
            { processed_count: 1, skipped_count: 0 }
          )
      end

      expect(worker).to receive(:log_extra_metadata_on_done)
        .with(:result, {
          status: :completed,
          processed_secrets: (batch_size - 1) + (batch_size - 3) + 1,
          skipped_secrets: 1 + 3 + 0
        })

      run_worker
    end

    context 'when database is read-only' do
      before do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
      end

      it 'returns early without performing any writes' do
        expect(service_class).not_to receive(:new)

        run_worker
      end
    end

    context 'when runtime limit is exceeded' do
      it 'stops processing even with full batches and logs limit_reached status' do
        expect_next_instance_of(service_class) do |service|
          expect(service).to receive(:execute).and_return({
            processed_count: 2,
            skipped_count: 0
          })
        end

        expect_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
          allow(runtime_limiter).to receive(:over_time?).and_return(true)
        end

        expect(worker).to receive(:log_extra_metadata_on_done)
          .with(:result, {
            status: :limit_reached,
            processed_secrets: 2,
            skipped_secrets: 0
          })

        run_worker
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    before do
      provision_secrets_manager(secrets_manager, owner)
      create_pending_secrets
      reset_delivered_emails!
    end

    it 'processes all pending reminders when called multiple times' do
      rotation_infos.each do |rotation_info|
        expect(rotation_info.last_reminder_at).to be_nil
        expect(rotation_info.next_reminder_at).to be_past
      end

      perform_idempotent_work

      rotation_infos.each do |rotation_info|
        expect_enqueud_email(owner.id, resource.id, rotation_info.secret_name, mail: mail_name)
        rotation_info.reload
        expect(rotation_info.last_reminder_at).to be_present
        expect(rotation_info.next_reminder_at).to be_future
      end
    end
  end
end

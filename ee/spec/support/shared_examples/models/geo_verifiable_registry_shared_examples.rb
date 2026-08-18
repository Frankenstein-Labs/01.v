# frozen_string_literal: true

RSpec.shared_examples 'a Geo verifiable registry' do
  let(:registry_class_factory) { described_class.underscore.tr('/', '_').to_sym }

  subject(:registry_record) { create(registry_class_factory, :synced) }

  context 'state machine' do
    context 'when transitioning to synced' do
      let(:registry) { create(registry_class_factory, :started) }

      it 'marks verification as pending' do
        allow(registry).to receive(:ready_to_verify?).and_return(true)

        registry.synced!

        expect(registry.reload).to be_verification_pending
      end

      context 'when the model_record cannot be verified' do
        before do
          allow(registry).to receive(:ready_to_verify?).and_return(false)
        end

        context 'when the registry is already verification_disabled' do
          let(:registry) { create(registry_class_factory, :started, verification_state: verification_state_value(:verification_disabled)) }

          it 'changes verification to disabled' do
            registry.synced!

            expect(registry.reload).to be_verification_disabled
          end
        end

        context 'when the registry is verification_pending' do
          let(:registry) { create(registry_class_factory, :started) }

          it 'changes verification to disabled' do
            registry.synced!

            expect(registry.reload).to be_verification_disabled
          end
        end
      end
    end

    context 'when transitioning to pending' do
      context 'when synced' do
        let(:registry) { create(registry_class_factory, :synced) }

        it 'marks verification as disabled' do
          registry.pending!

          expect(registry.reload).to be_verification_disabled
        end
      end

      context 'when failed' do
        let(:registry) { create(registry_class_factory, :failed) }

        it 'marks verification as disabled' do
          registry.pending!

          expect(registry.reload).to be_verification_disabled
        end
      end
    end

    context 'when transitioning to started' do
      context 'when brand-new pending' do
        let(:registry) { create(registry_class_factory) } # rubocop:disable Rails/SaveBang -- FactoryBot method

        it 'keeps verification pending so the skip-download optimization still applies', :aggregate_failures do
          registry.start!

          expect(registry.reload).to be_verification_pending
          expect(registry.brand_new_pending?).to be_truthy
        end
      end

      context 'when synced' do
        let(:registry) { create(registry_class_factory, :synced) }

        it 'marks verification as disabled' do
          registry.start!

          expect(registry.reload).to be_verification_disabled
        end
      end

      context 'when failed' do
        let(:registry) { create(registry_class_factory, :failed) }

        it 'marks verification as disabled' do
          registry.start!

          expect(registry.reload).to be_verification_disabled
        end
      end

      context 'when verification_failed with a blank verification_failure' do
        # Regression test for https://gitlab.com/gitlab-org/gitlab/-/issues/562921
        let(:registry) do
          create(registry_class_factory, :failed,
            verification_state: verification_state_value(:verification_failed),
            verification_failure: 'temp')
        end

        before do
          # Reproduce the invalid data state the way these rows exist in
          # production: verification_failed with a NULL verification_failure.
          # update_column bypasses the presence validation.
          registry.update_column(:verification_failure, nil)
        end

        it 'does not raise and disables verification', :aggregate_failures do
          expect { registry.start! }.not_to raise_error
          expect(registry.reload).to be_verification_disabled
        end
      end
    end

    context 'when a verification failure triggers a resync' do
      # A verification failure calls `failed` (see #before_verification_failed),
      # and the resync's `:start` transition disables verification. The
      # verification failure fields must survive that round trip, otherwise
      # `verification_retry_count` resets on every resync and can never exceed 1.
      let(:registry) { create(registry_class_factory, :synced) }

      before do
        allow(registry).to receive(:ready_to_verify?).and_return(true)
      end

      it 'accumulates verification_retry_count across resyncs', :aggregate_failures do
        3.times do |attempt|
          registry.verification_failed_with_message!('Checksum does not match the primary checksum')

          expect(registry.reload.verification_retry_count).to eq(attempt + 1)

          # The resync scheduled by the verification failure. The data is fine,
          # so it succeeds.
          registry.start!
          registry.synced!

          expect(registry.reload).to be_verification_pending
          expect(registry.verification_retry_count).to eq(attempt + 1)
        end
      end

      it 'clears verification_retry_count once verification succeeds' do
        registry.verification_failed_with_message!('Checksum does not match the primary checksum')
        registry.start!
        registry.synced!

        registry.verification_started!
        registry.verification_succeeded_with_checksum!('abc123', Time.current)

        expect(registry.reload.verification_retry_count).to eq(0)
      end
    end
  end

  context 'verification_state machine' do
    context 'when transitioning to verification_failed' do
      it 'changes state from synced to failed' do
        registry = create(registry_class_factory, :synced)

        registry.verification_failed_with_message!('foo')

        expect(registry.reload).to be_failed
        expect(registry.verification_failure).to eq('foo')
        expect(registry.last_sync_failure).to eq('Verification failed with: foo')
        expect(registry.retry_count).to eq(1)
      end
    end
  end

  describe '.verification_pending_batch' do
    before do
      subject.save!
    end

    it 'returns IDs of rows which are synced and pending verification' do
      expect(described_class.verification_pending_batch(batch_size: 4)).to match_array([subject.model_record_id])
    end

    it 'excludes rows which are not synced or are not pending verification' do
      create(registry_class_factory, verification_state: verification_state_value(:verification_pending))
      create(registry_class_factory, :started, verification_state: verification_state_value(:verification_pending))
      create(registry_class_factory, :failed, verification_state: verification_state_value(:verification_pending))
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_failed), verification_failure: 'foo')
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_started))
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_succeeded), verification_checksum: 'abc123')
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_disabled))
      expect(described_class.verification_pending_batch(batch_size: 4)).to match_array([subject.model_record_id])
    end

    it 'marks verification as started' do
      described_class.verification_pending_batch(batch_size: 4)

      expect(subject.reload.verification_started?).to be_truthy
      expect(subject.verification_started_at).to be_present
    end

    it 'logs the verification state transition' do
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_pending))

      expect(Gitlab::Geo::Logger).to receive(:debug).with(hash_including(
        message: 'Batch verification state transition',
        table: described_class.table_name,
        "#{described_class.verification_state_model_key}": match(/\d+,\d+/),
        count: 2,
        from: 'verification_pending',
        to: 'verification_started',
        method: 'verification_pending_batch'
      ))

      described_class.verification_pending_batch(batch_size: 4)
    end
  end

  describe '.verification_failed_batch' do
    before do
      # The setup is unusual because we don't want
      # `before_verification_failure` to set the sync state to `:failed`.
      # This lets us test things that are synced but failed verification, which
      # should not happen anymore, but may exist from before we implemented
      # automatic resync of verification failures.
      subject.synced!
      subject.verification_state = verification_state_value(:verification_failed)
      subject.verification_failure = 'foo'
      subject.verification_retry_count = 1
      subject.verified_at = Time.current
      subject.verification_retry_at = verification_retry_at
      subject.save!
    end

    context 'with a failed record with retry due' do
      let(:verification_retry_at) { 1.minute.ago }

      it 'returns IDs of rows which are synced and have failed verification' do
        expect(described_class.verification_failed_batch(batch_size: 4)).to match_array([subject.model_record_id])
      end

      it 'excludes rows which are not synced or have not failed verification' do
        create(registry_class_factory, verification_state: verification_state_value(:verification_failed), verification_failure: 'foo')
        create(registry_class_factory, :started, verification_state: verification_state_value(:verification_failed), verification_failure: 'foo')
        create(registry_class_factory, :failed, verification_state: verification_state_value(:verification_failed), verification_failure: 'foo')
        create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_pending))
        create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_started))
        create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_succeeded), verification_checksum: 'abc123')
        create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_disabled))
        expect(described_class.verification_failed_batch(batch_size: 4)).to match_array([subject.model_record_id])
      end

      it 'marks verification as started' do
        described_class.verification_failed_batch(batch_size: 4)

        expect(subject.reload.verification_started?).to be_truthy
        expect(subject.verification_started_at).to be_present
      end

      it 'logs the verification state transition' do
        expect(Gitlab::Geo::Logger).to receive(:debug).with(hash_including(
          message: 'Batch verification state transition',
          table: described_class.table_name,
          "#{described_class.verification_state_model_key}": match(/\d+/),
          count: 1,
          from: 'verification_failed',
          to: 'verification_started',
          method: 'verification_failed_batch'
        ))

        described_class.verification_failed_batch(batch_size: 4)
      end
    end

    context 'when verification_retry_at is in the future' do
      let(:verification_retry_at) { 1.minute.from_now }

      it 'does not return the row which failed verification' do
        expect(subject.class.verification_failed_batch(batch_size: 4)).not_to include(subject.model_record_id)
      end
    end
  end

  describe '.needs_verification_count' do
    before do
      subject.save!
    end

    it 'returns the number of rows which are synced and pending verification' do
      expect(described_class.needs_verification_count(limit: 3)).to eq(1)
    end

    it 'includes rows which are synced and failed verification and are due for retry' do
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_failed), verification_failure: 'foo', verification_retry_at: 1.minute.ago)

      expect(described_class.needs_verification_count(limit: 3)).to eq(2)
    end

    it 'excludes rows which are synced and failed verification and have a future retry time' do
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_failed), verification_failure: 'foo', verification_retry_at: 1.minute.from_now)

      expect(described_class.needs_verification_count(limit: 3)).to eq(1)
    end

    it 'excludes rows which are not synced or are not (pending or failed) verification' do
      create(registry_class_factory, verification_state: verification_state_value(:verification_pending))
      create(registry_class_factory, :started, verification_state: verification_state_value(:verification_pending))
      create(registry_class_factory, :failed, verification_state: verification_state_value(:verification_pending))
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_started))
      create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_succeeded), verification_checksum: 'abc123')
      expect(described_class.needs_verification_count(limit: 3)).to eq(1)
    end
  end

  describe '.persistent_checksum_mismatches' do
    before do
      subject.save!
    end

    it 'returns rows with a checksum mismatch at or above the threshold' do
      subject.update!(checksum_mismatch: true, verification_retry_count: 3)

      expect(described_class.persistent_checksum_mismatches(3)).to match_array([subject])
    end

    it 'excludes rows below the threshold' do
      subject.update!(checksum_mismatch: true, verification_retry_count: 2)

      expect(described_class.persistent_checksum_mismatches(3)).to be_empty
    end

    it 'excludes rows without a checksum mismatch' do
      subject.update!(checksum_mismatch: false, verification_retry_count: 5)

      expect(described_class.persistent_checksum_mismatches(3)).to be_empty
    end
  end

  describe '#verification_succeeded!', :aggregate_failures do
    before do
      subject.verification_started!
    end

    it 'clears checksum mismatch fields' do
      subject.update!(checksum_mismatch: true, verification_checksum_mismatched: 'abc123')
      subject.verification_checksum = 'abc123'

      expect do
        subject.verification_succeeded!
      end.to change { subject.verification_succeeded? }.from(false).to(true)

      expect(subject.checksum_mismatch).to eq(false)
      expect(subject.verification_checksum_mismatched).to eq(nil)
    end
  end

  describe '#track_checksum_attempt!', :aggregate_failures do
    context 'when verification was not yet started' do
      it 'starts verification' do
        allow(subject).to receive(:ready_to_verify?).and_return(true)

        expect do
          subject.track_checksum_attempt! do
            'a_checksum_value'
          end
        end.to change { subject.verification_started_at }.from(nil)
      end

      context 'when the model record cannot be verified' do
        before do
          allow(registry).to receive(:ready_to_verify?).and_return(false)
        end

        context 'when the registry is already verification_disabled' do
          let(:registry) { create(registry_class_factory, :synced, verification_state: verification_state_value(:verification_disabled)) }

          it 'leaves verification as disabled' do
            expect do
              registry.track_checksum_attempt! do
                ''
              end
            end.not_to change { registry.verification_disabled? }
          end
        end

        context 'when the registry is verification_pending' do
          let(:registry) { create(registry_class_factory, :synced) }

          it 'changes verification to disabled' do
            expect do
              registry.track_checksum_attempt! do
                ''
              end
            end.to change { registry.verification_disabled? }.from(false).to(true)
          end
        end
      end

      context 'when the primary site is expected to checksum the model record' do
        before do
          allow(replicator).to receive(:primary_verification_succeeded?).and_return(true)
        end

        context 'comparison with primary checksum' do
          let(:replicator) { double('replicator') }
          let(:calculated_checksum) { 'abc123' }

          before do
            allow(subject).to receive(:replicator).and_return(replicator)
            allow(replicator).to receive(:matches_checksum?).with(calculated_checksum).and_return(matches_checksum)
          end

          context 'when the calculated checksum matches the primary checksum' do
            let(:matches_checksum) { true }

            it 'transitions to verification_succeeded and updates the checksum' do
              expect do
                subject.track_checksum_attempt! do
                  calculated_checksum
                end
              end.to change { subject.verification_succeeded? }.from(false).to(true)
              expect(replicator.matches_checksum?(calculated_checksum)).to eq(matches_checksum)
              expect(subject.verification_checksum).to eq(calculated_checksum)
            end
          end

          context 'when the calculated checksum does not match the primary checksum' do
            let(:matches_checksum) { false }
            let(:primary_checksum) { '123abc' }

            it 'transitions to verification_failed and updates mismatch fields' do
              allow(replicator).to receive(:primary_checksum).and_return(primary_checksum)

              expect do
                subject.track_checksum_attempt! do
                  calculated_checksum
                end
              end.to change { subject.verification_failed? }.from(false).to(true)
              expect(replicator.matches_checksum?(calculated_checksum)).to eq(matches_checksum)
              expect(subject.verification_checksum).to eq(calculated_checksum)
              expect(subject.verification_checksum_mismatched).to eq(primary_checksum)
              expect(subject.checksum_mismatch).to eq(true)
              expect(subject.verification_failure).to match('Checksum does not match the primary checksum')
            end
          end
        end
      end
    end

    context 'when verification was started' do
      it 'does not update verification_started_at' do
        allow(subject).to receive(:ready_to_verify?).and_return(true)

        subject.verification_started!
        expected = subject.verification_started_at

        subject.track_checksum_attempt! do
          'a_checksum_value'
        end

        expect(subject.verification_started_at).to be_within(1.second).of(expected)
      end
    end

    it 'yields to the checksum calculation' do
      allow(subject).to receive(:ready_to_verify?).and_return(true)

      expect do |probe|
        subject.track_checksum_attempt!(&probe)
      end.to yield_with_no_args
    end

    context 'when an error occurs while yielding' do
      it 'sets verification_failed' do
        allow(subject).to receive(:ready_to_verify?).and_return(true)

        subject.track_checksum_attempt! do
          raise 'an error'
        end

        expect(subject.reload.verification_failed?).to be_truthy
      end
    end
  end

  describe '#brand_new_pending?' do
    it 'returns true when sync state is pending and all other fields are default' do
      registry = create(registry_class_factory) # rubocop:disable Rails/SaveBang -- FactoryBot method

      expect(registry.brand_new_pending?).to be_truthy
    end

    it 'returns true when started but all other fields are default' do
      registry = create(registry_class_factory, :started)

      expect(registry.brand_new_pending?).to be_truthy
    end

    it 'returns false when sync state is synced' do
      registry = create(registry_class_factory, :synced)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when sync state is failed' do
      registry = create(registry_class_factory, :failed)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when it is pending but was synced before' do
      registry = create(registry_class_factory, last_synced_at: 1.hour.ago)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when it is scheduled to retry sync' do
      registry = create(registry_class_factory, retry_at: 1.day.from_now)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when it was tried before' do
      registry = create(registry_class_factory, retry_count: 1)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when it has a sync failure message' do
      registry = create(registry_class_factory, last_sync_failure: 'foo')

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when verification succeeded' do
      registry = create(registry_class_factory, :verification_succeeded)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when verification failed' do
      registry = create(registry_class_factory, :verification_failed)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when verification started' do
      registry = create(registry_class_factory, verification_state: 1)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when it was verified before' do
      registry = create(registry_class_factory, verified_at: 2.days.ago)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when verification was started before' do
      registry = create(registry_class_factory, verification_started_at: 3.minutes.ago)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when verification is scheduled for retry' do
      registry = create(registry_class_factory, verification_retry_at: 3.hours.from_now)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when verification was tried before' do
      registry = create(registry_class_factory, verification_retry_count: 4)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when checksum mismatched before' do
      registry = create(registry_class_factory, checksum_mismatch: true)

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when it has a local checksum from before' do
      registry = create(registry_class_factory, verification_checksum: 'abc123')

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when verification mismatched before' do
      registry = create(registry_class_factory, verification_checksum_mismatched: '111111')

      expect(registry.brand_new_pending?).to be_falsey
    end

    it 'returns false when there is a verification failure message from before' do
      registry = create(registry_class_factory, verification_failure: 'foo')

      expect(registry.brand_new_pending?).to be_falsey
    end
  end

  def verification_state_value(key)
    described_class.verification_state_value(key)
  end
end

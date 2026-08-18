# frozen_string_literal: true

# This should be included on any Replicator which implements verification.
#
# Expected let variables:
#
# - primary
# - secondary
# - model_record
# - replicator
#

RSpec.shared_examples 'a counter of succeeded available verifiables' do |count_method|
  specify do
    verifiable.verification_started!
    verifiable.verification_succeeded_with_checksum!('some checksum', Time.current)

    expect(described_class.send(count_method)).to eq(1)
  end

  it 'excludes other verification states' do
    verifiable.verification_started!

    expect(described_class.send(count_method)).to eq(0)

    verifiable.verification_failed_with_message!('some error message')

    expect(described_class.send(count_method)).to eq(0)

    verifiable.verification_pending!

    expect(described_class.send(count_method)).to eq(0)
  end
end

RSpec.shared_examples 'a counter of failed available verifiables' do |count_method|
  specify do
    verifiable.verification_started!
    verifiable.verification_failed_with_message!('some error message')

    # This bypasses the registry state attribute to :synced again
    # since available_verifiables return synced registries
    # and we need that state to count it properly.
    verifiable.update_attribute(:state, 2) if count_method == :verification_failed_count

    expect(described_class.send(count_method)).to eq(1)
  end

  it 'excludes other verification states' do
    verifiable.verification_started!

    expect(described_class.send(count_method)).to eq(0)

    verifiable.verification_succeeded_with_checksum!('foo', Time.current)

    expect(described_class.send(count_method)).to eq(0)

    verifiable.verification_pending!

    expect(described_class.send(count_method)).to eq(0)
  end
end

RSpec.shared_examples 'a verifiable replicator' do
  include EE::GeoHelpers

  describe 'events' do
    it 'has checksum_succeeded event' do
      expect(described_class.supported_events).to include(:checksum_succeeded)
    end
  end

  describe '.verification_enabled?' do
    let(:replicable_name) { described_class.replicable_name }

    context 'on a Geo primary site' do
      before do
        stub_primary_site
      end

      context 'when replication feature flag is enabled' do
        before do
          stub_feature_flags("geo_#{replicable_name}_replication" => true)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'returns true' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => true)

            expect(described_class.verification_enabled?).to be_truthy
          end
        end

        context 'when the force primary checksumming feature flag is disabled' do
          it 'returns true' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => false)

            expect(described_class.verification_enabled?).to be_truthy
          end
        end
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags("geo_#{replicable_name}_replication" => false)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'returns true' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => true)

            expect(described_class.verification_enabled?).to be_truthy
          end
        end

        context 'when the force primary checksumming feature flag is disabled' do
          it 'returns false' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => false)

            expect(described_class.verification_enabled?).to be_falsey
          end
        end
      end
    end

    context 'on a Geo secondary site' do
      before do
        stub_secondary_site
      end

      context 'when replication feature flag is enabled' do
        before do
          stub_feature_flags("geo_#{replicable_name}_replication" => true)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'returns true' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => true)

            expect(described_class.verification_enabled?).to be_truthy
          end
        end

        context 'when the force primary checksumming feature flag is disabled' do
          it 'returns true' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => false)

            expect(described_class.verification_enabled?).to be_truthy
          end
        end
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags("geo_#{replicable_name}_replication" => false)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'returns false' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => true)

            expect(described_class.verification_enabled?).to be_falsey
          end
        end

        context 'when the force primary checksumming feature flag is disabled' do
          it 'returns false' do
            stub_feature_flags("geo_#{replicable_name}_force_primary_checksumming" => false)

            expect(described_class.verification_enabled?).to be_falsey
          end
        end
      end
    end
  end

  describe '.checksummed_count' do
    before do
      stub_primary_node
    end

    context 'when verification is enabled' do
      let(:verifiable) { model_record }

      before do
        # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
        # is not allowed within a transaction but all RSpec tests run inside of a transaction.
        stub_batch_counter_transaction_open_check

        allow(described_class).to receive(:verification_enabled?).and_return(true)
      end

      it_behaves_like 'a counter of succeeded available verifiables', :checksummed_count

      context 'when there are no records' do
        it 'returns 0' do
          allow(described_class).to receive(:model_max_primary_key).and_return(nil)

          expect(described_class.checksummed_count).to eq(0)
        end
      end
    end

    context 'when verification is disabled' do
      it 'returns nil' do
        allow(described_class).to receive(:verification_enabled?).and_return(false)

        expect(described_class.checksummed_count).to be_nil
      end
    end
  end

  describe '.verified_count' do
    context 'when verification is enabled' do
      let(:verifiable) { replicator.registry }

      before do
        model_record.save!

        allow(described_class).to receive(:verification_enabled?).and_return(true)

        # Verification on the secondary requires a synced registry
        verifiable.start
        verifiable.synced!

        # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
        # is not allowed within a transaction but all RSpec tests run inside of a transaction.
        stub_batch_counter_transaction_open_check
      end

      it_behaves_like 'a counter of succeeded available verifiables', :verified_count
    end

    context 'when verification is disabled' do
      it 'returns nil' do
        allow(described_class).to receive(:verification_enabled?).and_return(false)

        expect(described_class.verified_count).to be_nil
      end
    end
  end

  describe '.checksum_failed_count' do
    before do
      stub_primary_node
    end

    context 'when verification is enabled' do
      let(:verifiable) { model_record }

      before do
        # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
        # is not allowed within a transaction but all RSpec tests run inside of a transaction.
        stub_batch_counter_transaction_open_check
      end

      it_behaves_like 'a counter of failed available verifiables', :checksum_failed_count

      context 'when there are no records' do
        it 'returns 0' do
          allow(described_class).to receive(:model_max_primary_key).and_return(nil)

          expect(described_class.checksum_failed_count).to eq(0)
        end
      end
    end

    context 'when verification is disabled' do
      it 'returns nil' do
        allow(described_class).to receive(:verification_enabled?).and_return(false)

        expect(described_class.checksum_failed_count).to be_nil
      end
    end
  end

  describe '.verification_failed_count' do
    context 'when verification is enabled' do
      let(:verifiable) { replicator.registry }

      before do
        model_record.save!

        allow(described_class).to receive(:verification_enabled?).and_return(true)

        # Verification on the secondary requires a synced registry
        verifiable.start
        verifiable.synced!

        # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
        # is not allowed within a transaction but all RSpec tests run inside of a transaction.
        stub_batch_counter_transaction_open_check
      end

      it_behaves_like 'a counter of failed available verifiables', :verification_failed_count
    end

    context 'when verification is disabled' do
      it 'returns nil' do
        allow(described_class).to receive(:verification_enabled?).and_return(false)

        expect(described_class.verification_failed_count).to be_nil
      end
    end
  end

  describe '.verification_total_count' do
    context 'when verification is enabled' do
      let(:verifiable) { replicator.registry }

      before do
        model_record.save!

        allow(described_class).to receive(:verification_enabled?).and_return(true)

        # Verification on the secondary requires a synced registry
        verifiable.start
        verifiable.synced!

        # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
        # is not allowed within a transaction but all RSpec tests run inside of a transaction.
        stub_batch_counter_transaction_open_check
      end

      context 'when the verification_state is disabled' do
        specify do
          verifiable.verification_disabled!

          expect(described_class.verification_total_count).to eq(0)
        end
      end

      context 'when the verification_state is not disabled' do
        specify do
          verifiable.verification_started!

          expect(described_class.verification_total_count).to eq(1)
        end
      end
    end

    context 'when verification is disabled' do
      it 'returns nil' do
        allow(described_class).to receive(:verification_enabled?).and_return(false)

        expect(described_class.verification_total_count).to be_nil
      end
    end
  end

  describe '.checksum_total_count' do
    context 'when verification is enabled' do
      before do
        model_record.verification_started!
        model_record.save!

        allow(described_class).to receive(:verification_enabled?).and_return(true)

        # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
        # is not allowed within a transaction but all RSpec tests run inside a transaction.
        stub_batch_counter_transaction_open_check
      end

      it 'returns the number of records' do
        expect(described_class.checksum_total_count).to eq(1)
      end

      context 'when there are no records' do
        before do
          model_record.delete
        end

        it 'returns 0' do
          expect(described_class.checksum_total_count).to eq(0)
        end
      end
    end

    context 'when verification is disabled' do
      it 'returns nil' do
        allow(described_class).to receive(:verification_enabled?).and_return(false)

        expect(described_class.checksum_total_count).to be_nil
      end
    end
  end

  describe '.primary_total_count' do
    before do
      # BatchCounter is not allowed within a transaction, but all RSpec tests
      # run inside a transaction.
      stub_batch_counter_transaction_open_check
    end

    it 'passes the unscoped primary-key MAX to model_batch_count as the finish bound' do
      # Persist a record so the unscoped MAX is a real, non-nil value. This
      # proves the override avoids BatchCounter's internal scoped MAX, which is
      # a sequential scan on large or joined available_replicables relations.
      # Correctness of the returned count is covered by the shared example in
      # replicator_shared_examples.rb.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/598940.
      model_record.save!

      expect(described_class).to receive(:model_batch_count)
        .with(anything, hash_including(max_key: described_class.send(:model_max_primary_key)))
        .and_call_original

      described_class.primary_total_count
    end

    context 'when there are no records' do
      it 'returns 0' do
        allow(described_class).to receive(:model_max_primary_key).and_return(nil)

        expect(described_class.primary_total_count).to eq(0)
      end
    end
  end

  describe '.trigger_background_verification' do
    context 'when verification is enabled' do
      before do
        allow(described_class).to receive(:verification_enabled?).and_return(true)
      end

      shared_examples 'enqueues verification workers' do
        it 'enqueues VerificationBatchWorker' do
          expect(::Geo::VerificationBatchWorker).to receive(:perform_with_capacity).with(described_class.replicable_name)

          described_class.trigger_background_verification
        end

        it 'enqueues VerificationTimeoutWorker' do
          expect(::Geo::VerificationTimeoutWorker).to receive(:perform_async).with(described_class.replicable_name)

          described_class.trigger_background_verification
        end
      end

      context 'for a Geo secondary' do
        before do
          stub_current_geo_node(secondary)
        end

        it 'does not enqueue ReverificationBatchWorker' do
          expect(::Geo::ReverificationBatchWorker).not_to receive(:perform_with_capacity)

          described_class.trigger_background_verification
        end

        include_examples 'enqueues verification workers'
      end

      context 'for a Geo primary' do
        before do
          stub_current_geo_node(primary)
        end

        it 'enqueues ReverificationBatchWorker' do
          expect(::Geo::ReverificationBatchWorker).to receive(:perform_with_capacity).with(described_class.replicable_name)

          described_class.trigger_background_verification
        end

        it 'enqueues VerificationStateBackfillWorker' do
          expect(described_class.model).to receive(:separate_verification_state_table?).and_return(true)
          expect(::Geo::VerificationStateBackfillWorker).to receive(:perform_async).with(described_class.replicable_name)

          described_class.trigger_background_verification
        end

        include_examples 'enqueues verification workers'
      end
    end

    context 'when verification is disabled' do
      before do
        allow(described_class).to receive(:verification_enabled?).and_return(false)
      end

      it 'does not enqueue VerificationBatchWorker' do
        expect(::Geo::VerificationBatchWorker).not_to receive(:perform_with_capacity)

        described_class.trigger_background_verification
      end

      it 'does not enqueue VerificationTimeoutWorker' do
        expect(::Geo::VerificationTimeoutWorker).not_to receive(:perform_async)

        described_class.trigger_background_verification
      end
    end
  end

  describe '.backfill_verification_state_table' do
    context 'on a Geo secondary site' do
      before do
        stub_secondary_node
      end

      it 'returns false' do
        expect(described_class.backfill_verification_state_table).to be_falsy
      end
    end

    context 'on a Geo primary site' do
      let(:replication_feature_flag) { "geo_#{replicator.replicable_name}_replication" }
      let(:force_primary_checksumming_feature_flag) { "geo_#{replicator.replicable_name}_force_primary_checksumming" }

      before do
        stub_primary_node
      end

      context 'when replication feature flag is enabled' do
        before do
          stub_feature_flags(replication_feature_flag => true)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'calls Geo::VerificationStateBackfillService' do
            stub_feature_flags(force_primary_checksumming_feature_flag => true)

            expect_next_instance_of(Geo::VerificationStateBackfillService) do |service|
              expect(service).to receive(:execute).and_return(true)
            end

            described_class.backfill_verification_state_table
          end
        end

        context 'when force primary checksumming feature flag is disabled' do
          it 'calls Geo::VerificationStateBackfillService' do
            stub_feature_flags(force_primary_checksumming_feature_flag => false)

            expect_next_instance_of(Geo::VerificationStateBackfillService) do |service|
              expect(service).to receive(:execute).and_return(true)
            end

            described_class.backfill_verification_state_table
          end
        end
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(replication_feature_flag => false)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'calls Geo::VerificationStateBackfillService' do
            stub_feature_flags(force_primary_checksumming_feature_flag => true)

            expect_next_instance_of(Geo::VerificationStateBackfillService) do |service|
              expect(service).to receive(:execute).and_return(true)
            end

            described_class.backfill_verification_state_table
          end
        end

        context 'when force primary checksumming feature flag is disabled' do
          it 'does not call Geo::VerificationStateBackfillService' do
            stub_feature_flags(force_primary_checksumming_feature_flag => false)

            expect(Geo::VerificationStateBackfillService).not_to receive(:new)

            described_class.backfill_verification_state_table
          end
        end
      end
    end
  end

  describe '.verify_batch' do
    context 'when there are records needing verification' do
      let(:another_replicator) { double('another_replicator', verify: true) }
      let(:replicators) { [replicator, another_replicator] }

      before do
        allow(described_class).to receive(:replicator_batch_to_verify).and_return(replicators)
      end

      it 'calls #verify on each replicator' do
        expect(replicator).to receive(:verify)
        expect(another_replicator).to receive(:verify)

        described_class.verify_batch
      end
    end
  end

  describe '.remaining_verification_batch_count' do
    it 'converts needs_verification_count to number of batches' do
      expected_limit = 40
      expect(described_class).to receive(:needs_verification_count).with(limit: expected_limit).and_return(21)

      expect(described_class.remaining_verification_batch_count(max_batch_count: 4)).to eq(3)
    end
  end

  describe '.remaining_reverification_batch_count' do
    it 'converts needs_reverification_count to number of batches' do
      expected_limit = 4000
      expect(described_class).to receive(:needs_reverification_count).with(limit: expected_limit).and_return(1500)

      expect(described_class.remaining_reverification_batch_count(max_batch_count: 4)).to eq(2)
    end
  end

  describe '.reverify_batch!' do
    it 'calls #reverify_batch' do
      allow(described_class).to receive(:reverify_batch).with(batch_size: described_class::DEFAULT_REVERIFICATION_BATCH_SIZE)

      described_class.reverify_batch!
    end
  end

  describe '.replicator_batch_to_verify' do
    it 'returns usable Replicator instances' do
      model_record.save!

      expect(described_class).to receive(:model_record_id_batch_to_verify).and_return([model_record.id])

      first_result = described_class.replicator_batch_to_verify.first

      expect(first_result.class).to eq(described_class)
      expect(first_result.model_record_id).to eq(model_record.id)
    end
  end

  describe '.model_record_id_batch_to_verify' do
    let(:pending_ids) { [1, 2] }

    before do
      allow(described_class).to receive(:verification_batch_size).and_return(verification_batch_size)
      allow(described_class).to receive(:verification_pending_batch).with(batch_size: verification_batch_size).and_return(pending_ids)
    end

    context 'when the batch is filled by pending rows' do
      let(:verification_batch_size) { 2 }

      it 'returns IDs of pending rows' do
        expect(described_class.model_record_id_batch_to_verify).to eq(pending_ids)
      end

      it 'does not call .verification_failed_batch' do
        expect(described_class).not_to receive(:verification_failed_batch)

        described_class.model_record_id_batch_to_verify
      end
    end

    context 'when that batch is not filled by pending rows' do
      let(:failed_ids) { [3, 4, 5] }
      let(:verification_batch_size) { 5 }

      it 'includes IDs of failed rows' do
        remaining_capacity = verification_batch_size - pending_ids.size

        allow(described_class).to receive(:verification_failed_batch).with(batch_size: remaining_capacity).and_return(failed_ids)

        result = described_class.model_record_id_batch_to_verify

        expect(result).to include(*pending_ids)
        expect(result).to include(*failed_ids)
      end
    end
  end

  describe '.verification_pending_batch' do
    context 'when current node is a primary' do
      it 'delegates to the model class of the replicator' do
        expect(described_class.model).to receive(:verification_pending_batch)

        described_class.verification_pending_batch
      end
    end

    context 'when current node is a secondary' do
      it 'delegates to the registry class of the replicator' do
        stub_current_geo_node(secondary)

        expect(described_class.registry_class).to receive(:verification_pending_batch)

        described_class.verification_pending_batch
      end
    end
  end

  describe '.verification_failed_batch' do
    context 'when current node is a primary' do
      it 'delegates to the model class of the replicator' do
        expect(described_class.model).to receive(:verification_failed_batch)

        described_class.verification_failed_batch
      end
    end

    context 'when current node is a secondary' do
      it 'delegates to the registry class of the replicator' do
        stub_current_geo_node(secondary)

        expect(described_class.registry_class).to receive(:verification_failed_batch)

        described_class.verification_failed_batch
      end
    end
  end

  describe '.fail_verification_timeouts' do
    context 'when current node is a primary' do
      it 'delegates to the model class of the replicator' do
        expect(described_class.model).to receive(:fail_verification_timeouts)

        described_class.fail_verification_timeouts
      end
    end

    context 'when current node is a secondary' do
      it 'delegates to the registry class of the replicator' do
        stub_current_geo_node(secondary)

        expect(described_class.registry_class).to receive(:fail_verification_timeouts)

        described_class.fail_verification_timeouts
      end
    end
  end

  describe '#verify_async' do
    before do
      model_record.save!
    end

    context 'on a Geo primary' do
      before do
        stub_primary_node
      end

      it 'calls verification_pending!' do
        expect(model_record).to receive(:verification_pending!)

        replicator.verify_async
      end
    end
  end

  describe '#verify' do
    it 'wraps the checksum calculation in track_checksum_attempt!' do
      tracker = double('tracker')
      allow(replicator).to receive(:verification_state_tracker).and_return(tracker)
      allow(replicator).to receive(:calculate_checksum).and_return('abc123')
      allow(tracker).to receive(:verification_started!).and_return(true)

      expect(tracker).to receive(:track_checksum_attempt!).and_yield

      replicator.verify
    end
  end

  describe '#verification_state_tracker' do
    context 'on a Geo primary' do
      before do
        stub_primary_node
      end

      it 'returns model_record' do
        expect(replicator.verification_state_tracker).to eq(model_record)
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns registry' do
        registry = double('registry')
        allow(replicator).to receive(:registry).and_return(registry)

        expect(replicator.verification_state_tracker).to eq(registry)
      end
    end
  end

  describe '#geo_handle_after_checksum_succeeded' do
    context 'on a Geo primary' do
      before do
        stub_primary_node
      end

      it 'creates checksum_succeeded event' do
        model_record

        expect { replicator.geo_handle_after_checksum_succeeded }.to change { ::Geo::Event.count }.by(1)
        expect(::Geo::Event.last.event_name).to eq 'checksum_succeeded'
      end

      it 'is called on verification success' do
        model_record.verification_started

        expect { model_record.verification_succeeded_with_checksum!('abc123', Time.current) }.to change { ::Geo::Event.count }.by(1)
        expect(::Geo::Event.last.event_name).to eq 'checksum_succeeded'
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags("geo_#{replicator.replicable_name}_replication": false)
        end

        it 'does not publish' do
          expect do
            replicator.geo_handle_after_checksum_succeeded
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does not create an event' do
        expect do
          replicator.geo_handle_after_checksum_succeeded
        end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
      end
    end
  end

  describe '#consume_event_checksum_succeeded' do
    context 'with a persisted model_record' do
      before do
        model_record.save!
      end

      context 'on a Geo primary' do
        before do
          stub_primary_node
        end

        it 'does nothing' do
          expect(replicator).not_to receive(:registry)

          replicator.consume_event_checksum_succeeded
        end
      end

      context 'on a Geo secondary' do
        before do
          stub_current_geo_node(secondary)
        end

        context 'with a persisted registry' do
          let(:registry) { replicator.registry }

          before do
            registry.save!
          end

          context 'with a registry which is verified' do
            it 'sets state to verification_pending' do
              registry.verification_started
              registry.verification_succeeded_with_checksum!('foo', Time.current)

              expect do
                replicator.consume_event_checksum_succeeded
              end.to change { registry.reload.verification_state }
                .from(verification_state_value(:verification_succeeded))
                .to(verification_state_value(:verification_pending))
            end
          end

          context 'with a registry which is pending verification' do
            it 'does not change state from verification_pending' do
              registry.save!

              expect do
                replicator.consume_event_checksum_succeeded
              end.not_to change { registry.reload.verification_state }
                .from(verification_state_value(:verification_pending))
            end
          end
        end

        context 'with an unpersisted registry' do
          it 'does not persist the registry' do
            replicator.consume_event_checksum_succeeded

            expect(replicator.registry.persisted?).to be_falsey
          end
        end
      end
    end
  end

  describe '#mutable?' do
    it 'returns the opposite of immutable?' do
      expect(replicator.mutable?).to eq(!replicator.immutable?)
    end
  end

  describe '#primary_verification_succeeded?' do
    context 'when the model record is verification_succeeded' do
      it 'returns true' do
        allow(model_record).to receive(:verification_succeeded?).and_return(true)

        expect(replicator.primary_verification_succeeded?).to be_truthy
      end
    end

    context 'when the model record is not verification_succeeded' do
      it 'returns false' do
        allow(model_record).to receive(:verification_succeeded?).and_return(false)

        expect(replicator.primary_verification_succeeded?).to be_falsey
      end
    end
  end

  describe '#ok_to_skip_download?' do
    subject(:ok_to_skip_download?) { replicator.ok_to_skip_download? }

    context 'when the registry is brand new' do
      context 'when the model is immutable' do
        before do
          skip 'this context does not apply to mutable models' unless replicator.immutable?
        end

        context 'when the resource already exists on this site' do
          before do
            allow(replicator).to receive(:resource_exists?).and_return(true)
          end

          context 'when verification is enabled for this model' do
            before do
              unless replicator.class.verification_enabled?
                skip 'this context does not apply to models that are not verified'
              end
            end

            context 'when the resource is in verifiables' do
              before do
                allow(model_record).to receive(:in_verifiables?).and_return(true)
              end

              it { is_expected.to be_truthy }
            end

            context 'when the resource is not in verifiables' do
              before do
                allow(model_record).to receive(:in_verifiables?).and_return(false)
              end

              it { is_expected.to be_falsey }
            end
          end

          context 'when verification is disabled for this model' do
            before do
              skip 'this context does not apply to models that are verified' if replicator.class.verification_enabled?
            end

            it { is_expected.to be_falsey }
          end
        end

        context 'when the resource does not exist on this site' do
          before do
            allow(replicator).to receive(:resource_exists?).and_return(false)
          end

          it { is_expected.to be_falsey }
        end
      end

      context 'when the model is mutable' do
        before do
          skip 'this context does not apply to immutable models' if replicator.immutable?
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when the registry is not brand new (sync or verification has been attempted before)' do
      before do
        model_record.save!
        replicator.registry.start
        replicator.registry.synced!
        replicator.registry.pending!
      end

      it { is_expected.to be_falsey }
    end
  end

  describe 'integration tests' do
    before do
      model_record.save!
    end

    context 'on a primary' do
      before do
        stub_current_geo_node(primary)
        allow(Gitlab::Geo).to receive(:verification_concurrency_limit).and_return(20)
      end

      describe 'background backfill' do
        it 'verifies model records' do
          model_record.verification_pending!

          expect do
            Geo::VerificationBatchWorker.new.perform(replicator.replicable_name)
          end.to change { model_record.reload.verification_succeeded? }.from(false).to(true)
        end
      end
    end

    context 'on a secondary' do
      before do
        # Set the primary checksum
        replicator.verify

        stub_current_geo_node(secondary)
        allow(Gitlab::Geo).to receive(:verification_concurrency_limit).and_return(20)
      end

      describe 'background backfill' do
        it 'verifies registries' do
          registry = replicator.registry
          registry.start
          registry.synced!

          expect do
            Geo::VerificationBatchWorker.new.perform(replicator.replicable_name)
          end.to change { registry.reload.verification_succeeded? }.from(false).to(true)
        end
      end
    end
  end

  def verification_state_value(state_name)
    model_record.class.verification_state_value(state_name)
  end
end

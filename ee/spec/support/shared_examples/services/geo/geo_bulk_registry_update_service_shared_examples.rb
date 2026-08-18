# frozen_string_literal: true

RSpec.shared_examples 'a geo bulk registry update service' do
  let(:registry_class) { model_name.constantize }
  let(:factory) { factory_name(registry_class) }
  let(:params) { {} }
  let(:service) { described_class.new(model_name, params) }
  let(:params_hash) { Base64.urlsafe_encode64(Gitlab::Json.dump(params.deep_stringify_keys)) }
  let(:redis_key) do
    "geo:#{registry_class.table_name}:#{params_hash}:#{described_class.name.demodulize.underscore}_cursor"
  end

  before do
    stub_current_geo_node(create(:geo_node, :primary))
  end

  shared_examples 'async_execute method' do
    it 'enqueues the worker and returns success response' do
      expect(worker).to receive(:perform_async)
                          .with(model_name, params.deep_stringify_keys)

      result = service.async_execute

      expect(result).to be_success
      expect(result.message).to eq('Batch update job has been successfully enqueued.')
      expect(result.payload[:status]).to eq(:pending)
    end

    context 'with invalid model_name' do
      let(:model_name) { 'invalid' }

      it 'returns a NotImplemented error' do
        expect(worker).not_to receive(:perform_async)

        expect { service.async_execute }.to raise_error(NotImplementedError, /Cannot find a class for invalid/)
      end
    end
  end

  shared_examples 'handles failures' do
    context 'when update_all fails' do
      before do
        create_list(factory, 3, default_state)

        relation = registry_class.send(not_pending_scope)
        allow(registry_class).to receive_message_chain(not_pending_scope, :after_cursor).and_return(relation)
        allow(relation).to receive(:update_all).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'allows the exception to bubble up for Sidekiq retry' do
        expect { service.execute }.to raise_error(ActiveRecord::StatementInvalid, 'Database error')
      end
    end

    context 'when last record is nil' do
      before do
        # Mock empty relation
        allow(service).to receive(:records_to_update).and_return(registry_class.none)
      end

      it 'handles empty batches gracefully' do
        expect { service.execute }.not_to raise_error
      end
    end
  end

  shared_examples 'updates all model types' do
    context 'with all model types' do
      where(model_classes: Gitlab::Geo.registry_classes)

      with_them do
        let(:model_name) { model_classes.name }
        let(:factory) { factory_name(model_classes) }

        it 'updates states' do
          create_list(factory, 3, default_state)

          expect { service.execute }.to change { model_classes.send(pending_scope).count }.by(3)
        end
      end
    end
  end

  shared_examples 'updates all records' do
    it 'updates all records' do
      service.execute

      expect(registry_class.send(pending_scope)).to match_array(registry_class.all)
    end
  end

  shared_examples 'updates records' do
    it 'updates expected records' do
      service.execute

      expect(registry_class.send(pending_scope)).to match_array(expected_records)
    end
  end

  shared_examples 'updates no records' do
    it 'updates 0 records' do
      service.execute

      expect(registry_class.send(pending_scope)).to be_empty
    end
  end

  describe '#async_execute' do
    it_behaves_like 'async_execute method'
  end

  describe '#execute' do
    context 'when there are records to update' do
      before do
        create_list(factory, 5, default_state)
      end

      it 'updates replication state of all records to pending' do
        service.execute

        expect(registry_class.send(pending_scope).size).to eq(5)
        expect(registry_class.send(default_state).size).to eq(0)
      end

      it 'returns success response when completed' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('All records have been successfully updated.')
        expect(result.payload[:status]).to eq(:completed)
      end

      it 'deletes the Redis cursor key on completion' do
        Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, 99) }

        result = service.execute

        expect(result.payload[:status]).to eq(:completed)
        Gitlab::Redis::SharedState.with do |redis|
          expect(redis.get(redis_key)).to be_nil
        end
      end

      it 'logs completion message' do
        expect(service).to receive(:log_info).with('All records have been successfully updated.')

        service.execute
      end

      it 'processes records in batches' do
        stub_const('Geo::BaseBatchBulkUpdateService::BATCH_SIZE', 2)
        relation = registry_class.send(not_pending_scope)
        allow(registry_class).to receive_message_chain(not_pending_scope, :after_cursor).and_return(relation)

        expect(relation).to receive(:update_all).exactly(3).times

        service.execute
      end

      context 'with id filters' do
        let(:params) { { ids: } }
        let(:all_records) { create_list(factory, 3, default_state) }
        let(:expected_records) { [all_records.first, all_records.last] }
        let(:ids) { expected_records.map(&:id) }

        it 'only updates expected records' do
          service.execute

          pending_records = registry_class.send(pending_scope)
          expect(pending_records.size).to eq(2)
          expect(pending_records).to match_array(expected_records)
        end
      end

      context 'with id and verification_state filters' do
        let(:params) do
          { ids: [registry_class.first.id, registry_class.last.id], verification_state: :verification_failed }
        end

        before do
          create_list(factory, 3, default_state)
        end

        it 'only updates matching records' do
          state = Geo::VerificationState::VERIFICATION_STATE_VALUES[:verification_failed]
          registry_class.first.update!(verification_state: state, verification_failure: 'Failed')

          service.execute

          pending_records = registry_class.send(pending_scope)
          expect(pending_records.size).to eq(1)
          expect(pending_records).to contain_exactly(registry_class.first)
        end
      end

      context 'with replication_state filters' do
        let(:params) { { replication_state: } }
        let!(:expected_records) do
          # create 2 new records if the state doesn't exist
          registry_class.with_state(replication_state).presence ||
            create_list(factory, 2, state: registry_class::STATE_VALUES[replication_state])
        end

        context 'when filter is failed' do
          let(:replication_state) { :failed }

          it_behaves_like 'updates records' if described_class == Geo::BulkRegistryResyncService
          # Reverification only works on synced records
          it_behaves_like 'updates no records' if described_class == Geo::BulkRegistryReverificationService
        end

        context 'when filter is started' do
          let(:replication_state) { :started }

          it_behaves_like 'updates records' if described_class == Geo::BulkRegistryResyncService
          # Reverification only works on synced records
          it_behaves_like 'updates no records' if described_class == Geo::BulkRegistryReverificationService
        end

        context 'when filter is succeeded' do
          let(:replication_state) { :synced }

          it_behaves_like 'updates all records'
        end
      end

      context 'with verification_state filter' do
        let(:params) { { verification_state: } }

        context 'when verification is disabled' do
          before do
            allow(registry_class.replicator_class).to receive(:verification_enabled?).and_return(false)
            # Set a variety of different verification_state on existing records
            # As verification is disabled this will not matter and all records will be updated
            registry_class.all.each_with_index do |registry, index|
              registry[:verification_state] = index
              registry[:verification_failure] = 'test' if index == 3
              registry[:verification_checksum] = 'abc' if index == 2

              registry.save!
            end
          end

          context 'when filter is failed' do
            let(:verification_state) { :verification_failed }

            it_behaves_like 'updates all records'
          end

          context 'when filter is succeeded' do
            let(:verification_state) { :verification_succeeded }

            it_behaves_like 'updates all records'
          end

          context 'when filter is started' do
            let(:verification_state) { :verification_started }

            it_behaves_like 'updates all records'
          end

          context 'when filter is pending' do
            let(:verification_state) { :verification_pending }

            it_behaves_like 'updates all records'
          end

          context 'when filter is disabled' do
            let(:verification_state) { :verification_disabled }

            it_behaves_like 'updates all records'
          end
        end

        context 'when verification is enabled' do
          let!(:expected_records) do
            args = if %i[verification_failed verification_succeeded].include?(verification_state)
                     [2, verification_state]
                   else
                     [2, :synced, { verification_state: registry_class::VERIFICATION_STATE_VALUES[verification_state] }]
                   end

            registry_class.with_verification_state(verification_state).presence || create_list(factory, *args)
          end

          before do
            allow(registry_class.replicator_class).to receive(:verification_enabled?).and_return(true)
          end

          context 'when filter is failed' do
            let(:verification_state) { :verification_failed }

            it_behaves_like 'updates records'
          end

          context 'when filter is succeeded' do
            let(:verification_state) { :verification_succeeded }

            it_behaves_like 'updates records'
          end

          context 'when filter is started' do
            let(:verification_state) { :verification_started }

            it_behaves_like 'updates records'
          end

          context 'when filter is pending' do
            let(:verification_state) { :verification_pending }

            it_behaves_like 'updates records'
          end

          context 'when filter is disabled' do
            let(:verification_state) { :verification_disabled }

            it_behaves_like 'updates records'
          end
        end
      end
    end

    context 'with invalid model_name' do
      let(:model_name) { 'invalid' }

      it 'returns a NotImplemented error' do
        expect(worker).not_to receive(:perform_async)

        expect { service.execute }.to raise_error(NotImplementedError, /Cannot find a class for invalid/)
      end
    end

    context 'when time limit is reached' do
      before do
        # Create multiple records to ensure batching
        create_list(factory, 5, default_state)
        stub_const('Geo::BaseBatchBulkUpdateService::BATCH_SIZE', 2)

        # Mock runtime limiter to simulate time limit reached
        runtime_limiter = instance_double(Gitlab::Metrics::RuntimeLimiter)
        allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new).and_return(runtime_limiter)
        allow(runtime_limiter).to receive(:over_time?).and_return(false, true) # First batch succeeds, second hits limit
      end

      it 'reenqueues the worker for continuation' do
        expect(worker).to receive(:perform_in).with(described_class::PERFORM_IN, model_name, params.stringify_keys)

        service.execute
      end

      it 'returns error response with limit_reached status' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include("20 seconds limit reached on #{model_name} update")
        expect(result.payload[:status]).to eq(:limit_reached)
      end

      it 'logs error message' do
        expect(service).to receive(:log_error).with(a_string_including('20 seconds limit reached'))

        service.execute
      end

      it 'saves cursor for continuation' do
        fourth_registry = registry_class.offset(3).first
        expected_cursor = Gitlab::Json.dump(fourth_registry.slice(*registry_class.primary_key).values)

        service.execute

        Gitlab::Redis::SharedState.with do |redis|
          cursor = redis.get(redis_key)
          expect(cursor).to eq(expected_cursor)
        end
      end
    end

    context 'when no records need updating' do
      before do
        # Ensure all records are already pending
        registry_class.update_all(state_field => registry_states[pending_scope])
      end

      it 'completes without updating any records' do
        expect { service.execute }.not_to change {
          registry_class
            .where(state_field => registry_states[pending_scope])
            .count
        }
      end

      it 'returns success response' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('All records have been successfully updated.')
        expect(result.payload[:status]).to eq(:completed)
      end
    end

    context 'with cursor continuation' do
      let(:job_artifacts) { create_list(factory, 3, default_state) }

      context 'when cursor ID exists' do
        before do
          # Set cursor to skip first record
          cursor_value = job_artifacts.first.slice(*job_artifacts.first.class.primary_key).values
          Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, Gitlab::Json.dump(cursor_value)) }
        end

        it 'continues from cursor position' do
          service.execute

          # First record should remain unchanged, others should be updated
          expect(job_artifacts[0].reload.send(state_field)).to eq(registry_states[default_state])
          expect(job_artifacts[1].reload.send(state_field)).to eq(registry_states[pending_scope])
          expect(job_artifacts[2].reload.send(state_field)).to eq(registry_states[pending_scope])
        end
      end

      context 'when cursor ID does not exist anymore' do
        before do
          # Set cursor to skip first and second record
          # Delete second record
          cursor_value = job_artifacts.second.slice(*job_artifacts.second.class.primary_key).values
          Gitlab::Redis::SharedState.with { |redis| redis.set(redis_key, Gitlab::Json.dump(cursor_value)) }
          job_artifacts.second.delete
        end

        it 'continues from cursor position' do
          service.execute

          # First record should remain unchanged and the third should be updated
          expect(job_artifacts[0].reload.send(state_field)).to eq(registry_states[default_state])
          expect(job_artifacts[2].reload.send(state_field)).to eq(registry_states[pending_scope])
        end
      end
    end
  end

  # Test error handling scenarios
  describe 'error handling' do
    it_behaves_like 'handles failures'
  end

  describe 'with different model types' do
    it_behaves_like 'updates all model types'
  end
end

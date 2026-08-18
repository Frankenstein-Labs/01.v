# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MigrationReindexBasedOnSchemaVersion, feature_category: :global_search do
  context 'when required methods are not implemented' do
    let(:migration_klass) do
      Class.new do
        include ::Search::Elastic::MigrationReindexBasedOnSchemaVersion
      end
    end

    subject(:migration) { migration_klass.new }

    describe '#query_batch_size' do
      it 'raises a NotImplementedError when batch_size is not defined' do
        expect { migration.send(:query_batch_size) }.to raise_error(NotImplementedError)
      end
    end

    describe '#index_name' do
      it 'raises a NotImplementedError when DOCUMENT_TYPE is not defined' do
        expect { migration.send(:index_name) }.to raise_error(NotImplementedError)
      end
    end
  end

  context 'with a properly implemented migration class' do
    let(:version) { 30231204134928 }
    let(:new_schema_version) { 2 }
    let(:document_type) { WorkItem }

    let(:helper) { ::Search::Elastic::Helper.default }
    let(:client) { helper.client }

    let(:migration_klass) do
      migration_klass = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationReindexBasedOnSchemaVersion

        batch_size 4
        batched!
        throttle_delay 1.minute
        retry_on_failure
      end

      stub_const('MigrationKlass', migration_klass)

      MigrationKlass
    end

    subject(:migration) { MigrationKlass.new(version) }

    before do
      stub_const("#{migration_klass}::DOCUMENT_TYPE", document_type)
      stub_const("#{migration_klass}::NEW_SCHEMA_VERSION", 2)

      allow(migration).to receive_messages(client: client, helper: helper, index_name: 'test-index')
      allow(migration).to receive(:set_migration_state)
      allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:refresh_index)
    end

    describe '#completed?' do
      it 'returns true when no documents with old schema version remain' do
        expect(client).to receive(:count).and_return({ 'count' => 0 })

        expect(migration.completed?).to be(true)
      end

      it 'returns false when documents with old schema version remain' do
        expect(client).to receive(:count).and_return({ 'count' => 10 })

        expect(migration.completed?).to be(false)
      end

      it 'sets migration state with remaining document count' do
        expect(client).to receive(:count).and_return({ 'count' => 5 })
        expect(migration).to receive(:set_migration_state).with(documents_remaining: 5)

        migration.completed?
      end
    end

    describe '#migrate' do
      context 'when migration is already completed' do
        before do
          allow(migration).to receive(:completed?).and_return(true)
        end

        it 'skips reindexing' do
          expect(migration).not_to receive(:process_batch!)

          migration.migrate
        end
      end

      context 'when queue is full' do
        before do
          allow(migration).to receive_messages(completed?: false, queue_full?: true)
        end

        it 'skips reindexing due to throttling' do
          expect(migration).not_to receive(:process_batch!)

          migration.migrate
        end
      end

      context 'when migration can proceed' do
        let(:document_references) { [Search::Elastic::References::WorkItem] }

        before do
          allow(migration).to receive_messages(completed?: false, queue_full?: false,
            process_batch!: document_references)
        end

        it 'processes a batch of documents' do
          expect(migration).to receive(:process_batch!)

          migration.migrate
        end

        it 'logs the reindexing process' do
          expect(migration).to receive(:log).with('Start reindexing', hash_including(:index_name, :batch_size))
          expect(migration).to receive(:log)
            .with('Reindexing batch has been processed', hash_including(:index_name, :batch_size))

          migration.migrate
        end
      end

      context 'when an error occurs' do
        before do
          allow(migration).to receive_messages(completed?: false, queue_full?: false)
          allow(migration).to receive(:process_batch!).and_raise(StandardError.new("Test error"))
        end

        it 'logs the error and re-raises it' do
          expect(migration).to receive(:log_raise)
            .with('migrate failed', hash_including(:error_class, :error_message)).and_call_original

          expect { migration.migrate }.to raise_error(StandardError)
        end
      end
    end

    describe '#process_batch!' do
      let(:hits) do
        [
          { '_id' => 'es_id_1', '_routing' => 'parent_1', '_source' => { 'id' => 1 } },
          { '_id' => 'es_id_2', '_routing' => nil, '_source' => { 'id' => 2 } }
        ]
      end

      let(:search_results) do
        { 'hits' => { 'hits' => hits } }
      end

      before do
        allow(client).to receive(:search).and_return(search_results)
        allow(migration.send(:bookkeeping_service)).to receive(:track!)
        allow(migration).to receive(:use_scroll_api?).and_return(false)
      end

      context 'when using regular search' do
        it 'searches for documents with old schema version' do
          expect(client).to receive(:search).with(
            hash_including(
              index: 'test-index',
              body: hash_including(query: instance_of(Hash), size: instance_of(Integer))
            )
          )

          migration.send(:process_batch!)
        end

        it 'creates document references from search results' do
          expect(Search::Elastic::Reference).to receive(:init).with(document_type, 1, 'es_id_1', 'parent_1')
          expect(Search::Elastic::Reference).to receive(:init).with(document_type, 2, 'es_id_2', nil)

          migration.send(:process_batch!)
        end

        it 'tracks document references for reindexing' do
          expect(migration.send(:bookkeeping_service)).to receive(:track!).once

          migration.send(:process_batch!)
        end

        it 'returns the document references' do
          refs = migration.send(:process_batch!)

          expect(refs.size).to eq(2)
        end
      end

      context 'when using scroll API' do
        let(:scroll_response) do
          {
            '_scroll_id' => 'scroll_123',
            'hits' => { 'hits' => hits }
          }
        end

        before do
          allow(migration).to receive_messages(use_scroll_api?: true, current_scroll_id: nil)
          allow(client).to receive(:search).and_return(scroll_response)
        end

        it 'initializes scroll search when no scroll_id exists' do
          expect(client).to receive(:search).with(
            hash_including(
              index: 'test-index',
              scroll: described_class::SCROLL_TIMEOUT,
              body: hash_including(
                query: instance_of(Hash),
                size: instance_of(Integer),
                sort: [{ 'id' => { order: 'asc' } }]
              )
            )
          )

          migration.send(:process_batch!)
        end

        it 'updates migration state with scroll_id and last_processed_id' do
          expect(migration).to receive(:set_migration_state).with(scroll_id: 'scroll_123', last_processed_id: 2)

          migration.send(:process_batch!)
        end

        context 'when continuing existing scroll' do
          before do
            allow(migration).to receive(:current_scroll_id).and_return('existing_scroll_123')
            allow(client).to receive(:scroll).and_return(scroll_response)
          end

          it 'continues with existing scroll' do
            expect(client).to receive(:scroll).with(
              body: { scroll_id: 'existing_scroll_123' },
              scroll: described_class::SCROLL_TIMEOUT
            )

            migration.send(:process_batch!)
          end

          context 'when the scroll_id has expired' do
            before do
              allow(client).to receive(:scroll).and_raise(Elasticsearch::Transport::Transport::Errors::NotFound)
            end

            it 'handles expired scroll_id gracefully' do
              expect(migration).to receive(:log_warn)
                .with('scroll_id expired, will restart scroll in next migration run',
                  hash_including(:exception_class, :exception_message, :scroll_id))

              expect { migration.send(:process_batch!) }.not_to raise_exception
            end

            it 'returns empty response when scroll expires' do
              result = migration.send(:process_batch!)
              expect(result).to be_empty
            end
          end
        end

        context 'when no more results' do
          let(:empty_scroll_response) do
            {
              '_scroll_id' => 'scroll_123',
              'hits' => { 'hits' => [] }
            }
          end

          before do
            allow(client).to receive(:search).and_return(empty_scroll_response)
            allow(migration).to receive(:cleanup_scroll)
          end

          it 'cleans up scroll and resets state' do
            expect(migration).to receive(:cleanup_scroll).with('scroll_123')
            expect(migration).to receive(:set_migration_state).with(
              scroll_id: nil,
              last_processed_id: nil
            )

            migration.send(:process_batch!)
          end
        end

        context 'when processing multiple batches within threshold' do
          let(:batch_hits_1) do
            [
              { '_id' => 'es_id_1', '_routing' => 'parent_1', '_source' => { 'id' => 1 } },
              { '_id' => 'es_id_2', '_routing' => nil, '_source' => { 'id' => 2 } },
              { '_id' => 'es_id_3', '_routing' => 'parent_2', '_source' => { 'id' => 3 } },
              { '_id' => 'es_id_4', '_routing' => nil, '_source' => { 'id' => 4 } }
            ]
          end

          let(:batch_hits_2) do
            [
              { '_id' => 'es_id_5', '_routing' => 'parent_3', '_source' => { 'id' => 5 } },
              { '_id' => 'es_id_6', '_routing' => nil, '_source' => { 'id' => 6 } },
              { '_id' => 'es_id_7', '_routing' => 'parent_4', '_source' => { 'id' => 7 } },
              { '_id' => 'es_id_8', '_routing' => nil, '_source' => { 'id' => 8 } }
            ]
          end

          let(:first_response) do
            {
              '_scroll_id' => 'scroll_123',
              'hits' => { 'hits' => batch_hits_1 }
            }
          end

          let(:second_response) do
            {
              '_scroll_id' => 'scroll_456',
              'hits' => { 'hits' => batch_hits_2 }
            }
          end

          let(:empty_response) do
            {
              '_scroll_id' => 'scroll_789',
              'hits' => { 'hits' => [] }
            }
          end

          before do
            allow(client).to receive(:search).and_return(first_response)
            allow(client).to receive(:scroll).and_return(second_response, empty_response)
            allow(migration).to receive(:cleanup_scroll)
          end

          it 'processes multiple scroll batches until empty or threshold reached' do
            expect(migration).to receive(:set_migration_state).with(scroll_id: 'scroll_123',
              last_processed_id: 4)
            expect(migration).to receive(:set_migration_state).with(scroll_id: 'scroll_456',
              last_processed_id: 8)
            expect(migration).to receive(:cleanup_scroll).with('scroll_789')
            expect(migration).to receive(:set_migration_state).with(scroll_id: nil, last_processed_id: nil)

            result = migration.send(:process_batch!)
            expect(result.size).to eq(8)
          end

          it 'logs batch processing progress' do
            expect(migration).to receive(:log).with(
              'Processed batch with scroll',
              hash_including(:index_name, :batch_size, :total_processed)
            ).twice

            migration.send(:process_batch!)
          end
        end
      end
    end

    describe '#use_scroll_api?' do
      before do
        allow(migration).to receive_messages(current_scroll_id: nil, remaining_documents_count: 5000,
          query_batch_size: 1000)
      end

      subject(:use_scroll_api) { migration.send(:use_scroll_api?) }

      context 'when there is an existing scroll session' do
        before do
          allow(migration).to receive(:current_scroll_id).and_return('scroll_123')
        end

        it { is_expected.to be(true) }
      end

      context 'when remaining_documents_count exceed batch size' do
        before do
          allow(migration).to receive(:remaining_documents_count).and_return(15000)
        end

        it { is_expected.to be(true) }
      end

      context 'when remaining_documents_count are within batch size' do
        before do
          allow(migration).to receive(:remaining_documents_count).and_return(500)
        end

        it { is_expected.to be(false) }
      end
    end

    describe '#fetch_scroll_response' do
      context 'when scroll_id is nil' do
        it 'initiates new scroll search' do
          expect(client).to receive(:search).with(
            index: 'test-index',
            scroll: described_class::SCROLL_TIMEOUT,
            body: hash_including(
              query: instance_of(Hash),
              size: instance_of(Integer),
              sort: [{ 'id' => { order: 'asc' } }]
            )
          ).and_return({ '_scroll_id' => 'new_scroll', 'hits' => { 'hits' => [] } })

          result = migration.send(:fetch_scroll_response, nil)
          expect(result['_scroll_id']).to eq('new_scroll')
        end
      end

      context 'when scroll_id is present' do
        it 'continues existing scroll' do
          expect(client).to receive(:scroll).with(
            body: { scroll_id: 'existing_scroll' },
            scroll: described_class::SCROLL_TIMEOUT
          ).and_return({ '_scroll_id' => 'continued_scroll', 'hits' => { 'hits' => [] } })

          result = migration.send(:fetch_scroll_response, 'existing_scroll')
          expect(result['_scroll_id']).to eq('continued_scroll')
        end

        context 'when scroll_id has expired' do
          it 'logs warning and returns empty response' do
            allow(client).to receive(:scroll)
              .and_raise(Elasticsearch::Transport::Transport::Errors::NotFound.new('scroll expired'))

            expect(migration).to receive(:log_warn).with(
              'scroll_id expired, will restart scroll in next migration run',
              hash_including(:exception_class, :exception_message, :scroll_id)
            )

            result = migration.send(:fetch_scroll_response, 'expired_scroll')
            expect(result).to eq({ '_scroll_id' => nil, 'hits' => { 'hits' => [] } })
          end
        end
      end
    end

    describe '#cleanup_scroll' do
      context 'when scroll_id is present' do
        it 'clears the scroll' do
          expect(client).to receive(:clear_scroll).with(body: { scroll_id: 'scroll_123' })

          migration.send(:cleanup_scroll, 'scroll_123')
        end

        context 'when the scroll_id has expired' do
          it 'logs a warning and does not raise an exception' do
            allow(client).to receive(:clear_scroll).and_raise(Elasticsearch::Transport::Transport::Errors::NotFound)

            expect(migration).to receive(:log_warn)
              .with('scroll_id not found while trying to clear_scroll',
                hash_including(:exception_class, :exception_message, :scroll_id))

            expect { migration.send(:cleanup_scroll, 'scroll_123') }.not_to raise_exception
          end
        end
      end

      context 'when scroll_id is not present' do
        it 'does not clear the scroll' do
          expect(client).not_to receive(:clear_scroll)

          migration.send(:cleanup_scroll, nil)
        end
      end

      it 'logs error when clear_scroll fails' do
        allow(client).to receive(:clear_scroll).and_raise(StandardError.new('Connection error'))
        expect(migration).to receive(:log_warn).with(
          'clear_scroll failed',
          hash_including(:exception_class, :exception_message, :scroll_id)
        )

        migration.send(:cleanup_scroll, 'scroll_123')
      end
    end

    describe '#bookkeeping_service' do
      it 'returns the ProcessInitialBookkeepingService' do
        expect(migration.send(:bookkeeping_service)).to eq(::Elastic::ProcessInitialBookkeepingService)
      end
    end

    describe '#queue_full?' do
      it 'returns true when queue size exceeds threshold' do
        allow(migration.send(:bookkeeping_service)).to receive(:queue_size)
          .and_return(described_class::QUEUE_THRESHOLD + 1)

        expect(migration.send(:queue_full?)).to be(true)
      end

      it 'returns false when queue size is below threshold' do
        allow(migration.send(:bookkeeping_service)).to receive(:queue_size)
          .and_return(described_class::QUEUE_THRESHOLD - 1)

        expect(migration.send(:queue_full?)).to be(false)
      end
    end

    describe '#update_batch_size' do
      it 'returns the class constant if defined' do
        update_size = 350
        stub_const("#{migration_klass}::UPDATE_BATCH_SIZE", update_size)

        expect(migration.send(:update_batch_size)).to eq(update_size)
      end

      it 'returns the module constant if class constant is not defined' do
        expect(migration.send(:update_batch_size)).to eq(described_class::UPDATE_BATCH_SIZE)
      end
    end
  end

  describe 'integration tests', :elastic_delete_by_query, :sidekiq_inline do
    let(:document_type) { WorkItem }
    let(:object) { :work_item }
    let(:current_schema_version) { ::Search::Elastic::References::WorkItem::SCHEMA_VERSION }

    let(:migration_klass) do
      migration_klass = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationReindexBasedOnSchemaVersion

        batch_size 100
        batched!
        throttle_delay 1.minute
        retry_on_failure
      end

      stub_const('MigrationKlass', migration_klass)

      MigrationKlass
    end

    let(:version) { 30231204134928 }
    let(:objects) { create_list(object, 5) }

    before do
      stub_const("#{migration_klass}::DOCUMENT_TYPE", document_type)
    end

    subject(:migration) { MigrationKlass.new(version) }

    describe '#migrate' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        set_elasticsearch_migration_to(version, including: false)

        migration.send(:bookkeeping_service).track!(*objects)
        ensure_elasticsearch_index!

        migration_record = Elastic::MigrationRecord.new(version: version, name: 'SomeName', filename: 'some_file')
        allow(Elastic::DataMigrationService).to receive(:[]).and_return(migration_record)

        stub_const("#{migration_klass}::NEW_SCHEMA_VERSION", current_schema_version + 1)

        # reset state to avoid flaky-ness
        migration.set_migration_state(current_id: 0, scroll_id: nil, last_processed_id: nil, documents_remaining: nil)
      end

      context 'when records exist with old schema' do
        before do
          # make sure new indexed records get the correct schema_version
          # We need to stub both SCHEMA_VERSIONS hash and the derived SCHEMA_VERSION constant
          new_schema_versions = ::Search::Elastic::References::WorkItem::SCHEMA_VERSIONS.dup
          new_schema_versions[current_schema_version + 1] = :test_migration
          stub_const('Search::Elastic::References::WorkItem::SCHEMA_VERSIONS', new_schema_versions)
          stub_const('Search::Elastic::References::WorkItem::SCHEMA_VERSION', current_schema_version + 1)

          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:test_migration).and_return(true)
        end

        context 'when using search API' do
          it 'processes records' do
            expected_count = objects.size
            expect(migration.send(:bookkeeping_service)).to receive(:track!).once.and_call_original do |*refs|
              expect(refs.count).to eq(expected_count)
            end

            migration.migrate

            ensure_elasticsearch_index!

            expect(migration.completed?).to be(true)
          end
        end

        context 'when using scroll API' do
          before do
            allow(migration).to receive(:query_batch_size).and_return(objects.size - 2)
          end

          it 'processes records using scroll API' do
            expect(migration.send(:bookkeeping_service)).to receive(:track!).twice.and_call_original

            state_before_first_run = migration.migration_state
            expect(state_before_first_run[:scroll_id]).to be_nil
            expect(state_before_first_run[:last_processed_id]).to be_nil

            migration.migrate
            ensure_elasticsearch_index!

            state_after_first_run = migration.migration_state
            expect(state_after_first_run[:scroll_id]).to be_present
            expect(state_after_first_run[:last_processed_id]).to be_present

            migration.migrate
            ensure_elasticsearch_index!

            expect(migration.completed?).to be(true)
          end
        end
      end

      context 'when all records have the new schema' do
        it 'does not process documents' do
          stub_const("#{migration_klass}::NEW_SCHEMA_VERSION", current_schema_version)

          expect(migration.send(:bookkeeping_service)).not_to receive(:track!)

          migration.migrate

          expect(migration.completed?).to be(true)
        end
      end

      context 'when queue is full' do
        before do
          allow(migration.send(:bookkeeping_service)).to receive(:queue_size)
            .and_return(described_class::QUEUE_THRESHOLD + 1)
        end

        it 'does not process documents' do
          expect(migration.send(:bookkeeping_service)).not_to receive(:track!)

          migration.migrate

          expect(migration.completed?).to be(false)
        end
      end
    end
  end
end

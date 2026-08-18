# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MigrationCleanupService, feature_category: :global_search do
  let(:client) { instance_double(::Gitlab::Search::Client) }
  let(:logger) { instance_double(Gitlab::Elasticsearch::Logger, info: nil, warn: nil) }
  let(:service) { described_class.new(dry_run: dry_run, logger: logger) }
  let(:dry_run) { false }
  let_it_be(:helper) { ::Search::Elastic::Helper.default }

  before do
    allow(Search::Elastic::Helper).to receive(:default).and_return(helper)
    allow(Gitlab::Search::Client).to receive(:new).and_return(client)
  end

  describe '#execute' do
    let(:migration_id_1) { 1 }
    let(:migration_id_2) { 2 }
    let(:migration_id_3) { 3 }
    let(:scroll_id) { 'scroll-id-123' }
    let(:initial_response) do
      {
        '_scroll_id' => scroll_id,
        'hits' => {
          'hits' => [
            {
              '_id' => migration_id_1.to_s,
              '_source' => { 'name' => 'Migration1', 'started_at' => 1.month.ago.to_s }
            },
            {
              '_id' => migration_id_2.to_s,
              '_source' => { 'name' => 'Migration2', 'started_at' => 1.month.ago.to_s }
            },
            {
              '_id' => migration_id_3.to_s,
              '_source' => { 'name' => 'Migration3', 'started_at' => 3.months.ago.to_s }
            }
          ]
        }
      }
    end

    let(:empty_response) do
      {
        '_scroll_id' => scroll_id,
        'hits' => {
          'hits' => []
        }
      }
    end

    context 'when not on Saas' do
      it 'returns false' do
        expect(service.execute).to be(false)
      end
    end

    context 'when on Saas', :saas do
      context 'when elasticsearch_indexing is false' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: false)
        end

        it 'returns false' do
          expect(service.execute).to be(false)
        end
      end

      context 'when elasticsearch_indexing is true' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: true)
        end

        context 'when dry_run is true' do
          let(:dry_run) { true }

          it 'logs warnings but does not delete migrations' do
            expect(client).to receive(:search).and_return(initial_response)
            expect(client).to receive(:scroll).and_return(empty_response)
            expect(client).to receive(:clear_scroll).with(body: { scroll_id: scroll_id })
            expect(client).not_to receive(:delete)

            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_1).and_return(nil)
            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_2)
                                                                .and_return(instance_double(Elastic::MigrationRecord))
            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_3).and_return(nil)

            expect(logger).to receive(:warn)
              .with(hash_including('message' => 'Migration not found', 'migration_id' => migration_id_1.to_s))
            expect(logger).not_to receive(:warn).with(hash_including('migration_id' => migration_id_2.to_s))
            expect(logger).not_to receive(:warn).with(hash_including('migration_id' => migration_id_3.to_s))

            expect(service.execute).to eq(0)
          end
        end

        context 'when dry_run is false' do
          let(:dry_run) { false }

          it 'deletes migrations that are not found and are recent' do
            expect(client).to receive(:search).and_return(initial_response)
            expect(client).to receive(:scroll).and_return(empty_response)
            expect(client).to receive(:clear_scroll).with(body: { scroll_id: scroll_id })

            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_1).and_return(nil)
            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_2)
              .and_return(instance_double(Elastic::MigrationRecord))
            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_3).and_return(nil)

            expect(logger).to receive(:warn)
              .with(hash_including('message' => 'Migration not found', 'migration_id' => migration_id_1.to_s))
            expect(client).to receive(:delete)
              .with(index: helper.migrations_index_name, id: migration_id_1.to_s)
            expect(logger).to receive(:info)
              .with(hash_including('message' => 'Migration removed from index', 'migration_id' => migration_id_1.to_s))

            expect(service.execute).to eq(1)
          end
        end

        context 'when multiple scroll batches are required' do
          let(:second_batch_migration_id) { 4 }
          let(:second_response) do
            {
              '_scroll_id' => scroll_id,
              'hits' => {
                'hits' => [
                  {
                    '_id' => second_batch_migration_id.to_s,
                    '_source' => { 'name' => 'Migration4', 'started_at' => 1.month.ago.to_s }
                  }
                ]
              }
            }
          end

          it 'processes all batches and cleans up properly' do
            expect(client).to receive(:search).and_return(initial_response)
            expect(client).to receive(:scroll).and_return(second_response, empty_response)
            expect(client).to receive(:clear_scroll).with(body: { scroll_id: scroll_id })

            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_1).and_return(nil)
            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_2)
                                                                .and_return(instance_double(Elastic::MigrationRecord))
            allow(Elastic::DataMigrationService).to receive(:[]).with(migration_id_3).and_return(nil)
            allow(Elastic::DataMigrationService).to receive(:[]).with(second_batch_migration_id).and_return(nil)

            expect(logger).to receive(:warn)
              .with(hash_including('message' => 'Migration not found', 'migration_id' => migration_id_1.to_s))
            expect(logger).to receive(:warn).with(
              hash_including('message' => 'Migration not found', 'migration_id' => second_batch_migration_id.to_s))

            expect(client).to receive(:delete)
              .with(index: helper.migrations_index_name, id: migration_id_1.to_s)
            expect(client).to receive(:delete)
              .with(index: helper.migrations_index_name, id: second_batch_migration_id.to_s)

            expect(logger).to receive(:info)
              .with(hash_including('message' => 'Migration removed from index', 'migration_id' => migration_id_1.to_s))
            expect(logger).to receive(:info)
              .with(hash_including('message' => 'Migration removed from index',
                'migration_id' => second_batch_migration_id.to_s))

            expect(service.execute).to eq(2)
          end
        end

        context 'when migration started before the cutoff time' do
          let(:old_migration_response) do
            {
              '_scroll_id' => scroll_id,
              'hits' => {
                'hits' => [
                  {
                    '_id' => '10',
                    '_source' => { 'name' => 'OldMigration', 'started_at' => 3.months.ago.to_s }
                  }
                ]
              }
            }
          end

          it 'does not process migrations older than the cutoff time' do
            expect(client).to receive(:search).and_return(old_migration_response)
            expect(client).to receive(:scroll).and_return(empty_response)
            expect(client).to receive(:clear_scroll).with(body: { scroll_id: scroll_id })

            allow(Elastic::DataMigrationService).to receive(:[]).with(10).and_return(nil)

            expect(logger).not_to receive(:warn)
            expect(client).not_to receive(:delete)
            expect(logger).not_to receive(:info)

            expect(service.execute).to eq(0)
          end
        end

        context 'when migration has no started_at value' do
          let(:invalid_migration_response) do
            {
              '_scroll_id' => scroll_id,
              'hits' => {
                'hits' => [
                  {
                    '_id' => '20',
                    '_source' => { 'name' => 'InvalidMigration' }
                  }
                ]
              }
            }
          end

          it 'does not process migrations without a started_at value' do
            expect(client).to receive(:search).and_return(invalid_migration_response)
            expect(client).to receive(:scroll).and_return(empty_response)
            expect(client).to receive(:clear_scroll).with(body: { scroll_id: scroll_id })

            allow(Elastic::DataMigrationService).to receive(:[]).with(20).and_return(nil)

            expect(logger).not_to receive(:warn)
            expect(client).not_to receive(:delete)
            expect(logger).not_to receive(:info)

            expect(service.execute).to eq(0)
          end
        end
      end
    end
  end

  describe '.execute' do
    it 'creates a new instance and calls execute' do
      service_instance = instance_double(described_class)

      expect(described_class).to receive(:new).with(dry_run: false).and_return(service_instance)
      expect(service_instance).to receive(:execute)

      described_class.execute(dry_run: false)
    end
  end
end

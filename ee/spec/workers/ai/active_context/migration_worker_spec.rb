# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::MigrationWorker, feature_category: :global_search do
  let_it_be(:connection) { create(:ai_active_context_connection, active: true) }
  let_it_be(:migration_version) { '20240101010101' }
  let_it_be(:migration_class) do
    Class.new(ActiveContext::Migration::V1_0) do
      def migrate!; end

      def skip?
        false
      end
    end
  end

  let_it_be(:failing_migration_class) do
    Class.new(ActiveContext::Migration::V1_0) do
      def migrate!
        raise StandardError, 'Something went wrong'
      end

      def skip?
        false
      end
    end
  end

  let_it_be(:skipping_migration_class) do
    Class.new(ActiveContext::Migration::V1_0) do
      def migrate!; end

      def skip?
        true
      end
    end
  end

  let(:worker) { described_class.new }
  let(:logger) { instance_double(::Logger, info: nil) }
  let(:dictionary_versions) { [migration_version] }
  let(:dictionary_klass) { migration_class }

  it_behaves_like 'active_context pause-controlled worker' do
    let(:worker_params) { [] }
  end

  before do
    ActiveContext::Migration::Dictionary.reset!

    allow(ActiveContext).to receive_messages(
      indexing?: true,
      adapter: instance_double(ActiveContext::Databases::Concerns::Adapter, connection: connection)
    )
    allow(ActiveContext::Config).to receive(:logger).and_return(logger)
    allow(ActiveContext::Migration::Dictionary).to receive(:instance).and_return(
      instance_double(ActiveContext::Migration::Dictionary,
        migrations: dictionary_versions,
        find_by_version: dictionary_klass)
    )
  end

  describe '#perform' do
    context 'when indexing is disabled' do
      before do
        allow(ActiveContext).to receive(:indexing?).and_return(false)
      end

      it 'returns false' do
        expect(worker.perform).to be false
      end
    end

    context 'when there are failed migrations' do
      let_it_be(:migration_record) do
        create(:ai_active_context_migration, :failed, connection: connection, version: migration_version)
      end

      it 'halts execution' do
        expect(worker.perform).to be_nil
      end
    end

    context 'when there are missing migration records' do
      it 'creates missing migration records' do
        expect { worker.perform }.to change { connection.migrations.count }.by(1)
      end
    end

    context 'when there are orphaned migration records' do
      let_it_be(:orphaned_record) do
        create(:ai_active_context_migration, connection: connection, version: '20230101010101')
      end

      let(:dictionary_versions) { [] }
      let(:dictionary_klass) { nil }

      it 'deletes orphaned migration records' do
        expect { worker.perform }.to change { connection.migrations.count }.by(-1)
      end
    end

    context 'when there is a pending migration record' do
      let_it_be_with_reload(:migration_record) do
        create(:ai_active_context_migration, connection: connection, version: migration_version)
      end

      it 'marks the migration as completed' do
        worker.perform

        expect(migration_record.reload.status).to eq('completed')
        expect(migration_record.reload.started_at).not_to be_nil
        expect(migration_record.reload.completed_at).not_to be_nil
      end

      context 'when the migration fails' do
        let(:dictionary_klass) { failing_migration_class }

        it 'decreases retries on the migration record' do
          expect { worker.perform }.to change { migration_record.reload.retries_left }.by(-1)
        end

        context 'when no retries are left' do
          let_it_be_with_reload(:migration_record) do
            create(:ai_active_context_migration, connection: connection, version: '20240101010102', retries_left: 1)
          end

          let(:dictionary_versions) { ['20240101010102'] }

          it 'marks the migration as failed' do
            worker.perform

            expect(migration_record.reload.status).to eq('failed')
            expect(migration_record.reload.retries_left).to eq(0)
          end
        end
      end

      context 'when the migration should be skipped' do
        let(:dictionary_klass) { skipping_migration_class }

        it 'marks the migration as skipped' do
          worker.perform

          expect(migration_record.reload.status).to eq('skipped')
        end

        context 'when the migration record is already skipped' do
          before do
            migration_record.skipped!
          end

          it 'does not change the status' do
            worker.perform

            expect(migration_record.reload.status).to eq('skipped')
          end
        end
      end

      context 'when the migration is already in progress' do
        let_it_be_with_reload(:migration_record) do
          create(:ai_active_context_migration, :in_progress, connection: connection, version: '20240101010103')
        end

        let(:dictionary_versions) { ['20240101010103'] }

        it 'does not update started_at' do
          original_started_at = migration_record.started_at

          worker.perform

          expect(migration_record.reload.started_at).to be_within(0.001.seconds).of(original_started_at)
        end

        it 'still completes the migration' do
          worker.perform

          expect(migration_record.reload.status).to eq('completed')
        end
      end
    end

    context 'when there are skipped migrations to re-evaluate' do
      let_it_be_with_reload(:migration_record) do
        create(:ai_active_context_migration, connection: connection, version: migration_version, status: :skipped)
      end

      context 'when the skip condition is no longer met' do
        it 'processes the migration' do
          worker.perform

          expect(migration_record.reload.status).to eq('completed')
        end
      end

      context 'when the skip condition is still met' do
        let(:dictionary_klass) { skipping_migration_class }

        it 'does not change the migration status' do
          worker.perform

          expect(migration_record.reload.status).to eq('skipped')
        end
      end
    end

    context 'when there are no pending migrations' do
      let_it_be(:migration_record) do
        create(:ai_active_context_migration, :completed, connection: connection, version: migration_version)
      end

      it 'returns true' do
        expect(worker.perform).to be true
      end

      it 'logs that there are no pending migrations' do
        worker.perform

        expect(logger).to have_received(:info)
          .with(hash_including('message' => /No pending migrations to process/))
      end
    end
  end
end

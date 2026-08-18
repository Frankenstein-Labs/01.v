# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Migration, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:connection) { create(:ai_active_context_connection) }

  describe 'associations' do
    it { is_expected.to belong_to(:connection).class_name('Ai::ActiveContext::Connection') }
  end

  describe 'validations' do
    describe 'version' do
      it { is_expected.to validate_presence_of(:version) }

      context 'for uniqueness validations' do
        let!(:existing_migration) { create(:ai_active_context_migration, connection: connection) }

        it 'validates uniqueness of version scoped to connection_id' do
          new_migration = build(:ai_active_context_migration,
            connection: existing_migration.connection,
            version: existing_migration.version)

          expect(new_migration).not_to be_valid
          expect(new_migration.errors[:version]).to include('has already been taken')
        end

        it 'allows same version for different connections' do
          new_migration = build(:ai_active_context_migration,
            version: existing_migration.version)

          expect(new_migration).to be_valid
        end
      end

      context 'when validating format' do
        let(:migration) { build(:ai_active_context_migration) }

        where(:version, :valid) do
          '20250212093911'  | true   # Valid 14-digit timestamp
          '20250212093'     | false  # Too short
          '2025021209391a'  | false  # Contains non-digit
          '202502120939111' | false  # Too long
          nil               | false  # Nil value
          ''                | false  # Empty string
        end

        with_them do
          before do
            migration.version = version
          end

          it 'validates version format correctly' do
            expect(migration.valid?).to eq(valid)

            expect(migration.errors[:version]).to include('must be a 14-digit timestamp') unless valid
          end
        end
      end
    end

    describe 'status' do
      it { is_expected.to validate_presence_of(:status) }
    end

    describe 'retries_left' do
      let(:migration) { build(:ai_active_context_migration) }

      context 'when validating numericality' do
        where(:retries_left_value, :status_value, :valid) do
          -1                                 | 'pending'     | false  # Negative value
          0                                  | 'failed'      | true   # Minimum allowed value with failed status
          1                                  | 'pending'     | true   # Valid value
        end

        with_them do
          it 'validates retries_left value correctly' do
            migration.retries_left = retries_left_value
            migration.status = status_value
            expect(migration.valid?).to eq(valid)

            expect(migration.errors[:retries_left]).to be_present unless valid
          end
        end
      end

      it 'does not allow nil value' do
        migration.retries_left = nil
        expect(migration).to be_invalid
      end

      context 'when retries_left is 0' do
        before do
          migration.retries_left = 0
        end

        it 'is valid when status is failed' do
          migration.status = 'failed'
          expect(migration).to be_valid
        end

        it 'is invalid when status is not failed' do
          migration.status = 'pending'
          expect(migration).not_to be_valid
          expect(migration.errors[:retries_left]).to include('can only be 0 when status is failed')
        end
      end
    end
  end

  describe 'database constraints' do
    let(:migration) { create(:ai_active_context_migration, connection: connection) }

    it 'enforces version format through check constraint' do
      expect do
        # Using update_column bypasses validations but runs SQL
        migration.update_column(:version, 'invalid')
      end.to raise_error(ActiveRecord::StatementInvalid, /violates check constraint/)
    end

    it 'enforces retries constraint through check constraint' do
      expect do
        # Using update_columns to update multiple columns while bypassing validations
        migration.update_columns(
          retries_left: 0,
          status: described_class.statuses[:pending]
        )
      end.to raise_error(ActiveRecord::StatementInvalid, /violates check constraint/)
    end

    it 'enforces non-negative retries_left through check constraint' do
      expect do
        # Using update_column bypasses validations but runs SQL
        migration.update_column(:retries_left, -1)
      end.to raise_error(ActiveRecord::StatementInvalid, /violates check constraint/)
    end

    it 'enforces unique combination of connection_id and version' do
      existing = create(:ai_active_context_migration, connection: connection)
      new_migration = build(:ai_active_context_migration, connection: existing.connection, version: existing.version)

      expect do
        new_migration.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'scopes' do
    describe '.processable' do
      let_it_be(:pending) { create(:ai_active_context_migration, connection: connection, status: :pending) }
      let_it_be(:in_progress) { create(:ai_active_context_migration, connection: connection, status: :in_progress) }
      let_it_be(:completed_migration) do
        create(:ai_active_context_migration, connection: connection, status: :completed)
      end

      let_it_be(:failed) { create(:ai_active_context_migration, connection: connection, status: :failed) }

      it 'returns migrations that are pending, in_progress, or failed with retries left' do
        processable = described_class.processable

        expect(processable).to include(pending, in_progress)
        expect(processable).not_to include(completed_migration, failed)
      end

      it 'orders migrations by version' do
        expect(described_class.processable.to_a).to eq([
          pending,
          in_progress
        ])
      end
    end
  end

  describe '.current' do
    context 'when there are processable migrations' do
      let_it_be(:older_migration) { create(:ai_active_context_migration, connection: connection, status: :pending) }
      let_it_be(:newer_migration) { create(:ai_active_context_migration, connection: connection, status: :pending) }

      it 'returns the oldest processable migration by version' do
        expect(described_class.current).to eq(older_migration)
      end
    end

    context 'when there are no processable migrations' do
      let_it_be(:completed_migration) do
        create(:ai_active_context_migration, connection: connection, status: :completed)
      end

      let_it_be(:failed) do
        create(:ai_active_context_migration, connection: connection, status: :failed, retries_left: 0)
      end

      it 'returns nil' do
        expect(described_class.current).to be_nil
      end
    end
  end

  describe '#mark_as_failed!' do
    let(:error) { StandardError.new('Something went wrong') }
    let(:migration) { create(:ai_active_context_migration, connection: connection) }

    it 'updates the status to failed, decrements retries_left, and sets error_message' do
      expect { migration.mark_as_failed!(error) }
        .to change { migration.status }.from('pending').to('failed')
        .and change { migration.error_message }.from(nil).to('StandardError: Something went wrong')
    end
  end

  describe '#decrease_retries!' do
    let(:error) { StandardError.new('something went wrong') }

    context 'when retries are available' do
      let(:migration) { create(:ai_active_context_migration, connection: connection, retries_left: 3) }

      it 'decreases retries_left by 1' do
        expect { migration.decrease_retries!(error) }.to change { migration.retries_left }.from(3).to(2)
      end
    end

    context 'when no retries are left' do
      let(:migration) { create(:ai_active_context_migration, connection: connection, retries_left: 1) }

      it 'marks the migration as failed' do
        migration.decrease_retries!(error)

        expect(migration.status).to eq('failed')
        expect(migration.retries_left).to eq(0)
        expect(migration.error_message).to include(error.message)
      end
    end
  end

  describe '.complete?' do
    let(:version) { '20250212093911' }

    before do
      allow(Rails.cache).to receive(:fetch).and_yield
    end

    it 'calls check_complete_uncached with the given identifier' do
      expect(described_class).to receive(:check_complete_uncached).with(version).and_return(true)

      expect(described_class.complete?(version)).to be true
    end

    it 'caches the result with the correct key and timeout' do
      allow(described_class).to receive(:check_complete_uncached).with(version).and_return(true)

      expect(Rails.cache).to receive(:fetch).with([:ai_active_context_migration_completed, version],
        expires_in: described_class::CACHE_TIMEOUT)

      described_class.complete?(version)
    end
  end

  describe '.check_complete_uncached' do
    subject(:check_complete_uncached) { described_class.send(:check_complete_uncached, identifier) }

    let_it_be(:inactive_connection) { create(:ai_active_context_connection, active: false) }
    let(:version) { '20250212093911' }
    let(:identifier) { version }

    context 'with a numeric version identifier' do
      context 'when no completed migration exists for the version' do
        it 'returns false' do
          expect(check_complete_uncached).to be false
        end
      end

      context 'when a completed migration exists but connection is inactive' do
        before do
          create(:ai_active_context_migration, connection: inactive_connection, version: version, status: :completed)
        end

        it 'returns false' do
          expect(check_complete_uncached).to be false
        end
      end

      context 'when a completed migration exists with active connection' do
        before do
          create(:ai_active_context_migration, connection: connection, version: version, status: :completed)
        end

        it 'returns true' do
          expect(check_complete_uncached).to be true
        end
      end

      context 'when migration exists but is not completed' do
        before do
          create(:ai_active_context_migration, connection: connection, version: version, status: :pending)
        end

        it 'returns false' do
          expect(check_complete_uncached).to be false
        end
      end
    end

    context 'with a class name identifier' do
      let(:class_name) { 'SomeMigrationClass' }
      let(:identifier) { class_name }

      context 'when the class name exists in the dictionary' do
        before do
          dictionary_instance = instance_double(::ActiveContext::Migration::Dictionary)
          allow(::ActiveContext::Migration::Dictionary).to receive(:instance).and_return(dictionary_instance)
          allow(dictionary_instance).to receive(:find_version_by_class_name).with(class_name).and_return(version)
        end

        context 'when no completed migration exists for the version' do
          it 'returns false' do
            expect(check_complete_uncached).to be false
          end
        end

        context 'when a completed migration exists with active connection' do
          before do
            create(:ai_active_context_migration, connection: connection, version: version, status: :completed)
          end

          it 'returns true' do
            expect(check_complete_uncached).to be true
          end
        end
      end

      context 'when the class name does not exist in the dictionary' do
        before do
          dictionary_instance = instance_double(::ActiveContext::Migration::Dictionary)
          allow(::ActiveContext::Migration::Dictionary).to receive(:instance).and_return(dictionary_instance)
          allow(dictionary_instance).to receive(:find_version_by_class_name).with(class_name).and_return(nil)
        end

        it 'returns false' do
          expect(check_complete_uncached).to be false
        end
      end
    end
  end
end

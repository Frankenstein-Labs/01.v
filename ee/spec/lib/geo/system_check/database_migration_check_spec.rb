# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::DatabaseMigrationCheck, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  subject(:database_migration_check) { described_class.new }

  describe '#skip?' do
    context 'when not a secondary node' do
      before do
        stub_primary_site
      end

      it 'returns true' do
        expect(database_migration_check.skip?).to be true
      end
    end

    context 'when a secondary node' do
      before do
        stub_secondary_site
      end

      context 'when not in logical replication mode' do
        before do
          stub_logical_replication_mode(false)
        end

        it 'returns true' do
          expect(database_migration_check.skip?).to be true
        end
      end

      context 'when in logical replication mode' do
        before do
          stub_logical_replication_mode(true)
        end

        it 'returns false' do
          expect(database_migration_check.skip?).to be false
        end
      end
    end
  end

  describe '#check?' do
    context 'when no databases have pending migrations' do
      before do
        stub_pending_databases([])
      end

      it 'returns true' do
        expect(database_migration_check.check?).to be true
      end
    end

    context 'when databases have pending migrations' do
      before do
        stub_pending_databases([:main, :ci])
      end

      it 'returns false' do
        expect(database_migration_check.check?).to be false
      end
    end
  end

  describe '#show_error' do
    before do
      stub_pending_databases([:main])
    end

    it 'shows a fix suggestion with pending databases' do
      expect(database_migration_check).to receive(:try_fixing_it).with(
        'Databases with pending migrations: main',
        'Run `gitlab-rake db:migrate` on the secondary to apply pending migrations'
      )
      expect(database_migration_check).to receive(:for_more_information)

      database_migration_check.show_error
    end
  end

  describe '#skip_reason' do
    context 'when not a secondary node' do
      before do
        stub_primary_site
      end

      it 'returns not a secondary node message' do
        expect(database_migration_check.skip_reason).to eq('not a secondary node')
      end
    end

    context 'when a secondary node' do
      before do
        stub_secondary_site
      end

      context 'when not using logical replication' do
        before do
          stub_logical_replication_mode(false)
        end

        it 'returns not using logical replication message' do
          expect(database_migration_check.skip_reason).to eq('not using logical replication')
        end
      end

      context 'when using logical replication' do
        before do
          stub_logical_replication_mode(true)
        end

        it 'returns nil' do
          expect(database_migration_check.skip_reason).to be_nil
        end
      end
    end
  end

  def stub_logical_replication_mode(enabled)
    allow_next_instance_of(::Gitlab::Geo::HealthCheck) do |health_check|
      allow(health_check).to receive(:logical_replication_mode?).and_return(enabled)
    end
  end

  def stub_pending_databases(databases)
    allow_next_instance_of(::Gitlab::Geo::HealthCheck) do |health_check|
      allow(health_check).to receive(:pending_migration_databases).and_return(databases)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Types::MigrationsIndexConfig, feature_category: :global_search do
  describe '.index_name' do
    it 'delegates to References::MigrationsIndexConfig.index' do
      expect(described_class.index_name).to eq(Search::Elastic::References::MigrationsIndexConfig.index)
    end

    it 'returns correct environment based index name' do
      expect(described_class.index_name).to match(/gitlab-test-search-migrations/)
    end
  end

  describe '.mappings' do
    let(:mappings) { described_class.mappings[:properties] }

    it 'contains expected migration tracking fields' do
      expect(mappings.keys).to contain_exactly(:completed, :state, :started_at, :completed_at, :name)
    end

    it 'defines correct field types' do
      expect(mappings[:completed][:type]).to eq('boolean')
      expect(mappings[:state][:type]).to eq('object')
      expect(mappings[:started_at][:type]).to eq('date')
      expect(mappings[:completed_at][:type]).to eq('date')
      expect(mappings[:name][:type]).to eq('keyword')
    end
  end

  describe '.settings' do
    it 'returns settings with number_of_shards' do
      expect(described_class.settings[:number_of_shards]).to eq(1)
    end
  end

  describe '.ready?' do
    context 'when delete_legacy_migrations_index migration has finished' do
      before do
        allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:delete_legacy_migrations_index)
          .and_return(true)
      end

      it 'returns true' do
        expect(described_class.ready?).to be true
      end
    end

    context 'when delete_legacy_migrations_index migration has not finished' do
      before do
        allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:delete_legacy_migrations_index)
          .and_return(false)
      end

      it 'returns false' do
        expect(described_class.ready?).to be false
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MigrationsIndexConfig, feature_category: :global_search do
  describe '.alias_name' do
    let(:helper) { Search::Elastic::Helper.default }

    context 'when elasticsearch_migrations_type_class feature flag is disabled' do
      before do
        stub_feature_flags(elasticsearch_migrations_type_class: false)
      end

      it 'returns the migrations index name from Helper' do
        expect(described_class.alias_name).to eq(helper.migrations_index_name)
      end
    end

    context 'when elasticsearch_migrations_type_class feature flag is enabled' do
      before do
        stub_feature_flags(elasticsearch_migrations_type_class: true)
      end

      it 'delegates to Types::MigrationsIndexConfig.index_name' do
        expect(described_class.alias_name).to eq(Search::Elastic::Types::MigrationsIndexConfig.index_name)
      end
    end
  end

  describe '.ready?' do
    context 'when elasticsearch_migrations_type_class feature flag is disabled' do
      before do
        stub_feature_flags(elasticsearch_migrations_type_class: false)
      end

      it 'checks if delete_legacy_migrations_index migration has finished' do
        expect(Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:delete_legacy_migrations_index)
          .and_return(true)

        expect(described_class.ready?).to be true
      end
    end

    context 'when elasticsearch_migrations_type_class feature flag is enabled' do
      before do
        stub_feature_flags(elasticsearch_migrations_type_class: true)
      end

      it 'delegates to Types::MigrationsIndexConfig.ready?' do
        expect(Search::Elastic::Types::MigrationsIndexConfig).to receive(:ready?).and_return(true)

        expect(described_class.ready?).to be true
      end
    end
  end
end

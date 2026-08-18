# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BaseRegistry, :geo, feature_category: :geo_replication do
  let(:registry_class) { Geo::UploadRegistry }

  describe '.has_create_events?' do
    it 'returns true by default' do
      expect(described_class.has_create_events?).to be_truthy
    end
  end

  describe '.delete_worker_class' do
    it 'returns Geo::DestroyWorker' do
      expect(described_class.delete_worker_class).to eq(::Geo::DestroyWorker)
    end
  end

  describe '.graphql_enum_key' do
    it 'generates GraphQL enum key from class name' do
      expect(described_class.graphql_enum_key).to eq('BASE_REGISTRY')
    end

    it 'generates correct key for concrete subclass' do
      expect(registry_class.graphql_enum_key).to eq('UPLOAD_REGISTRY')
    end
  end

  describe '.model_id_in' do
    let_it_be(:registry1) { create(:geo_upload_registry) }
    let_it_be(:registry2) { create(:geo_upload_registry) }
    let_it_be(:registry3) { create(:geo_upload_registry) }

    it 'returns registries matching the given model IDs' do
      model_ids = [registry1.file_id, registry3.file_id]

      result = registry_class.model_id_in(model_ids)

      expect(result).to contain_exactly(registry1, registry3)
    end

    it 'returns empty relation when no IDs match' do
      result = registry_class.model_id_in([non_existing_record_id])

      expect(result).to be_empty
    end
  end

  describe '.model_id_not_in' do
    let_it_be(:registry1) { create(:geo_upload_registry) }
    let_it_be(:registry2) { create(:geo_upload_registry) }
    let_it_be(:registry3) { create(:geo_upload_registry) }

    it 'returns registries not matching the given model IDs' do
      excluded_ids = [registry1.file_id, registry3.file_id]

      result = registry_class.model_id_not_in(excluded_ids)

      expect(result).to contain_exactly(registry2)
    end
  end

  describe '.ordered_by_id' do
    let_it_be(:registry1) { create(:geo_upload_registry) }
    let_it_be(:registry2) { create(:geo_upload_registry) }

    it 'returns registries ordered by id ascending' do
      result = registry_class.ordered_by_id

      expect(result.first.id).to be < result.last.id
    end
  end

  describe '.ordered_by' do
    let_it_be(:registry1) { create(:geo_upload_registry, last_synced_at: 2.days.ago) }
    let_it_be(:registry2) { create(:geo_upload_registry, last_synced_at: 1.day.ago) }

    it 'orders by id descending when given id_desc' do
      result = registry_class.ordered_by(:id_desc)

      expect(result.first).to eq(registry2)
      expect(result.last).to eq(registry1)
    end

    it 'orders by last_synced_at ascending when given last_synced_at_asc' do
      result = registry_class.ordered_by(:last_synced_at_asc)

      expect(result.first).to eq(registry1)
      expect(result.last).to eq(registry2)
    end

    it 'orders by last_synced_at descending when given last_synced_at_desc' do
      result = registry_class.ordered_by(:last_synced_at_desc)

      expect(result.first).to eq(registry2)
      expect(result.last).to eq(registry1)
    end

    it 'defaults to ordered_by_id for unknown sort methods' do
      result = registry_class.ordered_by(:unknown)

      expect(result.first.id).to be < result.last.id
    end
  end

  describe '#model_record_id' do
    let(:registry) { create(:geo_upload_registry) }

    it 'returns the model foreign key value' do
      expect(registry.model_record_id).to eq(registry.file_id)
    end
  end
end

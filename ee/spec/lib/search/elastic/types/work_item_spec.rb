# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Types::WorkItem, feature_category: :global_search do
  describe '#target' do
    it 'returns work_item class' do
      expect(described_class.target.class.name).to eq(WorkItem.class.name)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name' do
      expect(described_class.index_name).to eq('gitlab-test-work_items')
    end
  end

  describe '#mappings' do
    let(:mappings) { described_class.mappings.to_hash[:properties] }

    it 'contains base mappings' do
      expect(mappings.keys).to include(:id, :title, :description)
    end

    it 'does not contain embedding fields' do
      expect(mappings.keys).not_to include(:embedding_0, :embedding_1)
    end
  end

  describe '#settings' do
    let(:settings) { described_class.settings.to_hash[:index].keys }

    it 'contains base settings' do
      expect(settings).to include(:number_of_shards)
    end
  end
end

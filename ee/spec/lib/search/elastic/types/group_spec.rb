# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Types::Group, feature_category: :global_search do
  let(:helper) { Search::Elastic::Helper.default }
  let(:base_mappings) { described_class.send(:base_mappings).keys }

  before do
    allow(Search::Elastic::Helper).to receive(:default).and_return(helper)
  end

  describe '#index_name' do
    it 'returns correct environment based index name' do
      expect(described_class.index_name).to eq('gitlab-test-groups')
    end
  end

  describe '#target' do
    it 'returns the Group model' do
      expect(described_class.target).to eq(::Group)
    end
  end

  describe '#mappings' do
    let(:mappings) { described_class.mappings.to_hash }
    let(:properties) { mappings[:properties] }

    it 'is strict' do
      expect(mappings[:dynamic]).to eq('strict')
    end

    it 'contains all base mappings' do
      expect(properties.keys).to match_array(base_mappings)
    end

    it 'maps text fields with analyzers', :aggregate_failures do
      expect(properties[:name][:type]).to eq('text')
      expect(properties[:name][:analyzer]).to eq('my_ngram_analyzer')
      expect(properties[:full_name][:type]).to eq('text')
      expect(properties[:full_name][:analyzer]).to eq('my_ngram_analyzer')
    end

    it 'maps text fields with positions', :aggregate_failures do
      expect(properties[:path][:type]).to eq('text')
      expect(properties[:path][:index_options]).to eq('positions')
      expect(properties[:full_path][:type]).to eq('text')
      expect(properties[:full_path][:index_options]).to eq('positions')
      expect(properties[:description][:type]).to eq('text')
      expect(properties[:description][:index_options]).to eq('positions')
    end

    it 'maps keyword fields', :aggregate_failures do
      expect(properties[:traversal_ids][:type]).to eq('keyword')
    end

    it 'maps visibility_level as short' do
      expect(properties[:visibility_level][:type]).to eq('short')
    end

    it 'maps date fields', :aggregate_failures do
      expect(properties[:created_at][:type]).to eq('date')
      expect(properties[:updated_at][:type]).to eq('date')
    end

    it 'maps long fields', :aggregate_failures do
      expect(properties[:id][:type]).to eq('long')
      expect(properties[:parent_id][:type]).to eq('long')
      expect(properties[:organization_id][:type]).to eq('long')
    end

    it 'maps archived as boolean' do
      expect(properties[:archived][:type]).to eq('boolean')
    end
  end

  describe '#settings' do
    let(:settings) { described_class.settings.to_hash }

    it 'contains base index settings' do
      expect(settings[:index].keys).to include(:number_of_shards)
    end
  end
end

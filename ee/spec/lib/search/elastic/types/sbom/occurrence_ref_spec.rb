# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Types::Sbom::OccurrenceRef, feature_category: :dependency_management do
  let(:helper) { Search::Elastic::Helper.default }
  let(:base_mappings) { described_class.send(:base_mappings).keys }

  before do
    allow(Search::Elastic::Helper).to receive(:default).and_return(helper)
  end

  describe '#index_name' do
    it 'returns correct environment based index name' do
      expect(described_class.index_name).to eq('gitlab-test-sbom_occurrence_refs')
    end
  end

  describe '#target' do
    it 'returns the Sbom::OccurrenceRef model' do
      expect(described_class.target).to eq(::Sbom::OccurrenceRef)
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

    it 'maps all enum fields as short', :aggregate_failures do
      %i[source_type highest_severity reachability purl_type component_type schema_version].each do |field|
        expect(properties[field][:type]).to eq('short')
      end
    end

    it 'maps denormalised primary and secondary license fields as keyword', :aggregate_failures do
      expect(properties[:primary_license_spdx_identifier][:type]).to eq('keyword')
      expect(properties[:primary_license_name][:type]).to eq('keyword')
      expect(properties[:secondary_license_spdx_identifier][:type]).to eq('keyword')
      expect(properties[:secondary_license_name][:type]).to eq('keyword')
    end

    it 'does not map a nested licenses field' do
      expect(properties).not_to have_key(:licenses)
    end

    it 'maps malware as boolean' do
      expect(properties[:malware][:type]).to eq('boolean')
    end
  end

  describe '#settings' do
    let(:settings) { described_class.settings.to_hash }

    it 'contains base index settings' do
      expect(settings[:index].keys).to include(:number_of_shards)
    end
  end
end

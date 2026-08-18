# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Errors::ErrorType, feature_category: :geo_replication do
  describe 'the catalog' do
    subject(:items) { described_class.all }

    it 'has unique ids and names', :aggregate_failures do
      expect(items.map(&:id).uniq.size).to eq(items.size)
      expect(items.map(&:name).uniq.size).to eq(items.size)
    end

    it 'uses known severities and sites', :aggregate_failures do
      expect(items.map(&:severity)).to all(be_in(described_class::SEVERITIES))
      expect(items.map(&:site)).to all(be_in(described_class::SITES))
    end

    it 'gives every resolvable entry a resolve strategy', :aggregate_failures do
      resolvable = items.select(&:resolvable)

      expect(resolvable).to be_present
      expect(resolvable.map(&:resolve_strategy)).to all(be_present)
    end

    it 'points every resolve strategy at a registered resolution' do
      strategies = items.filter_map(&:resolve_strategy).uniq

      expect(strategies).to all(be_in(Geo::Tools::Resolutions::STRATEGIES.keys))
    end
  end

  describe '.find_by' do
    it 'looks up an entry by name' do
      expect(described_class.find_by(name: 'url_blocked')).to have_attributes(name: 'url_blocked')
    end
  end
end

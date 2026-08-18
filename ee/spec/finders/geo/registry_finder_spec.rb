# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::RegistryFinder, feature_category: :geo_replication do
  describe '#registry_class' do
    it 'raises NotImplementedError when not implemented in subclass' do
      base_finder = described_class.new

      expect { base_finder.registry_class }.to raise_error(NotImplementedError)
    end
  end
end

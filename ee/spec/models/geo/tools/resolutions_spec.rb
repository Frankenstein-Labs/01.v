# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Tools::Resolutions, feature_category: :geo_replication do
  describe '.for' do
    it 'returns the resolution object for a known strategy' do
      error_type = Geo::Errors::ErrorType.find_by(name: 'url_blocked')

      expect(described_class.for(error_type)).to be_a(Geo::Tools::Resolutions::Resync)
    end

    it 'returns the primary-side resolution for the missing-file error' do
      error_type = Geo::Errors::ErrorType.find_by(name: 'file_missing_on_primary')

      expect(described_class.for(error_type))
        .to be_a(Geo::Tools::Resolutions::DestroyReplicablesWithMissingFiles)
    end

    it 'raises for an unknown strategy' do
      error_type = instance_double(Geo::Errors::ErrorType, resolve_strategy: 'nope')

      expect { described_class.for(error_type) }
        .to raise_error(described_class::UnknownStrategyError, /nope/)
    end
  end
end

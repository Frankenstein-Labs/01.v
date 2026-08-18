# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::TrackingBase, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  it 'raises when Geo database is not configured' do
    with_geo_database_configured(enabled: false) do
      expect(described_class).not_to receive(:retrieve_connection)
      expect { described_class.connection }.to raise_error(Geo::TrackingBase::SecondaryNotConfigured)
    end
  end

  it 'raises when Geo database is not found' do
    with_geo_database_configured(enabled: true) do
      allow(described_class).to receive(:retrieve_connection).and_raise(ActiveRecord::NoDatabaseError.new('not found'))

      expect(described_class).to receive(:retrieve_connection)
      expect { described_class.connection }.to raise_error(Geo::TrackingBase::SecondaryNotConfigured)
    end
  end
end

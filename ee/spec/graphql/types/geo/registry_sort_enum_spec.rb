# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GeoRegistrySort'], feature_category: :geo_replication do
  it { expect(described_class.graphql_name).to eq('GeoRegistrySort') }

  it 'exposes the correct registry sort parameters' do
    parameters = %w[ID_ASC ID_DESC VERIFIED_AT_ASC VERIFIED_AT_DESC LAST_SYNCED_AT_ASC LAST_SYNCED_AT_DESC]
    expect(described_class.values.keys).to include(*parameters)
  end
end

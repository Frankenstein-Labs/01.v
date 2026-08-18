# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe RescaleGeoVerificationMaxCapacity, migration: :gitlab_main_cell_local,
  # `geo_nodes` lives on the main database, not the Geo tracking database. Opt out of the
  # `:geo` metadata that ee/spec/spec_helper.rb auto-applies to specs with "geo" in the path.
  geo: false, feature_category: :geo_replication do
  let(:geo_nodes) { table(:geo_nodes) }
  let(:count) { described_class::VERIFICATION_ENABLED_REPLICATOR_COUNT }

  let!(:high_capacity_node) do
    geo_nodes.create!(name: 'primary', url: 'https://primary.example.com', verification_max_capacity: count * 5)
  end

  let!(:low_capacity_node) do
    geo_nodes.create!(name: 'secondary', url: 'https://secondary.example.com', verification_max_capacity: 3)
  end

  it 'rescales each node capacity by the verification-enabled replicator count, flooring at 1' do
    migrate!

    # floor((count * 5) / count)
    expect(high_capacity_node.reload.verification_max_capacity).to eq(5)
    # max(1, floor(3 / count)): count is well above 3, so this floors to 1
    expect(low_capacity_node.reload.verification_max_capacity).to eq(1)
  end
end

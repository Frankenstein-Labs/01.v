# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SupplyChainAttestationReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:supply_chain_attestation) }

  include_examples 'a blob replicator'
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SupplyChainAttestationState, :geo, feature_category: :geo_replication do
  it { is_expected.to be_a ::Geo::VerificationStateDefinition }

  describe 'associations' do
    it { is_expected.to belong_to(:supply_chain_attestation).class_name('::SupplyChain::Attestation') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:supply_chain_attestation) }
    it { is_expected.to validate_presence_of(:verification_state) }
  end
end

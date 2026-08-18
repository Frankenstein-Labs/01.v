# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesHelmMetadataCacheState, :geo, feature_category: :geo_replication do
  it { is_expected.to be_a ::Geo::VerificationStateDefinition }

  describe 'associations' do
    it { is_expected.to belong_to(:packages_helm_metadata_cache).class_name('::Packages::Helm::MetadataCache') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:packages_helm_metadata_cache) }
    it { is_expected.to validate_presence_of(:verification_state) }
  end
end

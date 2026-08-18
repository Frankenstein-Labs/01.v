# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::DependencyProxyManifestState, :geo, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:dependency_proxy_manifest).inverse_of(:dependency_proxy_manifest_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:dependency_proxy_manifest) }
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SPDX::CatalogueGateway, feature_category: :software_composition_analysis do
  include StubRequests

  describe "#fetch" do
    let(:result) { subject.fetch }
    let(:catalogue_hash) { ::Gitlab::Json.safe_parse(spdx_json, symbolize_names: true) }
    let(:spdx_json) { described_class::OFFLINE_CATALOGUE_PATH.read }

    it { expect(result.count).to be(catalogue_hash[:licenses].count) }
  end
end

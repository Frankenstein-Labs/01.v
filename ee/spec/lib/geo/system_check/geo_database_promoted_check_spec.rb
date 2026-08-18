# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::GeoDatabasePromotedCheck, feature_category: :geo_replication do
  include EE::GeoHelpers

  subject(:geo_database_promoted_check) { described_class.new }

  describe 'skip?' do
    # freeze: true prevents accidental mutation of shared test data
    # it holds true for both because neither of them are mutated here
    let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }
    let_it_be(:secondary_node, freeze: true) { create(:geo_node) }

    before do
      stub_current_geo_node(primary_node)
    end

    it 'skips when Geo disabled' do
      allow(Gitlab::Geo).to receive(:enabled?).and_return(false)

      expect(geo_database_promoted_check.skip?).to be_truthy
    end

    it 'skips when Geo is enabled but its a secondary node' do
      stub_current_geo_node(secondary_node)

      expect(geo_database_promoted_check.skip?).to be_truthy
    end

    it 'does not skip when Geo is enabled and its a primary node' do
      expect(geo_database_promoted_check.skip?).to be_falsey
    end
  end

  describe '#check?' do
    it 'succeeds when there is no Geo tracking database configured' do
      allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_return(false)

      expect(geo_database_promoted_check.check?).to be_truthy
    end

    it 'fails when there is a Geo tracking database configured' do
      allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_return(true)

      expect(geo_database_promoted_check.check?).to be_falsey
    end
  end

  describe '#show_error' do
    it 'shows errors when there is a Geo tracking database configured' do
      allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_return(true)

      expect(geo_database_promoted_check).to receive(:try_fixing_it)
      expect(geo_database_promoted_check).to receive(:for_more_information)

      geo_database_promoted_check.show_error
    end
  end
end

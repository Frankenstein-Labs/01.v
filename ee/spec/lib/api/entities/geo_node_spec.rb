# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::GeoNode, feature_category: :geo_replication do
  include EE::GeoHelpers

  subject(:entity) { described_class.new(geo_node).as_json }

  describe 'web_geo_replication_details_url' do
    let(:replicator_class) { class_double(::Gitlab::Geo::Replicator, replicable_name_plural: 'replicables') }

    before do
      allow(Gitlab::Geo).to receive(:replication_enabled_replicator_classes)
        .and_return(instance_double(Array, first: replicator_class))
    end

    context 'when the node is a primary' do
      let(:geo_node) { create(:geo_node, :primary) }

      before do
        stub_current_geo_node(geo_node)
      end

      it 'does not expose web_geo_replication_details_url' do
        expect(entity).not_to have_key(:web_geo_replication_details_url)
      end
    end

    context 'when the node is a secondary' do
      let(:geo_node) { create(:geo_node) }

      before do
        stub_current_geo_node(geo_node)
      end

      it 'exposes web_geo_replication_details_url' do
        expect(entity[:web_geo_replication_details_url]).to be_present
      end
    end

    context 'when the node is an org migration target' do
      let(:geo_node) { create(:geo_node) }

      before do
        stub_feature_flags(org_migration_target_cell: true)
        allow(Gitlab::Geo).to receive(:secondary?).and_return(false)
        stub_current_geo_node(geo_node)
      end

      it 'exposes web_geo_replication_details_url' do
        expect(entity[:web_geo_replication_details_url]).to be_present
      end
    end
  end
end

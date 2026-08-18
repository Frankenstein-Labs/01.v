# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::NodeUpdateService, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be_with_reload(:primary) { create(:geo_node, :primary) }
  let!(:geo_node) { create(:geo_node) }

  before do
    stub_current_geo_node(primary)
  end

  describe '#execute' do
    it 'updates the node' do
      params = { url: 'http://example.com' }
      service = described_class.new(geo_node, params)

      service.execute

      geo_node.reload
      expect(geo_node.url.chomp('/')).to eq(params[:url])
    end

    it 'returns true when update succeeds' do
      service = described_class.new(geo_node, { url: 'http://example.com' })

      expect(service.execute).to eq true
    end

    it 'returns false when update fails' do
      allow(geo_node).to receive(:update).and_return(false)

      service = described_class.new(geo_node, { url: 'http://example.com' })

      expect(service.execute).to eq false
    end

    context 'when params includes organization_ids' do
      context 'when organization_ids is a string of comma-separated integers' do
        it 'updates the organization links' do
          organization_1 = create(:organization)
          organization_2 = create(:organization)

          service = described_class.new(geo_node, { organization_ids: "#{organization_1.id},#{organization_2.id}" })
          expect(service.execute).to be true
          geo_node.reload

          expect(geo_node.organizations).to match_array([organization_1, organization_2])
        end
      end

      context 'when organization_ids is an empty string' do
        it 'successfully removes organization links' do
          organization = create(:organization)
          geo_node.organizations << organization
          geo_node.save!
          expect(geo_node.organizations).not_to be_empty

          service = described_class.new(geo_node, { organization_ids: '' })
          expect(service.execute).to be true
          geo_node.reload

          expect(geo_node.organizations).to be_empty
        end
      end

      context 'when organization_ids is an empty Array' do
        it 'successfully removes organization links' do
          organization = create(:organization)
          geo_node.organizations << organization
          geo_node.save!
          expect(geo_node.organizations).not_to be_empty

          service = described_class.new(geo_node, { organization_ids: [] })
          expect(service.execute).to be true
          geo_node.reload

          expect(geo_node.organizations).to be_empty
        end
      end
    end
  end
end

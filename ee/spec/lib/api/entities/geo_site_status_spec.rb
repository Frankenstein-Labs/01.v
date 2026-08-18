# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::GeoSiteStatus, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let!(:geo_node_status) { build(:geo_node_status) }
  let(:entity) { described_class.new(geo_node_status, request: double) }
  let(:error) { 'Could not connect to Geo database' }

  subject(:entity_json) { entity.as_json }

  before do
    stub_primary_node
  end

  describe '#healthy' do
    context 'when site is healthy' do
      it 'returns true' do
        expect(entity_json[:healthy]).to be true
      end
    end

    context 'when site is unhealthy' do
      before do
        geo_node_status.status_message = error
      end

      it 'returns false' do
        expect(entity_json[:healthy]).to be false
      end
    end
  end

  describe '#health' do
    context 'when site is healthy' do
      it 'exposes the health message' do
        expect(entity_json[:health]).to eq GeoNodeStatus::HEALTHY_STATUS
      end
    end

    context 'when site is unhealthy' do
      before do
        geo_node_status.status_message = error
      end

      it 'exposes the error message' do
        expect(entity_json[:health]).to eq error
      end
    end
  end

  describe '#job_artifacts_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(
        job_artifacts_registry_count: 256,
        job_artifacts_failed_count: 12,
        job_artifacts_synced_count: 123
      )

      expect(entity_json[:job_artifacts_synced_in_percentage]).to eq '48.05%'
    end
  end

  describe '#container_repositories_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(
        container_repositories_registry_count: 256,
        container_repositories_failed_count: 12,
        container_repositories_synced_count: 123
      )

      expect(entity_json[:container_repositories_synced_in_percentage]).to eq '48.05%'
    end
  end

  describe '#replication_slots_used_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(
        replication_slots_count: 4,
        replication_slots_used_count: 2
      )

      expect(entity_json[:replication_slots_used_in_percentage]).to eq '50.00%'
    end
  end

  describe '#namespaces' do
    it 'returns empty array when full sync is active' do
      expect(entity_json[:namespaces]).to be_empty
    end

    it 'returns array of namespace ids and paths for selective sync' do
      namespace = create(:namespace)
      geo_node_status.geo_node.namespaces << namespace

      expect(entity_json[:namespaces]).not_to be_empty
      expect(entity_json[:namespaces]).to be_an(Array)
      expect(entity_json[:namespaces].first[:id]).to eq(namespace.id)
      expect(entity_json[:namespaces].first[:path]).to eq(namespace.path)
    end
  end

  describe '#storage_shards' do
    it 'returns the config' do
      shards = StorageShard.all

      expect(entity_json[:storage_shards].count).to eq(shards.count)
      expect(entity_json[:storage_shards].first[:name]).to eq(shards.first.name)
    end
  end

  context 'when secondary Geo site' do
    before do
      stub_secondary_node
    end

    it { is_expected.to have_key(:storage_shards) }
    it { is_expected.to have_key(:storage_shards_match) }
  end
end

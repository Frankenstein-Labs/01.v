# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesHelmMetadataCacheReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:helm_metadata_cache) }

  include_examples 'a blob replicator'

  describe '#immutable?' do
    it 'returns false' do
      expect(model_record.replicator.immutable?).to be false
    end
  end

  describe 'updated event consumption' do
    context 'when in replicables_for_current_secondary list' do
      it 'downloads the blob' do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(true)

        expect(replicator).to receive(:download)

        replicator.consume(::Geo::ReplicatorEvents::EVENT_UPDATED)
      end
    end

    context 'when not in replicables_for_current_secondary list' do
      it 'does not download the blob' do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)

        expect(replicator).not_to receive(:download)

        replicator.consume(::Geo::ReplicatorEvents::EVENT_UPDATED)
      end
    end
  end

  describe '#geo_handle_after_update' do
    context 'on a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'creates a Geo::Event' do
        model_record # ensure record is created before counting

        expect do
          replicator.geo_handle_after_update
        end.to change { ::Geo::Event.where(replicable_name: replicator.replicable_name).count }.by(1)

        expect(::Geo::Event.last).to have_attributes(
          replicable_name: replicator.replicable_name,
          event_name: ::Geo::ReplicatorEvents::EVENT_UPDATED,
          payload: {
            "model_record_id" => replicator.model_record.id,
            "correlation_id" => an_instance_of(String)
          })
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does not create an event' do
        expect do
          replicator.geo_handle_after_update
        end.not_to change { ::Geo::Event.where(replicable_name: replicator.replicable_name).count }
      end
    end
  end
end

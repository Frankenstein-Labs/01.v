# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ChecksumMismatchReportingWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  describe '#perform' do
    let(:secondary) { create(:geo_node) }

    include_examples 'an idempotent worker' do
      context 'when running on a secondary with the feature flag enabled' do
        before do
          stub_current_geo_node(secondary)
          stub_feature_flags(geo_self_heal_checksum_mismatch: true)
        end

        it 'delegates to Geo::ChecksumMismatchReportingService' do
          service = Geo::ChecksumMismatchReportingService.new(secondary)
          allow(Geo::ChecksumMismatchReportingService).to receive(:new).and_return(service).at_least(1).time

          expect(service).to receive(:execute).and_call_original.at_least(1).time

          perform_multiple
        end
      end

      context 'when running on the primary' do
        before do
          stub_current_geo_node(create(:geo_node, :primary))
          stub_feature_flags(geo_self_heal_checksum_mismatch: true)
        end

        it 'does not delegate to Geo::ChecksumMismatchReportingService' do
          expect(Geo::ChecksumMismatchReportingService).not_to receive(:new)

          perform_multiple
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_current_geo_node(secondary)
          stub_feature_flags(geo_self_heal_checksum_mismatch: false)
        end

        it 'does not delegate to Geo::ChecksumMismatchReportingService' do
          expect(Geo::ChecksumMismatchReportingService).not_to receive(:new)

          perform_multiple
        end
      end
    end
  end
end

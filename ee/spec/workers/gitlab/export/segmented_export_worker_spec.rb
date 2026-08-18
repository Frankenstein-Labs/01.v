# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Export::SegmentedExportWorker, feature_category: :vulnerability_management do
  describe '#perform' do
    let(:vulnerability_export) { create(:vulnerability_export) }
    let(:global_id) { vulnerability_export.to_global_id }
    let(:segment_ids) { [1, 2, 3] }

    subject(:perform) { described_class.new.perform(global_id, segment_ids) }

    it 'calls SegmentExporterService#export' do
      expect_next_instance_of(
        ::Gitlab::SegmentedExport::SegmentExporterService,
        vulnerability_export,
        segment_ids) do |mock_service_object|
          expect(mock_service_object).to receive(:execute)
        end

      perform
    end
  end
end

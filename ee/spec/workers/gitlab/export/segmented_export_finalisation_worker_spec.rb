# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Export::SegmentedExportFinalisationWorker, feature_category: :vulnerability_management do
  describe '#perform' do
    let(:vulnerability_export) { create(:vulnerability_export) }
    let(:global_id) { vulnerability_export.to_global_id }

    subject(:perform) { described_class.new.perform(global_id) }

    it 'calls `Gitlab::SegmentedExport::FinalizerService#execute`' do
      expect_next_instance_of(::Gitlab::SegmentedExport::FinalizerService, vulnerability_export) do |mock_object|
        expect(mock_object).to receive(:execute)
      end

      perform
    end
  end
end

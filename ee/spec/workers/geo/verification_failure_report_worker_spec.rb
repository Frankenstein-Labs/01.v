# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::VerificationFailureReportWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:geo_node_id) { 5 }
  let(:failures) do
    [
      {
        'error_type' => 'checksum_mismatch',
        'replicable_name' => 'upload',
        'replicable_id' => 1,
        'verification_retry_count' => 3,
        'context' => { 'primary_checksum_at_mismatch' => 'abc123' }
      }
    ]
  end

  before do
    stub_current_geo_node(create(:geo_node, :primary))
  end

  describe '#perform' do
    let(:job_args) { [geo_node_id, failures] }

    include_examples 'an idempotent worker'

    it 'dispatches checksum_mismatch entries to Geo::ChecksumMismatchSelfHealService' do
      service = instance_double(Geo::ChecksumMismatchSelfHealService, execute: 1)

      expect(Geo::ChecksumMismatchSelfHealService).to receive(:new)
        .with(geo_node_id: geo_node_id, failures: [a_hash_including(error_type: 'checksum_mismatch')])
        .and_return(service)

      described_class.new.perform(*job_args)
    end

    context 'with an unknown error_type' do
      let(:failures) do
        [{ 'error_type' => 'some_future_error_type', 'replicable_name' => 'upload', 'replicable_id' => 1,
           'verification_retry_count' => 1 }]
      end

      it 'does not call Geo::ChecksumMismatchSelfHealService' do
        expect(Geo::ChecksumMismatchSelfHealService).not_to receive(:new)

        described_class.new.perform(*job_args)
      end
    end

    context 'when running on a secondary' do
      before do
        stub_current_geo_node(create(:geo_node))
      end

      it 'skips the job' do
        expect(Geo::ChecksumMismatchSelfHealService).not_to receive(:new)

        described_class.new.perform(*job_args)
      end
    end
  end
end

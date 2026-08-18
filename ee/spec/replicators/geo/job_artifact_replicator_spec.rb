# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::JobArtifactReplicator, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:model_record) { create(:ci_job_artifact, :with_file) }

  before do
    stub_feature_flags(geo_job_artifact_verification_summaries: false)
  end

  include_examples 'a blob replicator'

  describe '#event_params' do
    it 'includes partition_id so LogCursor can prune partitioned table lookups' do
      replicator = described_class.new(model_record: model_record)

      expect(replicator.event_params).to include('partition_id' => model_record.partition_id)
    end
  end

  context 'with verification summaries' do
    before do
      stub_primary_node
    end

    describe '.checksummed_count' do
      context 'when summaries are available' do
        before do
          stub_feature_flags(geo_job_artifact_verification_summaries: true)
        end

        let!(:clean_summary) do
          create(:geo_ci_job_artifact_verification_summary,
            state: :clean, bucket_number: 0, verified_count: 50, total_count: 100, failed_count: 5)
        end

        let!(:another_clean_summary) do
          create(:geo_ci_job_artifact_verification_summary,
            state: :clean, bucket_number: 1, verified_count: 30, total_count: 40, failed_count: 2)
        end

        it 'returns the sum of verified_count from summaries' do
          expect(described_class.checksummed_count).to eq(80)
        end
      end

      context 'when summaries are not available' do
        before do
          stub_feature_flags(geo_job_artifact_verification_summaries: false)
        end

        it 'falls back to batch_count' do
          expect(described_class).to receive(:batch_count).and_return(42)

          expect(described_class.checksummed_count).to eq(42)
        end
      end
    end

    describe '.checksum_failed_count' do
      context 'when summaries are available' do
        before do
          stub_feature_flags(geo_job_artifact_verification_summaries: true)
        end

        let!(:clean_summary) do
          create(:geo_ci_job_artifact_verification_summary,
            state: :clean, bucket_number: 0, failed_count: 5, total_count: 100, verified_count: 90)
        end

        let!(:another_clean_summary) do
          create(:geo_ci_job_artifact_verification_summary,
            state: :clean, bucket_number: 1, failed_count: 3, total_count: 50, verified_count: 40)
        end

        it 'returns the sum of failed_count from summaries' do
          expect(described_class.checksum_failed_count).to eq(8)
        end
      end

      context 'when summaries are not available' do
        before do
          stub_feature_flags(geo_job_artifact_verification_summaries: false)
        end

        it 'falls back to batch_count' do
          expect(described_class).to receive(:batch_count).and_return(3)

          expect(described_class.checksum_failed_count).to eq(3)
        end
      end
    end

    describe '.checksum_total_count' do
      context 'when summaries are available' do
        before do
          stub_feature_flags(geo_job_artifact_verification_summaries: true)
        end

        let!(:clean_summary) do
          create(:geo_ci_job_artifact_verification_summary,
            state: :clean, bucket_number: 0, total_count: 100, verified_count: 90, failed_count: 5)
        end

        let!(:another_clean_summary) do
          create(:geo_ci_job_artifact_verification_summary,
            state: :clean, bucket_number: 1, total_count: 50, verified_count: 40, failed_count: 3)
        end

        it 'returns the sum of total_count from summaries' do
          expect(described_class.checksum_total_count).to eq(150)
        end
      end

      context 'when summaries are not available' do
        before do
          stub_feature_flags(geo_job_artifact_verification_summaries: false)
        end

        it 'falls back to batch_count' do
          expect(described_class).to receive(:batch_count).and_return(200)

          expect(described_class.checksum_total_count).to eq(200)
        end
      end
    end
  end
end

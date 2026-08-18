# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::CiJobArtifactVerificationSummaryCalculatorService, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:verification_succeeded_value) do
    Geo::VerificationState::VERIFICATION_STATE_VALUES[:verification_succeeded]
  end

  let(:verification_failed_value) do
    Geo::VerificationState::VERIFICATION_STATE_VALUES[:verification_failed]
  end

  let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }

  before do
    stub_current_geo_node(primary_node)
  end

  describe '#execute' do
    context 'when Geo is not enabled' do
      before do
        allow(Gitlab::Geo).to receive(:enabled?).and_return(false)
      end

      it 'returns zero buckets calculated without processing' do
        result = described_class.new.execute

        expect(result[:buckets_calculated]).to eq(0)
      end

      it 'does not query the summaries table' do
        expect(Geo::CiJobArtifactVerificationSummary).not_to receive(:needs_recalculation)

        described_class.new.execute
      end
    end

    context 'when buckets are stuck in calculating state' do
      it 'picks up calculating buckets older than CALCULATING_TIMEOUT' do
        stuck_summary = create(
          :geo_ci_job_artifact_verification_summary,
          state: :calculating,
          bucket_number: 0,
          state_changed_at: 15.minutes.ago
        )

        described_class.new.execute

        expect(stuck_summary.reload.state).to eq('clean')
      end

      it 'does not pick up recently calculating buckets' do
        recent_summary = create(
          :geo_ci_job_artifact_verification_summary,
          state: :calculating,
          bucket_number: 0,
          state_changed_at: 5.minutes.ago
        )

        described_class.new.execute

        expect(recent_summary.reload.state).to eq('calculating')
      end
    end

    context 'when there are no dirty buckets' do
      it 'returns zero buckets calculated' do
        result = described_class.new.execute

        expect(result[:buckets_calculated]).to eq(0)
      end
    end

    context 'when there are dirty buckets' do
      let!(:artifact_pending) { create(:ci_job_artifact) }

      let!(:artifact_succeeded) do
        create(:ci_job_artifact).tap do |artifact|
          artifact.job_artifact_state.update_column(:verification_state, verification_succeeded_value)
        end
      end

      let!(:artifact_failed) do
        create(:ci_job_artifact).tap do |artifact|
          artifact.job_artifact_state.update_column(:verification_state, verification_failed_value)
        end
      end

      let!(:dirty_summaries) do
        bucket_count = Geo::CiJobArtifactVerificationSummary::BUCKET_COUNT

        [artifact_pending, artifact_succeeded, artifact_failed]
          .map { |artifact| artifact.id % bucket_count }
          .uniq
          .map do |bucket_number|
          Geo::CiJobArtifactVerificationSummary
            .find_or_initialize_by(bucket_number: bucket_number)
            .tap { |s| s.update!(state: :dirty, state_changed_at: Time.current) }
        end
      end

      it 'recalculates counts for dirty buckets' do
        described_class.new.execute

        bucket_count = Geo::CiJobArtifactVerificationSummary::BUCKET_COUNT
        bucket_number = artifact_pending.id % bucket_count
        summary = Geo::CiJobArtifactVerificationSummary.find_by!(bucket_number: bucket_number)
        expect(summary.total_count).to be >= 1
      end

      it 'counts verified and failed states correctly' do
        described_class.new.execute

        total_verified = Geo::CiJobArtifactVerificationSummary.sum(:verified_count)
        total_failed = Geo::CiJobArtifactVerificationSummary.sum(:failed_count)
        expect(total_verified).to eq(1)
        expect(total_failed).to eq(1)
      end

      it 'transitions dirty buckets to clean' do
        described_class.new.execute

        expect(Geo::CiJobArtifactVerificationSummary.dirty.count).to eq(0)
        expect(Geo::CiJobArtifactVerificationSummary.where(state: :clean).count).to eq(dirty_summaries.size)
      end

      it 'sets last_calculated_at' do
        freeze_time do
          described_class.new.execute

          dirty_summaries.each do |summary|
            expect(summary.reload.last_calculated_at).to eq(Time.current)
          end
        end
      end

      it 'returns the number of buckets calculated' do
        result = described_class.new.execute

        expect(result[:buckets_calculated]).to eq(dirty_summaries.size)
      end

      it 'does not recalculate clean buckets' do
        clean_summary = create(
          :geo_ci_job_artifact_verification_summary,
          state: :clean,
          bucket_number: 99_999,
          total_count: 999
        )

        described_class.new.execute

        expect(clean_summary.reload.total_count).to eq(999)
      end

      it 'writes zero counts for a dirty bucket with no matching artifacts', :aggregate_failures do
        empty_bucket = create(:geo_ci_job_artifact_verification_summary, :dirty, bucket_number: 99_998)

        described_class.new.execute

        empty_bucket.reload
        expect(empty_bucket.state).to eq('clean')
        expect(empty_bucket.total_count).to eq(0)
        expect(empty_bucket.verified_count).to eq(0)
        expect(empty_bucket.failed_count).to eq(0)
      end
    end

    context 'when more dirty buckets exist than DIRTY_BUCKET_LIMIT' do
      it 'processes at most DIRTY_BUCKET_LIMIT buckets per call' do
        limit = described_class::DIRTY_BUCKET_LIMIT

        (0...(limit + 50)).each do |i|
          create(:geo_ci_job_artifact_verification_summary, :dirty, bucket_number: i)
        end

        result = described_class.new.execute

        expect(result[:buckets_calculated]).to eq(limit)
      end
    end

    context 'when claiming buckets atomically' do
      it 'transitions dirty buckets to calculating before counting' do
        dirty_summary = create(:geo_ci_job_artifact_verification_summary, :dirty, bucket_number: 0)

        service = described_class.new
        allow(service).to receive(:count_dirty_buckets) do
          expect(dirty_summary.reload.state).to eq('calculating')
        end
        allow(service).to receive(:update_summary_counts)

        service.execute
      end
    end

    context 'when a bucket is re-dirtied during calculation' do
      let!(:dirty_summary) { create(:geo_ci_job_artifact_verification_summary, :dirty, bucket_number: 0) }

      it 'does not overwrite the dirty state with clean', :aggregate_failures do
        service = described_class.new

        allow(service).to receive(:count_dirty_buckets).and_wrap_original do |method|
          method.call
          dirty_summary.update_column(:state, Geo::CiJobArtifactVerificationSummary.states[:dirty])
        end

        service.execute

        dirty_summary.reload
        expect(dirty_summary.state).to eq('dirty')
        expect(dirty_summary.total_count).to eq(0)
      end
    end

    context 'with artifacts spanning multiple buckets', :aggregate_failures do
      let(:bucket_count) { Geo::CiJobArtifactVerificationSummary::BUCKET_COUNT }

      let!(:pending_artifact) { create(:ci_job_artifact) }

      let!(:succeeded_artifact) do
        create(:ci_job_artifact).tap do |artifact|
          artifact.job_artifact_state.update_column(:verification_state, verification_succeeded_value)
        end
      end

      let!(:failed_artifact) do
        create(:ci_job_artifact).tap do |artifact|
          artifact.job_artifact_state.update_column(:verification_state, verification_failed_value)
        end
      end

      let(:bucket_pending) { pending_artifact.id % bucket_count }
      let(:bucket_succeeded) { succeeded_artifact.id % bucket_count }
      let(:bucket_failed) { failed_artifact.id % bucket_count }

      before do
        [bucket_pending, bucket_succeeded, bucket_failed].uniq.each do |bucket_number|
          Geo::CiJobArtifactVerificationSummary
            .find_or_initialize_by(bucket_number: bucket_number)
            .tap { |s| s.update!(state: :dirty, state_changed_at: Time.current) }
        end

        described_class.new.execute
      end

      it 'transitions all dirty buckets to clean' do
        expect(Geo::CiJobArtifactVerificationSummary.dirty.count).to eq(0)
      end

      it 'counts each bucket independently' do
        summary = Geo::CiJobArtifactVerificationSummary.find_by!(bucket_number: bucket_pending)

        expect(summary.total_count).to eq(1)
        expect(summary.verified_count).to eq(0)
        expect(summary.failed_count).to eq(0)
      end

      it 'aggregates totals correctly across all buckets' do
        expect(Geo::CiJobArtifactVerificationSummary.sum(:total_count)).to eq(3)
        expect(Geo::CiJobArtifactVerificationSummary.sum(:verified_count)).to eq(1)
        expect(Geo::CiJobArtifactVerificationSummary.sum(:failed_count)).to eq(1)
      end
    end
  end
end

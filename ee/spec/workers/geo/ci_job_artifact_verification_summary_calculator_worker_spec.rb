# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::CiJobArtifactVerificationSummaryCalculatorWorker, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:primary_node) { create(:geo_node, :primary) }

  before do
    stub_current_geo_node(primary_node)
  end

  it 'uses until_executed deduplication strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#perform' do
    context 'when Geo is not enabled' do
      before do
        allow(Gitlab::Geo).to receive(:enabled?).and_return(false)
      end

      it 'does not execute the calculator service' do
        expect(Geo::CiJobArtifactVerificationSummaryCalculatorService).not_to receive(:new)

        described_class.new.perform
      end
    end

    context 'when the site is a Geo secondary' do
      before do
        stub_current_geo_node(create(:geo_node))
      end

      it 'does not execute the calculator service' do
        expect(Geo::CiJobArtifactVerificationSummaryCalculatorService).not_to receive(:new)

        described_class.new.perform
      end
    end

    context 'when the site is an org migration target' do
      before do
        stub_org_migration_target_cell
      end

      it 'does not execute the calculator service' do
        expect(Geo::CiJobArtifactVerificationSummaryCalculatorService).not_to receive(:new)

        described_class.new.perform
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(geo_job_artifact_verification_summaries: false)
      end

      it 'does not execute the calculator service' do
        expect(Geo::CiJobArtifactVerificationSummaryCalculatorService).not_to receive(:new)

        described_class.new.perform
      end
    end

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(geo_job_artifact_verification_summaries: true)
      end

      it 'executes the calculator service' do
        service = instance_double(Geo::CiJobArtifactVerificationSummaryCalculatorService)
        allow(Geo::CiJobArtifactVerificationSummaryCalculatorService).to receive(:new).and_return(service)
        allow(service).to receive(:execute).and_return({ buckets_calculated: 0 })

        described_class.new.perform

        expect(service).to have_received(:execute).at_least(1).time
      end

      it 'loops until fewer than a full batch is processed' do
        service = instance_double(Geo::CiJobArtifactVerificationSummaryCalculatorService)
        allow(Geo::CiJobArtifactVerificationSummaryCalculatorService).to receive(:new).and_return(service)
        dirty_bucket_limit = Geo::CiJobArtifactVerificationSummaryCalculatorService::DIRTY_BUCKET_LIMIT
        allow(service).to receive(:execute).and_return(
          { buckets_calculated: dirty_bucket_limit },
          { buckets_calculated: dirty_bucket_limit },
          { buckets_calculated: 5 }
        )

        described_class.new.perform

        expect(service).to have_received(:execute).exactly(3).times
      end

      it 'stops looping after MAX_RUNTIME' do
        service = instance_double(Geo::CiJobArtifactVerificationSummaryCalculatorService)
        allow(Geo::CiJobArtifactVerificationSummaryCalculatorService).to receive(:new).and_return(service)
        dirty_bucket_limit = Geo::CiJobArtifactVerificationSummaryCalculatorService::DIRTY_BUCKET_LIMIT
        allow(service).to receive(:execute).and_return({ buckets_calculated: dirty_bucket_limit })

        runtime_limiter = instance_double(Gitlab::Metrics::RuntimeLimiter)
        allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new).and_return(runtime_limiter)
        allow(runtime_limiter).to receive(:over_time?).and_return(false, true)

        described_class.new.perform

        expect(service).to have_received(:execute).exactly(2).times
      end

      include_examples 'an idempotent worker'
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::VerificationStateBackfillWorker, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers
  include ExclusiveLeaseHelpers

  subject(:job) { described_class.new }

  let(:job_args) { 'MergeRequestDiff' }
  let(:replication_feature_flag) { :geo_merge_request_diff_replication }
  let(:force_primary_checksumming_feature_flag) { :geo_merge_request_diff_force_primary_checksumming }

  let_it_be(:primary) { create(:geo_node, :primary) }

  before do
    stub_current_geo_node(primary)
  end

  it 'uses a geo queue' do
    expect(subject.sidekiq_options_hash).to include(
      'queue_namespace' => :geo
    )
  end

  describe '#perform' do
    it_behaves_like 'reenqueuer'
    it_behaves_like '#perform is rate limited to 1 call per', 5.seconds

    context 'when replication feature flag is enabled' do
      before do
        stub_feature_flags(replication_feature_flag => true)

        expect_next_instance_of(Geo::VerificationStateBackfillService) do |service|
          expect(service).to receive(:execute).and_return(true)
        end
      end

      context 'when force primary checksumming feature flag is enabled' do
        before do
          stub_feature_flags(force_primary_checksumming_feature_flag => true)
        end

        it 'returns true' do
          expect(subject.perform(job_args)).to be_truthy
        end

        it 'worker gets reenqueued' do
          expect(described_class).to receive(:perform_async)

          subject.perform(job_args)
        end
      end

      context 'when force primary checksumming feature flag is disabled' do
        before do
          stub_feature_flags(force_primary_checksumming_feature_flag => false)
        end

        it 'returns true' do
          expect(subject.perform(job_args)).to be_truthy
        end

        it 'worker gets reenqueued' do
          expect(described_class).to receive(:perform_async)

          subject.perform(job_args)
        end
      end
    end

    context 'when replication feature flag is disabled' do
      before do
        stub_feature_flags(replication_feature_flag => false)
      end

      context 'when force primary checksumming feature flag is enabled' do
        before do
          stub_feature_flags(force_primary_checksumming_feature_flag => true)

          expect_next_instance_of(Geo::VerificationStateBackfillService) do |service|
            expect(service).to receive(:execute).and_return(true)
          end
        end

        it 'returns true' do
          expect(subject.perform(job_args)).to be_truthy
        end

        it 'worker gets reenqueued' do
          expect(described_class).to receive(:perform_async)

          subject.perform(job_args)
        end
      end

      context 'when force primary checksumming feature flag is disabled' do
        before do
          stub_feature_flags(force_primary_checksumming_feature_flag => false)

          expect(Geo::VerificationStateBackfillService).not_to receive(:new)
        end

        it 'returns false' do
          expect(subject.perform(job_args)).to be_falsey
        end

        it 'worker does not get reenqueued (we will wait until next cronjob)' do
          expect(described_class).not_to receive(:perform_async)

          subject.perform(job_args)
        end
      end
    end

    context 'when service is executed' do
      before do
        expect_next_instance_of(Geo::VerificationStateBackfillService) do |service|
          expect(service).to receive(:execute).and_return(execute_return)
        end
      end

      context 'when Geo::VerificationStateBackfillService#execute returns true' do
        let(:execute_return) { true }

        it 'returns true' do
          expect(subject.perform(job_args)).to be_truthy
        end

        it 'worker gets reenqueued' do
          expect(described_class).to receive(:perform_async)

          subject.perform(job_args)
        end
      end

      context 'when Geo::VerificationStateBackfillService#execute returns false' do
        let(:execute_return) { false }

        it 'returns false' do
          expect(subject.perform(job_args)).to be_falsey
        end

        it 'worker does not get reenqueued (we will wait until next cronjob)' do
          expect(described_class).not_to receive(:perform_async)

          subject.perform(job_args)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::StageAggregatorService, feature_category: :value_stream_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group, organization_id: root_group.organization_id) }
  let_it_be(:project) { create(:project, namespace: subgroup) }
  let(:stage) { create(:cycle_analytics_stage, namespace: subgroup) }
  let!(:aggregation) { stage.stage_aggregation }

  def run_service
    described_class.new(aggregation: aggregation).execute
  end

  context 'when the group is not licensed' do
    it 'sets the aggregation record disabled' do
      expect { run_service }.to change { aggregation.reload.enabled }.from(true).to(false)
    end

    it 'doesnt call the DataLoaderService' do
      expect(Analytics::CycleAnalytics::DataLoaderService).not_to receive(:new)

      run_service
    end
  end

  context 'when the aggregation succeeds' do
    before do
      stub_licensed_features(cycle_analytics_for_groups: true)
    end

    context 'when nothing to aggregate' do
      it 'updates the aggregation record with metadata' do
        freeze_time do
          run_service

          expect(aggregation.reload).to have_attributes(
            runtimes_in_seconds: satisfy(&:one?),
            processed_records: [0],
            last_run_at: Time.current,
            last_merge_requests_updated_at: nil,
            last_merge_requests_id: nil,
            last_issues_updated_at: nil,
            last_issues_id: nil
          )
        end
      end

      context 'when the aggregation already contains metadata about the previous runs' do
        before do
          # we store data for the last 10 runs
          aggregation.update!(
            processed_records: Array.new(10, 1000),
            runtimes_in_seconds: Array.new(10, 100)
          )
        end

        it 'updates the statistical columns' do
          run_service

          aggregation.reload

          expect(aggregation.processed_records.length).to eq(10)
          expect(aggregation.runtimes_in_seconds.length).to eq(10)
          expect(aggregation.processed_records[-1]).to eq(0)
        end
      end
    end

    context 'when merge requests and issues are present for the configured VSA stages' do
      let!(:merge_request) { create(:merge_request, :with_merged_metrics, project: project) }

      let!(:stage) do
        create(:cycle_analytics_stage, namespace: subgroup,
          start_event_identifier: :merge_request_created,
          end_event_identifier: :merge_request_merged)
      end

      it 'updates the aggregation record with record count and the last cursor' do
        run_service

        expect(aggregation.reload).to have_attributes(
          processed_records: [1],
          last_merge_requests_updated_at: be_within(5.seconds).of(merge_request.updated_at),
          last_merge_requests_id: merge_request.id,
          last_issues_updated_at: nil,
          last_issues_id: nil
        )
      end
    end

    context 'when running with plenty of data for aggregation' do
      let!(:merge_request_1) { create(:merge_request, :with_merged_metrics, :unique_branches, project: project) }
      let!(:merge_request_2) { create(:merge_request, :with_merged_metrics, :unique_branches, project: project) }
      let!(:stage) do
        create(:cycle_analytics_stage, namespace: subgroup,
          start_event_identifier: :merge_request_created,
          end_event_identifier: :merge_request_merged)
      end

      before do
        stub_const('Analytics::CycleAnalytics::DataLoaderService::MAX_UPSERT_COUNT', 1)
        stub_const('Analytics::CycleAnalytics::DataLoaderService::UPSERT_LIMIT', 1)
        stub_const('Analytics::CycleAnalytics::DataLoaderService::BATCH_LIMIT', 1)
      end

      context 'when aggregation is not finished' do
        it 'persists the cursor attributes' do
          run_service

          expect(aggregation.reload).to have_attributes(
            processed_records: [1],
            last_merge_requests_updated_at: be_within(5.seconds).of(merge_request_1.updated_at),
            last_merge_requests_id: merge_request_1.id,
            last_issues_updated_at: nil,
            last_issues_id: nil
          )
        end
      end

      context 'when aggregation is finished during the second run' do
        it 'marks aggregation as completed' do
          3.times { run_service }

          expect(aggregation.reload).to have_attributes(
            processed_records: [1, 1, 0],
            last_completed_at: be_within(5.seconds).of(merge_request_2.updated_at)
          )
        end
      end
    end
  end
end

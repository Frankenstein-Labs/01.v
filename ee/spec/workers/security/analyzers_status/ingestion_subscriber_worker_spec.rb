# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::IngestionSubscriberWorker, feature_category: :security_asset_inventories do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:pipeline) { create(:ci_empty_pipeline, project: project, ref: project.default_branch) }

  let(:event) { ::Security::ReportsIngestedEvent.new(data: { pipeline_id: pipeline.id }) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'subscribes to event'
  it_behaves_like 'an idempotent worker'

  describe '#handle_event' do
    subject(:use_event) { consume_event(subscriber: described_class, event: event) }

    context 'when the pipeline exists' do
      it 'enqueues PipelineAnalyzersStatusUpdateWorker with the pipeline id' do
        expect(::Security::PipelineAnalyzersStatusUpdateWorker).to receive(:perform_async).with(pipeline.id)

        use_event
      end

      context 'when the pipeline is not on the default branch' do
        let_it_be(:feature_branch_pipeline) { create(:ci_pipeline, project: project, ref: 'feature') }
        let(:event) { ::Security::ReportsIngestedEvent.new(data: { pipeline_id: feature_branch_pipeline.id }) }

        it 'does not enqueue PipelineAnalyzersStatusUpdateWorker' do
          expect(::Security::PipelineAnalyzersStatusUpdateWorker).not_to receive(:perform_async)

          use_event
        end
      end
    end

    context 'when the pipeline does not exist' do
      let(:event) { ::Security::ReportsIngestedEvent.new(data: { pipeline_id: non_existing_record_id }) }

      it 'does not enqueue PipelineAnalyzersStatusUpdateWorker' do
        expect(::Security::PipelineAnalyzersStatusUpdateWorker).not_to receive(:perform_async)

        use_event
      end
    end
  end
end

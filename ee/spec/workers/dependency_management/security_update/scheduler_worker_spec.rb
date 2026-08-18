# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::SchedulerWorker,
  feature_category: :dependency_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }

  let(:event) { Sbom::SbomIngestedEvent.new(data: { pipeline_id: pipeline.id }) }

  subject(:handle_event) { consume_event(subscriber: described_class, event: event) }

  it_behaves_like 'subscribes to event'
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe 'concurrency limit' do
    it 'reads the limit from application settings' do
      allow(Gitlab::CurrentSettings)
        .to receive(:security_update_scheduler_max_concurrency).and_return(50)

      expect(described_class.get_concurrency_limit).to eq(50)
    end

    it 'caps the limit at MAX_SCHEDULER_WORKER_LIMIT' do
      allow(Gitlab::CurrentSettings)
        .to receive(:security_update_scheduler_max_concurrency)
        .and_return(described_class::MAX_SCHEDULER_WORKER_LIMIT + 100)

      expect(described_class.get_concurrency_limit).to eq(described_class::MAX_SCHEDULER_WORKER_LIMIT)
    end
  end

  describe '#handle_event' do
    before do
      allow(DependencyManagement::SecurityUpdate::SchedulerService).to receive(:execute)
    end

    context 'when the pipeline exists' do
      it 'calls SchedulerService with the pipeline project' do
        handle_event

        expect(DependencyManagement::SecurityUpdate::SchedulerService)
          .to have_received(:execute).with(project: pipeline.project).once
      end
    end

    context 'when the pipeline does not exist' do
      let(:event) { Sbom::SbomIngestedEvent.new(data: { pipeline_id: non_existing_record_id }) }

      it 'does not call SchedulerService' do
        handle_event

        expect(DependencyManagement::SecurityUpdate::SchedulerService).not_to have_received(:execute)
      end
    end
  end
end

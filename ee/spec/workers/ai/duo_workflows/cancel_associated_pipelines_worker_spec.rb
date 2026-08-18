# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CancelAssociatedPipelinesWorker, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [workflow.id, user.id] }

    before do
      allow_next_found_instance_of(Ai::DuoWorkflows::Workflow) do |w|
        allow(w).to receive(:associated_pipelines).and_return([])
      end
    end
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform(workflow.id, user.id) }

    context 'when workflow does not exist' do
      it 'returns early' do
        expect(::Ci::CancelPipelineService).not_to receive(:new)

        described_class.new.perform(non_existing_record_id, user.id)
      end
    end

    context 'when user does not exist' do
      it 'returns early' do
        expect(::Ci::CancelPipelineService).not_to receive(:new)

        described_class.new.perform(workflow.id, non_existing_record_id)
      end
    end

    context 'when workflow has no associated pipelines' do
      before do
        allow(workflow).to receive(:associated_pipelines).and_return([])
      end

      it 'does not cancel any pipelines' do
        expect(::Ci::CancelPipelineService).not_to receive(:new)

        perform
      end
    end

    context 'when workflow has associated pipelines' do
      let(:pipeline1) { create(:ci_pipeline, project: project) }
      let(:pipeline2) { create(:ci_pipeline, project: project) }

      before do
        allow_next_found_instance_of(Ai::DuoWorkflows::Workflow) do |w|
          allow(w).to receive(:associated_pipelines).and_return([pipeline1, pipeline2])
        end
      end

      it 'cancels all cancelable pipelines' do
        allow(pipeline1).to receive(:cancelable?).and_return(true)
        allow(pipeline2).to receive(:cancelable?).and_return(true)

        allow(::Ci::CancelPipelineService).to receive(:new).and_wrap_original do |method, **kwargs|
          service = method.call(**kwargs)
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
          service
        end

        perform

        expect(::Ci::CancelPipelineService).to have_received(:new).twice
      end

      it 'skips non-cancelable pipelines' do
        allow(pipeline1).to receive(:cancelable?).and_return(false)
        allow(pipeline2).to receive(:cancelable?).and_return(true)

        service_double = instance_double(::Ci::CancelPipelineService)
        allow(service_double).to receive(:execute).and_return(ServiceResponse.success)
        allow(::Ci::CancelPipelineService).to receive(:new).and_return(service_double)

        perform

        expect(::Ci::CancelPipelineService).to have_received(:new).once
      end

      it 'logs errors when pipeline cancellation fails' do
        allow(pipeline1).to receive(:cancelable?).and_return(true)
        allow(pipeline2).to receive(:cancelable?).and_return(false)

        service_double = instance_double(::Ci::CancelPipelineService)
        allow(service_double).to receive(:execute).and_return(
          ServiceResponse.error(message: "Failed to cancel pipeline")
        )
        allow(::Ci::CancelPipelineService).to receive(:new).and_return(service_double)

        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          instance_of(StandardError),
          hash_including(
            workflow_id: workflow.id,
            pipeline_id: pipeline1.id,
            message: "Failed to cancel pipeline"
          )
        )

        perform
      end
    end

    context 'when other workflows have their own pipelines' do
      let_it_be(:pipeline1) { create(:ci_pipeline, project: project) }
      let_it_be(:pipeline2) { create(:ci_pipeline, project: project) }
      let_it_be(:pipeline3) { create(:ci_pipeline, project: project) }
      let_it_be(:pipeline4) { create(:ci_pipeline, project: project) }
      let_it_be(:workload1) { create(:ci_workload, pipeline: pipeline1, project: project) }
      let_it_be(:workload2) { create(:ci_workload, pipeline: pipeline2, project: project) }
      let_it_be(:workload3) { create(:ci_workload, pipeline: pipeline3, project: project) }
      let_it_be(:workload4) { create(:ci_workload, pipeline: pipeline4, project: project) }
      let_it_be(:other_workflow) { create(:duo_workflows_workflow, project: project, user: user) }

      it 'only cancels pipelines associated with the specific workflow' do
        create(:duo_workflows_workload, workflow: workflow, workload: workload1)
        create(:duo_workflows_workload, workflow: workflow, workload: workload2)
        # workload3 is associated with a different workflow (pipeline3 should not be selected)
        create(:duo_workflows_workload, workflow: other_workflow, workload: workload3)
        # workload4 is associated with a different workflow (pipeline4 should not be selected)
        create(:duo_workflows_workload, workflow: other_workflow, workload: workload4)
        # a pipeline with no workload at all (should not be selected)
        create(:ci_pipeline, project: project)

        cancelled_pipeline_ids = []
        allow(::Ci::CancelPipelineService).to receive(:new).and_wrap_original do |method, **kwargs|
          cancelled_pipeline_ids << kwargs[:pipeline].id
          service = method.call(**kwargs)
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
          service
        end

        perform

        expect(cancelled_pipeline_ids).to contain_exactly(pipeline1.id, pipeline2.id)
      end
    end
  end
end

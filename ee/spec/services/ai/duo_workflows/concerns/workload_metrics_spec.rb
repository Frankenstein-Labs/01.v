# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Concerns::WorkloadMetrics, feature_category: :duo_agent_platform do
  let(:test_class) do
    Class.new do
      include Ai::DuoWorkflows::Concerns::WorkloadMetrics

      public :track_workload_completion_metrics
    end
  end

  let(:instance) { test_class.new }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  describe '#track_workload_completion_metrics' do
    let(:pipeline) { create(:ci_pipeline, project: project, user: user, source: :duo_workflow) }
    let!(:build) do
      create(:ci_build, pipeline: pipeline, project: project, user: user).tap do |b|
        b.update_columns(
          queued_at: 2.minutes.ago,
          started_at: 1.minute.ago,
          finished_at: Time.current
        )
      end
    end

    let(:workload) { create(:ci_workload, pipeline: pipeline, project: project) }

    let(:workflow) do
      create(:duo_workflows_workflow,
        project: project,
        user: user,
        workflow_definition: workflow_definition,
        status: 1
      )
    end

    let(:workflow_definition) { 'fix_pipeline/v1' }

    context 'when workflow has a workload with a pipeline' do
      before do
        create(:duo_workflows_workload, workflow: workflow, workload: workload, project: project)
        pipeline.update_columns(duration: 180, status: 'success')
      end

      it 'emits the duo_workflow_workload_completed internal event', :freeze_time do
        expect(instance).to receive(:track_internal_event).with(
          'duo_workflow_workload_completed',
          user: workflow.user,
          project: workflow.project,
          additional_properties: hash_including(
            label: 'success',
            value: 180,
            workflow_id: workflow.id.to_s,
            workflow_definition: 'fix_pipeline/v1'
          )
        )

        instance.track_workload_completion_metrics(workflow, pipeline: pipeline, build: build)
      end

      it 'logs a structured message with pipeline and timing data' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'duo_workflow_workload_completed',
            pipeline_id: pipeline.id,
            pipeline_status: 'success',
            workflow_id: workflow.id,
            workflow_definition: 'fix_pipeline/v1',
            project_id: project.id
          )
        )

        instance.track_workload_completion_metrics(workflow, pipeline: pipeline, build: build)
      end

      context 'with a different workflow definition' do
        let(:workflow_definition) { 'software_development' }

        it 'still emits the event with the workflow_definition in the log' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'duo_workflow_workload_completed',
              workflow_definition: 'software_development'
            )
          )

          instance.track_workload_completion_metrics(workflow, pipeline: pipeline, build: build)
        end
      end

      context 'when pipeline has failed' do
        before do
          pipeline.update_columns(status: 'failed')
          build.update_columns(status: 'failed', failure_reason: 3)
        end

        it 'includes failure_reason in both the event and log' do
          expect(instance).to receive(:track_internal_event).with(
            'duo_workflow_workload_completed',
            user: workflow.user,
            project: workflow.project,
            additional_properties: hash_including(
              label: 'failed',
              property: 'stuck_or_timeout_failure'
            )
          )

          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              pipeline_status: 'failed',
              failure_reason: 'stuck_or_timeout_failure'
            )
          )

          instance.track_workload_completion_metrics(workflow, pipeline: pipeline, build: build)
        end
      end
    end

    context 'when pipeline is nil' do
      it 'does not emit any event or log' do
        expect(instance).not_to receive(:track_internal_event)
        expect(Gitlab::AppLogger).not_to receive(:info)

        instance.track_workload_completion_metrics(workflow, pipeline: nil, build: nil)
      end
    end
  end
end

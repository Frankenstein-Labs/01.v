# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::CancelPolicyPipelinesService,
  feature_category: :security_policy_management do
  let_it_be(:security_bot) { create(:user, :security_policy_bot) }
  let_it_be(:project) { create(:project, guests: security_bot) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

  let(:service) do
    described_class.new(
      security_policy: security_policy,
      project: project
    )
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(cancel_pipelines_when_policy_disabled: false)
      end

      it 'does not process pipelines' do
        expect(Security::PolicySchedulePipeline).not_to receive(:for_policy)

        execute
      end
    end

    context 'when policy is linked to a project instead of a namespace' do
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project, namespace: nil)
      end

      let_it_be(:project_security_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let_it_be(:running_pipeline) { create(:ci_pipeline, :running, project: project) }

      let_it_be(:running_policy_pipeline) do
        create(:security_policy_schedule_pipeline,
          security_policy: project_security_policy,
          pipeline: running_pipeline,
          project: project)
      end

      let(:service) do
        described_class.new(
          security_policy: project_security_policy,
          project: project
        )
      end

      it 'cancels pipelines when feature flag is enabled for project namespace' do
        stub_feature_flags(cancel_pipelines_when_policy_disabled: project.namespace)

        expect(Ci::CancelPipelineService).to receive(:new)
          .with(hash_including(pipeline: running_pipeline))
          .and_call_original

        execute
      end

      it 'does not cancel pipelines when feature flag is disabled for project namespace' do
        stub_feature_flags(cancel_pipelines_when_policy_disabled: false)

        expect(Ci::CancelPipelineService).not_to receive(:new)

        execute
      end
    end

    context 'when there are no policy schedule pipelines' do
      it 'does not call cancel service' do
        expect(Ci::CancelPipelineService).not_to receive(:new)

        execute
      end
    end

    context 'when there are policy schedule pipelines' do
      let_it_be(:running_pipeline) { create(:ci_pipeline, :running, project: project) }
      let_it_be(:pending_pipeline) { create(:ci_pipeline, :pending, project: project) }
      let_it_be(:success_pipeline) { create(:ci_pipeline, :success, project: project) }
      let_it_be(:other_running_pipeline) { create(:ci_pipeline, :running, project: other_project) }

      let_it_be(:running_policy_pipeline) do
        create(:security_policy_schedule_pipeline,
          security_policy: security_policy,
          pipeline: running_pipeline,
          project: project)
      end

      let_it_be(:pending_policy_pipeline) do
        create(:security_policy_schedule_pipeline,
          security_policy: security_policy,
          pipeline: pending_pipeline,
          project: project)
      end

      let_it_be(:success_policy_pipeline) do
        create(:security_policy_schedule_pipeline,
          security_policy: security_policy,
          pipeline: success_pipeline,
          project: project)
      end

      let_it_be(:other_running_policy_pipeline) do
        create(:security_policy_schedule_pipeline,
          security_policy: security_policy,
          pipeline: other_running_pipeline,
          project: other_project)
      end

      it 'only cancels cancelable pipelines for the specified project' do
        expect(Ci::CancelPipelineService).to receive(:new)
          .with(hash_including(pipeline: running_pipeline))
          .and_call_original
        expect(Ci::CancelPipelineService).to receive(:new)
          .with(hash_including(pipeline: pending_pipeline))
          .and_call_original
        expect(Ci::CancelPipelineService).not_to receive(:new)
          .with(hash_including(pipeline: other_running_pipeline))

        execute
      end

      it 'does not cancel pipelines that are already completed' do
        cancel_service = instance_double(Ci::CancelPipelineService)
        allow(cancel_service).to receive(:force_execute).and_return(ServiceResponse.success)
        allow(Ci::CancelPipelineService).to receive(:new).and_return(cancel_service)

        expect(Ci::CancelPipelineService).not_to receive(:new)
          .with(hash_including(pipeline: success_pipeline))

        execute
      end

      context 'when the project does not have a security policy bot' do
        before do
          allow(project).to receive(:security_policy_bot).and_return(nil)
        end

        it 'does not cancel pipelines' do
          expect(Ci::CancelPipelineService).not_to receive(:new)

          execute
        end
      end

      context 'when pipeline cancellation fails for one pipeline' do
        before do
          allow_next_instance_of(Ci::CancelPipelineService) do |service|
            allow(service).to receive(:force_execute).and_raise(StandardError, 'Something went wrong')
          end
        end

        it 'continues cancelling other pipelines and tracks the exception' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).at_least(:once)

          execute
        end
      end
    end
  end
end

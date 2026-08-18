# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::TestRunService, '#execute', feature_category: :security_policy_management do
  shared_examples 'does not enqueue the worker' do
    it 'does not enqueue the worker' do
      expect(Security::PipelineExecutionSchedulePolicies::CreateTestRunPipelineWorker)
        .not_to receive(:perform_async)

      execute
    end
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:policy_management_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policy_management_project)
  end

  let_it_be(:policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      security_orchestration_policy_configuration: policy_configuration,
      security_policy_management_project: policy_management_project)
  end

  let(:service) { described_class.new(policy: policy, project: project, user: user) }

  subject(:execute) { service.execute }

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow(policy).to receive(:scope_applicable?).with(project).and_return(true)
  end

  context 'when user can commit to security policy project' do
    before do
      policy.security_policy_management_project.add_developer(user)
      allow(Security::PipelineExecutionSchedulePolicies::CreateTestRunPipelineWorker)
        .to receive(:perform_async)
    end

    it 'creates a test run in pending state', :aggregate_failures do
      expect { execute }
        .to change { Security::ScheduledPipelineExecutionPolicyTestRun.count }.by(1)
      expect(execute).to be_success
      expect(execute.payload[:test_run]).to be_pending
    end

    it 'enqueues the worker with the test run ID' do
      result = execute
      test_run = result.payload[:test_run]

      expect(Security::PipelineExecutionSchedulePolicies::CreateTestRunPipelineWorker)
        .to have_received(:perform_async).with(test_run.id)
    end

    it 'does not include pipeline in the response payload' do
      expect(execute.payload).not_to have_key(:pipeline)
    end

    it 'does not call CreateScheduledPipelineService synchronously' do
      expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

      execute
    end

    context 'when policy is not a pipeline execution schedule policy' do
      let_it_be(:policy) do
        create(:security_policy, :pipeline_execution_policy,
          security_orchestration_policy_configuration: policy_configuration,
          security_policy_management_project: policy_management_project)
      end

      it 'returns an error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.message).to eq('Policy must be a pipeline_execution_schedule_policy')
      end

      it_behaves_like 'does not enqueue the worker'
    end

    context 'when project is not in policy scope' do
      before do
        allow(policy).to receive(:scope_applicable?).with(project).and_return(false)
      end

      it 'returns an error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.message).to eq('Project is not in policy scope')
      end

      it_behaves_like 'does not enqueue the worker'
    end

    context 'when test run creation fails' do
      let(:errors) { instance_double(ActiveModel::Errors, full_messages: ['Validation error']) }

      before do
        allow(Security::ScheduledPipelineExecutionPolicyTestRun).to receive(:create).and_return(
          instance_double(Security::ScheduledPipelineExecutionPolicyTestRun, persisted?: false, errors: errors)
        )
      end

      it 'returns an error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.message).to eq('Validation error')
      end

      it_behaves_like 'does not enqueue the worker'
    end

    # Integration test: verify the async pipeline creation flow
    # The worker handles pipeline creation and failure - see create_test_run_pipeline_worker_spec.rb
    describe 'async pipeline creation flow' do
      let(:pipeline) { create(:ci_pipeline, project: project) }

      it 'creates a pending test run that can be processed by the worker' do
        result = execute
        test_run = result.payload[:test_run]

        expect(test_run).to be_pending
        expect(test_run.pipeline).to be_nil

        # Simulate worker processing
        allow(Security::PipelineExecutionPolicies::CreateScheduledPipelineService)
          .to receive(:new).and_return(
            instance_double(
              Security::PipelineExecutionPolicies::CreateScheduledPipelineService,
              execute: ServiceResponse.success(payload: pipeline)
            )
          )

        Security::PipelineExecutionSchedulePolicies::CreateTestRunPipelineWorker.new.perform(test_run.id)

        test_run.reload
        expect(test_run).to be_running
        expect(test_run.pipeline).to eq(pipeline)
      end

      it 'handles pipeline creation failure in worker' do
        result = execute
        test_run = result.payload[:test_run]

        # Simulate worker processing with failure
        allow(Security::PipelineExecutionPolicies::CreateScheduledPipelineService)
          .to receive(:new).and_return(
            instance_double(
              Security::PipelineExecutionPolicies::CreateScheduledPipelineService,
              execute: ServiceResponse.error(message: 'Pipeline error')
            )
          )

        Security::PipelineExecutionSchedulePolicies::CreateTestRunPipelineWorker.new.perform(test_run.id)

        test_run.reload
        expect(test_run).to be_failed
        expect(test_run.error_message).to eq('Pipeline error')
      end
    end
  end

  context 'when user cannot commit to security policy project' do
    before do
      policy.security_policy_management_project.add_guest(user)
    end

    it 'returns an error', :aggregate_failures do
      expect(execute).to be_error
      expect(execute.message).to eq('User is not allowed to trigger test runs for this policy')
    end
  end

  context 'when user can commit to a different policy project but not to the tested policy project' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_project) { create(:project, group: group) }
    let_it_be(:group_policy_management_project) { create(:project, developers: user) }
    let_it_be(:group_policy_configuration) do
      create(:security_orchestration_policy_configuration, :namespace,
        namespace: group,
        security_policy_management_project: group_policy_management_project)
    end

    let_it_be(:other_policy_management_project) { create(:project) }
    let_it_be(:other_policy_configuration) do
      create(:security_orchestration_policy_configuration,
        project: group_project,
        security_policy_management_project: other_policy_management_project)
    end

    let_it_be(:other_policy) do
      create(:security_policy, :pipeline_execution_schedule_policy,
        security_orchestration_policy_configuration: other_policy_configuration,
        security_policy_management_project: other_policy_management_project)
    end

    let(:service) { described_class.new(policy: other_policy, project: group_project, user: user) }

    before do
      allow(other_policy).to receive(:scope_applicable?).with(group_project).and_return(true)
    end

    it 'returns an authorization error', :aggregate_failures do
      expect(execute).to be_error
      expect(execute.message).to eq('User is not allowed to trigger test runs for this policy')
    end
  end

  context 'when project has no security policy configuration' do
    before do
      allow(project).to receive(:security_orchestration_policy_configuration).and_return(nil)
    end

    it 'returns an error', :aggregate_failures do
      expect(execute).to be_error
      expect(execute.message).to eq('User is not allowed to trigger test runs for this policy')
    end
  end
end

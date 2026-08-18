# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionSchedulePolicies::CreateTestRunPipelineWorker, '#perform',
  feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

  let(:test_run) do
    create(:security_pipeline_execution_policy_test_run,
      project: project, security_policy: policy, state: :pending, pipeline: nil)
  end

  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:create_pipeline_service_response) { ServiceResponse.success(payload: pipeline) }
  let(:create_scheduled_pipeline_service) do
    instance_double(Security::PipelineExecutionPolicies::CreateScheduledPipelineService)
  end

  subject(:perform) { described_class.new.perform(test_run.id) }

  before do
    allow(Security::PipelineExecutionPolicies::CreateScheduledPipelineService)
      .to receive(:new).and_return(create_scheduled_pipeline_service)
    allow(create_scheduled_pipeline_service).to receive(:execute).and_return(create_pipeline_service_response)
  end

  it 'has correct feature category' do
    expect(described_class.get_feature_category).to eq(:security_policy_management)
  end

  it 'has correct deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it 'has limited retries to avoid infinite retry loops' do
    expect(described_class.sidekiq_options['retry']).to eq(3)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [test_run.id] }

    it 'only creates one pipeline regardless of how many times it runs' do
      expect { perform_multiple(job_args) }
        .to change { test_run.reload.state }.from('pending').to('running')

      expect(test_run.reload.pipeline).to eq(pipeline)
    end
  end

  describe 'atomic state transition' do
    it 'transitions test run from pending to creating before pipeline creation' do
      allow(create_scheduled_pipeline_service).to receive(:execute) do
        expect(test_run.reload.state).to eq('creating')
        create_pipeline_service_response
      end

      perform
    end

    it 'calls claim_for_pipeline_creation on the test run' do
      expect(test_run).to receive(:claim_for_pipeline_creation).and_call_original
      allow(::Security::ScheduledPipelineExecutionPolicyTestRun)
        .to receive(:find_by_id).with(test_run.id).and_return(test_run)

      perform
    end

    context 'when another worker already claimed the test run' do
      before do
        allow(test_run).to receive(:claim_for_pipeline_creation).and_return(false)
        allow(::Security::ScheduledPipelineExecutionPolicyTestRun)
          .to receive(:find_by_id).with(test_run.id).and_return(test_run)
      end

      it 'returns early without creating a pipeline when atomic update returns 0' do
        expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

        perform
      end

      it 'logs that the test run was already claimed' do
        expect(::Gitlab::AppLogger).to receive(:info) do |payload|
          expect(payload['test_run_id']).to eq(test_run.id)
          expect(payload['message']).to eq('Failed to claim pending test run')
        end

        perform
      end

      it 'does not trigger GraphQL subscription' do
        expect(::GraphqlTriggers).not_to receive(:security_policy_schedule_test_run_updated)

        perform
      end
    end

    context 'when state changes between initial check and atomic update' do
      it 'handles race condition gracefully' do
        allow(::Security::ScheduledPipelineExecutionPolicyTestRun)
          .to receive(:find_by_id).with(test_run.id).and_return(test_run)
        allow(test_run).to receive_messages(pending?: true, claim_for_pipeline_creation: false)

        expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

        perform
      end
    end
  end

  context 'when pipeline creation succeeds' do
    it 'updates test run state to running' do
      expect { perform }.to change { test_run.reload.state }.from('pending').to('running')
    end

    it 'associates the pipeline with the test run' do
      perform

      expect(test_run.reload.pipeline).to eq(pipeline)
    end

    it 'triggers GraphQL subscription' do
      expect(::GraphqlTriggers).to receive(:security_policy_schedule_test_run_updated)

      perform
    end

    it 'calls CreateScheduledPipelineService with correct parameters' do
      expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService)
        .to receive(:new)
        .with(
          project: project,
          ci_content: policy.content['content'],
          policy: policy
        )
        .and_return(create_scheduled_pipeline_service)

      perform
    end

    context 'when another worker already processed the test run' do
      it 'does not create duplicate pipelines' do
        # First worker processes successfully
        perform
        expect(test_run.reload).to be_running

        expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)
        described_class.new.perform(test_run.id)

        expect(test_run.reload).to be_running
      end
    end
  end

  context 'when pipeline creation fails' do
    let(:create_pipeline_service_response) { ServiceResponse.error(message: 'Pipeline creation failed') }

    it 'updates test run state to failed' do
      expect { perform }.to change { test_run.reload.state }.from('pending').to('failed')
    end

    it 'sets error message on test run' do
      perform

      expect(test_run.reload.error_message).to eq('Pipeline creation failed')
    end

    it 'triggers GraphQL subscription' do
      expect(::GraphqlTriggers).to receive(:security_policy_schedule_test_run_updated)

      perform
    end

    it 'does not associate a pipeline' do
      perform

      expect(test_run.reload.pipeline).to be_nil
    end
  end

  context 'when an exception occurs during pipeline creation' do
    before do
      allow(create_scheduled_pipeline_service).to receive(:execute).and_raise(StandardError, 'Unexpected error')
    end

    it 'marks the test run as failed with orphaned pipeline message' do
      expect { perform }.to raise_error(StandardError, 'Unexpected error')

      expect(test_run.reload.state).to eq('failed')
      expect(test_run.error_message).to eq('Pipeline creation failed - an orphaned pipeline may exist')
    end

    it 'triggers GraphQL subscription before re-raising' do
      expect(::GraphqlTriggers).to receive(:security_policy_schedule_test_run_updated)

      expect { perform }.to raise_error(StandardError)
    end

    it 're-raises the exception for Sidekiq retry' do
      expect { perform }.to raise_error(StandardError, 'Unexpected error')
    end

    it 'logs the error' do
      allow(::Gitlab::AppLogger).to receive(:info)

      expect(::Gitlab::AppLogger).to receive(:error) do |payload|
        expect(payload['test_run_id']).to eq(test_run.id)
        expect(payload['message']).to eq('Unexpected error during pipeline creation')
        expect(payload['error_message']).to eq('Unexpected error')
      end

      expect { perform }.to raise_error(StandardError)
    end
  end

  context 'when test run does not exist' do
    subject(:perform) { described_class.new.perform(non_existing_record_id) }

    it 'returns early without error' do
      expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

      expect { perform }.not_to raise_error
    end

    it 'does not trigger GraphQL subscription' do
      expect(::GraphqlTriggers).not_to receive(:security_policy_schedule_test_run_updated)

      perform
    end
  end

  context 'when test run is not in pending state' do
    let(:test_run) do
      create(:security_pipeline_execution_policy_test_run,
        project: project, security_policy: policy, state: :running)
    end

    it 'returns early without creating a pipeline' do
      expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

      perform
    end

    it 'does not change the test run state' do
      expect { perform }.not_to change { test_run.reload.state }
    end

    it 'does not trigger GraphQL subscription' do
      expect(::GraphqlTriggers).not_to receive(:security_policy_schedule_test_run_updated)

      perform
    end
  end

  context 'when test run is in creating state' do
    let(:test_run) do
      create(:security_pipeline_execution_policy_test_run,
        project: project, security_policy: policy, state: :creating)
    end

    it 'returns early without creating a pipeline' do
      expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

      perform
    end
  end

  context 'when test run is already completed' do
    let(:test_run) do
      create(:security_pipeline_execution_policy_test_run,
        project: project, security_policy: policy, state: :complete)
    end

    it 'returns early without creating a pipeline' do
      expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

      perform
    end
  end

  context 'when test run is already failed' do
    let(:test_run) do
      create(:security_pipeline_execution_policy_test_run,
        project: project, security_policy: policy, state: :failed)
    end

    it 'returns early without creating a pipeline' do
      expect(Security::PipelineExecutionPolicies::CreateScheduledPipelineService).not_to receive(:new)

      perform
    end
  end

  describe 'logging' do
    context 'when pipeline creation fails' do
      let(:create_pipeline_service_response) { ServiceResponse.error(message: 'CI config error') }

      it 'logs the failure' do
        expect(::Gitlab::AppLogger).to receive(:error) do |payload|
          expect(payload['test_run_id']).to eq(test_run.id)
          expect(payload['message']).to eq('Pipeline creation failed')
          expect(payload['error_message']).to eq('CI config error')
        end

        perform
      end
    end
  end
end

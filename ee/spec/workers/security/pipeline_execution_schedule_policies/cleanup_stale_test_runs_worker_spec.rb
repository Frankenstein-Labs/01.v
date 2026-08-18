# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionSchedulePolicies::CleanupStaleTestRunsWorker,
  feature_category: :security_policy_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    subject(:perform) { worker.perform }

    let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

    context 'with no stale test runs' do
      let_it_be(:fresh_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::PENDING_TIMEOUT - 1.minute).ago
        )
      end

      let_it_be(:fresh_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::RUNNING_TIMEOUT - 1.hour).ago
        )
      end

      it 'does not update any test runs' do
        expect(::GraphqlTriggers).not_to receive(:security_policy_schedule_test_run_updated)

        expect { perform }.not_to change {
          Security::ScheduledPipelineExecutionPolicyTestRun.where(state: :failed).count
        }
      end

      it 'logs cleaned_count as 0' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:cleaned_count, 0)

        perform
      end
    end

    context 'with stale pending test run' do
      let_it_be_with_reload(:stale_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::PENDING_TIMEOUT + 1.minute).ago
        )
      end

      it 'marks the test run as failed with correct error message', :aggregate_failures do
        expect { perform }.to change { stale_pending_test_run.reload.state }.from('pending').to('failed')
        expect(stale_pending_test_run.error_message).to eq('Pipeline creation timed out')
      end

      it 'triggers GraphQL subscription' do
        expect(::GraphqlTriggers).to receive(:security_policy_schedule_test_run_updated).with(stale_pending_test_run)

        perform
      end

      it 'logs cleaned_count as 1' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:cleaned_count, 1)

        perform
      end
    end

    context 'with stale running test run' do
      let_it_be_with_reload(:stale_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      it 'marks the test run as failed with correct error message', :aggregate_failures do
        expect { perform }.to change { stale_running_test_run.reload.state }.from('running').to('failed')
        expect(stale_running_test_run.error_message).to eq('Pipeline execution timed out')
      end

      it 'triggers GraphQL subscription' do
        expect(::GraphqlTriggers).to receive(:security_policy_schedule_test_run_updated).with(stale_running_test_run)

        perform
      end
    end

    context 'with mixed stale test runs' do
      let_it_be_with_reload(:stale_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::PENDING_TIMEOUT + 1.minute).ago
        )
      end

      let_it_be_with_reload(:stale_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      let_it_be(:fresh_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::PENDING_TIMEOUT - 1.minute).ago
        )
      end

      it 'marks only stale test runs as failed', :aggregate_failures do
        perform

        expect(stale_pending_test_run.reload.state).to eq('failed')
        expect(stale_running_test_run.reload.state).to eq('failed')
        expect(fresh_pending_test_run.reload.state).to eq('pending')
      end

      it 'triggers GraphQL subscription for each stale test run' do
        expect(::GraphqlTriggers).to receive(:security_policy_schedule_test_run_updated).with(stale_pending_test_run)
        expect(::GraphqlTriggers).to receive(:security_policy_schedule_test_run_updated).with(stale_running_test_run)
        expect(::GraphqlTriggers)
          .not_to receive(:security_policy_schedule_test_run_updated).with(fresh_pending_test_run)

        perform
      end

      it 'logs correct cleaned_count' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:cleaned_count, 2)

        perform
      end
    end

    context 'with number of stale test runs higher than BATCH_SIZE' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        3.times do
          create(:security_pipeline_execution_policy_test_run,
            security_policy: security_policy,
            state: :pending,
            pipeline: nil,
            created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::PENDING_TIMEOUT + 1.minute).ago
          )
        end
      end

      it 'processes all stale test runs across multiple batches' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:cleaned_count, 3)

        perform

        expect(Security::ScheduledPipelineExecutionPolicyTestRun.where(state: :failed).count).to eq(3)
        expect(Security::ScheduledPipelineExecutionPolicyTestRun.where(state: :pending).count).to eq(0)
      end
    end

    context 'with number of stale test runs exceeding MAX_BATCHES * BATCH_SIZE' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
        stub_const("#{described_class}::MAX_BATCHES", 2)

        5.times do
          create(:security_pipeline_execution_policy_test_run,
            security_policy: security_policy,
            state: :pending,
            pipeline: nil,
            created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::PENDING_TIMEOUT + 1.minute).ago
          )
        end
      end

      it 'processes up to MAX_BATCHES * BATCH_SIZE test runs' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:cleaned_count, 4)

        perform

        expect(Security::ScheduledPipelineExecutionPolicyTestRun.where(state: :failed).count).to eq(4)
        expect(Security::ScheduledPipelineExecutionPolicyTestRun.where(state: :pending).count).to eq(1)
      end
    end

    context 'when records transition state between SELECT and UPDATE' do
      let_it_be(:test_run_model) { Security::ScheduledPipelineExecutionPolicyTestRun }

      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        4.times do
          create(:security_pipeline_execution_policy_test_run,
            security_policy: security_policy,
            state: :pending,
            pipeline: nil,
            created_at: (test_run_model::PENDING_TIMEOUT + 1.minute).ago
          )
        end
      end

      it 'continues processing subsequent batches even when some records transition state' do
        first_batch_called = false

        allow(test_run_model).to receive(:mark_as_failed).and_wrap_original do |method, **args|
          unless first_batch_called
            first_batch_called = true
            test_run_model.where(state: :pending).limit(1).update_all(state: :running)
          end

          method.call(**args)
        end

        perform

        expect(test_run_model.where(state: :failed).count).to be >= 3
      end
    end

    context 'when test run is already completed' do
      let_it_be(:completed_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :complete,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      it 'does not update completed test runs' do
        expect(::GraphqlTriggers).not_to receive(:security_policy_schedule_test_run_updated)

        expect { perform }.not_to change { completed_test_run.reload.state }
      end
    end

    context 'when test run is already failed' do
      let_it_be(:failed_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :failed,
          created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      it 'does not update failed test runs' do
        expect(::GraphqlTriggers).not_to receive(:security_policy_schedule_test_run_updated)

        expect { perform }.not_to change { failed_test_run.reload.state }
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
    let_it_be(:stale_test_run) do
      create(:security_pipeline_execution_policy_test_run,
        security_policy: security_policy,
        state: :pending,
        pipeline: nil,
        created_at: (Security::ScheduledPipelineExecutionPolicyTestRun::PENDING_TIMEOUT + 1.minute).ago
      )
    end
  end
end

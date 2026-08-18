# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScheduledPipelineExecutionPolicyTestRun, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:security_policy).class_name('Security::Policy') }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:pipeline).class_name('Ci::Pipeline').optional }

    describe '#pipeline' do
      it_behaves_like 'a partition-pruned pipeline association' do
        # .reload clears the :pipeline target cached by the attribute writer
        let(:related_resource) { create(:security_pipeline_execution_policy_test_run, pipeline: pipeline).reload }
      end
    end
  end

  describe 'validations' do
    let(:test_run) { build(:security_pipeline_execution_policy_test_run) }

    subject { test_run }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:security_policy) }
    it { is_expected.to validate_presence_of(:project) }

    context 'when security policy is not a pipeline_execution_schedule_policy' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_policy) }
      let(:test_run) { build(:security_pipeline_execution_policy_test_run, security_policy: security_policy) }

      it { is_expected.not_to be_valid }
    end
  end

  describe 'enums' do
    it 'defines state enum with correct values' do
      is_expected.to define_enum_for(:state)
        .with_values(running: 0, complete: 1, failed: 2, pending: 3, creating: 4)
        .with_default(:pending)
    end
  end

  describe 'scopes' do
    describe '.for_pipeline_id' do
      subject(:for_pipeline_id) { described_class.for_pipeline_id(pipeline.id) }

      let_it_be(:project) { create(:project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
      let_it_be(:other_pipeline) { create(:ci_pipeline, project: project) }
      let_it_be(:test_run) { create(:security_pipeline_execution_policy_test_run, pipeline: pipeline) }
      let_it_be(:other_test_run) { create(:security_pipeline_execution_policy_test_run, pipeline: other_pipeline) }

      it 'returns only test runs for the specified pipeline' do
        is_expected.to contain_exactly(test_run)
      end
    end

    describe '.for_policy' do
      subject(:for_policy) { described_class.for_policy(test_run.security_policy) }

      let_it_be(:project) { create(:project) }
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:other_security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:test_run) { create(:security_pipeline_execution_policy_test_run, security_policy: security_policy) }
      let_it_be(:other_test_run) do
        create(:security_pipeline_execution_policy_test_run, security_policy: other_security_policy)
      end

      it 'returns only test runs for the specified policy' do
        is_expected.to contain_exactly(test_run)
      end
    end

    describe '.stale_pending' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:stale_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (described_class::PENDING_TIMEOUT + 1.minute).ago
        )
      end

      let(:fresh_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (described_class::PENDING_TIMEOUT - 1.minute).ago
        )
      end

      let(:stale_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (described_class::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      before do
        stale_pending_test_run
        fresh_pending_test_run
        stale_running_test_run
      end

      it 'returns only stale pending test runs' do
        expect(described_class.stale_pending).to contain_exactly(stale_pending_test_run)
      end
    end

    describe '.stale_running' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:stale_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (described_class::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      let(:fresh_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (described_class::RUNNING_TIMEOUT - 1.hour).ago
        )
      end

      let(:stale_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (described_class::PENDING_TIMEOUT + 1.minute).ago
        )
      end

      before do
        stale_running_test_run
        fresh_running_test_run
        stale_pending_test_run
      end

      it 'returns only stale running test runs' do
        expect(described_class.stale_running).to contain_exactly(stale_running_test_run)
      end
    end

    describe '.stale' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:stale_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (described_class::PENDING_TIMEOUT + 1.minute).ago
        )
      end

      let(:stale_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (described_class::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      let(:fresh_pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil,
          created_at: (described_class::PENDING_TIMEOUT - 1.minute).ago
        )
      end

      let(:fresh_running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running,
          created_at: (described_class::RUNNING_TIMEOUT - 1.hour).ago
        )
      end

      let(:completed_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :complete,
          created_at: (described_class::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      let(:failed_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :failed,
          created_at: (described_class::RUNNING_TIMEOUT + 1.hour).ago
        )
      end

      before do
        stale_pending_test_run
        stale_running_test_run
        fresh_pending_test_run
        fresh_running_test_run
        completed_test_run
        failed_test_run
      end

      it 'returns both stale pending and stale running test runs' do
        expect(described_class.stale).to contain_exactly(stale_pending_test_run, stale_running_test_run)
      end

      it 'excludes completed test runs even if old' do
        expect(described_class.stale).not_to include(completed_test_run)
      end

      it 'excludes failed test runs even if old' do
        expect(described_class.stale).not_to include(failed_test_run)
      end

      it 'excludes fresh test runs' do
        expect(described_class.stale).not_to include(fresh_pending_test_run, fresh_running_test_run)
      end
    end

    describe '.mark_as_failed' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:pending_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :pending,
          pipeline: nil
        )
      end

      let(:running_test_run) do
        create(:security_pipeline_execution_policy_test_run,
          security_policy: security_policy,
          state: :running
        )
      end

      before do
        pending_test_run
        running_test_run
      end

      it 'updates state to failed and sets error message for matching state', :aggregate_failures do
        described_class.mark_as_failed(
          ids: [pending_test_run.id],
          error_message: 'Test error',
          expected_state: :pending
        )

        expect(pending_test_run.reload.state).to eq('failed')
        expect(pending_test_run.error_message).to eq('Test error')
      end

      it 'updates updated_at timestamp' do
        original_updated_at = pending_test_run.updated_at

        travel_to(1.hour.from_now) do
          described_class.mark_as_failed(
            ids: [pending_test_run.id],
            error_message: 'Test error',
            expected_state: :pending
          )

          expect(pending_test_run.reload.updated_at).to be > original_updated_at
        end
      end

      it 'returns the number of updated records' do
        count = described_class.mark_as_failed(
          ids: [pending_test_run.id],
          error_message: 'Test error',
          expected_state: :pending
        )

        expect(count).to eq(1)
      end

      it 'returns 0 when given empty array' do
        count = described_class.mark_as_failed(ids: [], error_message: 'Test error', expected_state: :pending)

        expect(count).to eq(0)
      end

      it 'does not update records that have transitioned to a different state' do
        count = described_class.mark_as_failed(
          ids: [running_test_run.id],
          error_message: 'Test error',
          expected_state: :pending
        )

        expect(count).to eq(0)
        expect(running_test_run.reload.state).to eq('running')
      end
    end

    describe '.with_associations' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:test_run_1) { create(:security_pipeline_execution_policy_test_run, security_policy: security_policy) }
      let_it_be(:test_run_2) { create(:security_pipeline_execution_policy_test_run, security_policy: security_policy) }

      subject(:with_associations) { described_class.with_associations }

      it 'preloads pipeline association' do
        expect(with_associations.first.association(:pipeline)).to be_loaded
      end

      it 'preloads project association' do
        expect(with_associations.first.association(:project)).to be_loaded
      end

      it 'preloads security_policy association' do
        expect(with_associations.first.association(:security_policy)).to be_loaded
      end

      it 'orders by id descending' do
        expect(with_associations).to eq([test_run_2, test_run_1])
      end
    end
  end

  describe 'delegations' do
    let(:test_run) { create(:security_pipeline_execution_policy_test_run) }

    describe '#started_at' do
      it 'delegates to pipeline' do
        expect(test_run.started_at).to eq(test_run.pipeline.started_at)
      end
    end

    describe '#finished_at' do
      it 'delegates to pipeline' do
        expect(test_run.finished_at).to eq(test_run.pipeline.finished_at)
      end
    end

    describe '#duration' do
      it 'delegates to pipeline' do
        expect(test_run.duration).to eq(test_run.pipeline.duration)
      end
    end

    context 'when pipeline is nil' do
      let(:test_run) { create(:security_pipeline_execution_policy_test_run, pipeline: nil) }

      it 'returns nil for started_at' do
        expect(test_run.started_at).to be_nil
      end

      it 'returns nil for finished_at' do
        expect(test_run.finished_at).to be_nil
      end

      it 'returns nil for duration' do
        expect(test_run.duration).to be_nil
      end
    end
  end

  describe 'state transitions' do
    let(:test_run) { create(:security_pipeline_execution_policy_test_run, state: :running) }

    it 'starts in running state' do
      expect(test_run).to be_running
    end

    it 'can transition to complete' do
      test_run.update!(state: :complete)
      expect(test_run).to be_complete
    end

    it 'can transition to failed' do
      test_run.update!(state: :failed)
      expect(test_run).to be_failed
    end

    context 'when starting in pending state' do
      let(:test_run) { create(:security_pipeline_execution_policy_test_run, state: :pending, pipeline: nil) }

      it 'is in pending state' do
        expect(test_run).to be_pending
      end

      it 'can transition to running' do
        test_run.update!(state: :running)
        expect(test_run).to be_running
      end

      it 'can transition to failed' do
        test_run.update!(state: :failed)
        expect(test_run).to be_failed
      end
    end
  end

  describe '#completed?' do
    it 'returns false when pending' do
      test_run = build(:security_pipeline_execution_policy_test_run, state: :pending, pipeline: nil)

      expect(test_run.completed?).to be(false)
    end

    it 'returns false when running' do
      test_run = build(:security_pipeline_execution_policy_test_run, state: :running)

      expect(test_run.completed?).to be(false)
    end

    it 'returns true when complete' do
      test_run = build(:security_pipeline_execution_policy_test_run, state: :complete)

      expect(test_run.completed?).to be(true)
    end

    it 'returns true when failed' do
      test_run = build(:security_pipeline_execution_policy_test_run, state: :failed)

      expect(test_run.completed?).to be(true)
    end
  end

  describe 'error_message' do
    let(:test_run) { create(:security_pipeline_execution_policy_test_run, error_message: 'Test error') }

    it 'stores error message' do
      expect(test_run.error_message).to eq('Test error')
    end

    context 'when error_message exceeds limit' do
      let(:long_message) { 'a' * 256 }

      it 'truncates to 255 characters' do
        test_run = create(:security_pipeline_execution_policy_test_run, error_message: long_message)
        expect(test_run.error_message.length).to eq(255)
      end
    end
  end

  describe '#claim_for_pipeline_creation' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

    let(:test_run) do
      create(:security_pipeline_execution_policy_test_run,
        project: project, security_policy: policy, state: :pending)
    end

    it 'atomically transitions test run from pending to creating' do
      expect(test_run.claim_for_pipeline_creation).to be true
      expect(test_run.reload.state).to eq('creating')
    end

    it 'returns true when claim is successful' do
      expect(test_run.claim_for_pipeline_creation).to be true
    end

    context 'when test run is not in pending state' do
      before do
        test_run.update!(state: :creating)
      end

      it 'returns false' do
        expect(test_run.claim_for_pipeline_creation).to be false
      end

      it 'does not change the state' do
        expect { test_run.claim_for_pipeline_creation }
          .not_to change { test_run.reload.state }
      end
    end
  end

  describe '#mark_as_failed!' do
    let_it_be(:project) { create(:project) }
    let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

    let(:test_run) do
      create(:security_pipeline_execution_policy_test_run,
        project: project, security_policy: policy, state: :creating)
    end

    it 'updates state to failed and sets error message' do
      test_run.mark_as_failed!('Pipeline creation failed')

      expect(test_run.state).to eq('failed')
      expect(test_run.error_message).to eq('Pipeline creation failed')
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflow::ExecutionState,
  :clean_gitlab_redis_shared_state,
  feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let(:workflow) { :sast_fp_detection }
  let(:metadata) { { fingerprint: 'abc123' } }

  let(:stages) do
    [
      { name: 'critical', order: 0 }
    ]
  end

  subject(:state) do
    described_class.create!(
      project_id: project.id,
      workflow: workflow,
      stages: stages,
      metadata: metadata
    )
  end

  describe '.create!' do
    it 'creates an execution', :aggregate_failures do
      expect(state.execution_id).to be_present
      expect(state.status).to eq(:created)
      expect(state.workflow_metadata).to eq(metadata.stringify_keys)
    end

    it 'returns the existing active execution' do
      second = described_class.create!(
        project_id: project.id,
        workflow: workflow,
        stages: stages
      )

      expect(second.execution_id).to eq(state.execution_id)
    end

    it 'creates a new execution after the previous execution finishes processing' do
      first_execution = state

      first_execution.append_to_stage!(
        stage: :critical,
        item_ids: ['finding-1']
      )
      first_execution.start!
      first_execution.start_processing!(['finding-1'])
      first_execution.mark_completed!(['finding-1'])

      expect(first_execution.status).to eq(:completed)

      second_execution = described_class.create!(
        project_id: project.id,
        workflow: workflow,
        stages: stages
      )

      expect(second_execution.execution_id).not_to eq(first_execution.execution_id)
      expect(second_execution.status).to eq(:created)
    end
  end

  describe '.current' do
    it 'returns nil when no execution exists' do
      current = described_class.current(
        project_id: project.id,
        workflow: workflow
      )

      expect(current).to be_nil
    end

    it 'returns the active execution' do
      state

      current = described_class.current(project_id: project.id, workflow: workflow)

      expect(current&.execution_id).to eq(state.execution_id)
    end

    it 'returns nil after completion' do
      state.complete!

      current = described_class.current(project_id: project.id, workflow: workflow)

      expect(current).to be_nil
    end

    it 'returns nil when current pointer exists but metadata is missing' do
      state

      metadata_key = "vulnerabilities:bulk_duo_workflow:{#{project.id}:#{workflow}}:#{state.execution_id}:metadata"
      Gitlab::Redis::SharedState.with { |r| r.del(metadata_key) }

      current = described_class.current(project_id: project.id, workflow: workflow)

      expect(current).to be_nil
    end
  end

  describe '.latest' do
    it 'returns nil when no execution exists' do
      latest = described_class.latest(
        project_id: project.id,
        workflow: workflow
      )

      expect(latest).to be_nil
    end

    it 'returns the latest active execution' do
      state

      latest = described_class.latest(project_id: project.id, workflow: workflow)

      expect(latest&.execution_id).to eq(state.execution_id)
    end

    it 'returns the new latest execution after the previous execution completes' do
      first_execution = state
      first_execution.complete!

      second_execution = described_class.create!(
        project_id: project.id,
        workflow: workflow,
        stages: stages
      )

      latest = described_class.latest(project_id: project.id, workflow: workflow)

      expect(latest&.execution_id).to eq(second_execution.execution_id)
    end

    it 'returns nil when latest pointer exists but metadata is missing' do
      state

      metadata_key = "vulnerabilities:bulk_duo_workflow:{#{project.id}:#{workflow}}:#{state.execution_id}:metadata"
      Gitlab::Redis::SharedState.with { |r| r.del(metadata_key) }

      latest = described_class.latest(project_id: project.id, workflow: workflow)

      expect(latest).to be_nil
    end

    context 'when the latest execution is in a terminal state' do
      where(:status, :transition) do
        [
          [described_class::STATUS_COMPLETED, :complete!],
          [described_class::STATUS_FAILED, :fail!],
          [described_class::STATUS_CANCELLED, :cancel!]
        ]
      end

      with_them do
        it 'returns the latest execution' do
          state.public_send(transition)

          latest = described_class.latest(project_id: project.id, workflow: workflow)

          expect(latest&.execution_id).to eq(state.execution_id)
          expect(latest&.status).to eq(status)
        end
      end
    end
  end

  describe '.fetch' do
    it 'returns the execution when it exists' do
      fetched = described_class.fetch(
        execution_id: state.execution_id,
        project_id: project.id,
        workflow: workflow
      )

      expect(fetched.execution_id).to eq(state.execution_id)
    end

    it 'returns nil when the execution does not exist' do
      fetched = described_class.fetch(
        execution_id: SecureRandom.uuid,
        project_id: project.id,
        workflow: workflow
      )

      expect(fetched).to be_nil
    end
  end

  describe '#initialize' do
    where(:project_id, :workflow, :message) do
      nil        | :sast_fp_detection | 'project_id is required'
      123        | nil                | 'workflow is required'
    end

    with_them do
      it 'raises an ArgumentError' do
        expect do
          described_class.new(execution_id: SecureRandom.uuid, project_id: project_id, workflow: workflow).cancel!
        end.to raise_error(ArgumentError, message)
      end
    end
  end

  describe '#start!' do
    before do
      state.start!
    end

    it 'stores execution metadata', :aggregate_failures do
      snap = state.snapshot

      expect(snap[:execution_id]).to eq(state.execution_id)
      expect(snap[:project_id]).to eq(project.id.to_s)
      expect(snap[:workflow]).to eq(workflow)
      expect(snap[:metadata]).to eq(metadata.stringify_keys)
      expect(snap[:status]).to eq(:running)
      expect(snap[:cancel_requested]).to be(false)
      expect(snap[:started_at]).to be_present
      expect(snap[:ended_at]).to be_nil

      expect(state.created_at).to eq(snap[:created_at])
      expect(state.started_at).to eq(snap[:started_at])
      expect(state.cancel_requested?).to be(false)
      expect(state.stages).to eq(stages.as_json)
      expect(state.current_stage).to eq(stages.first.as_json)
    end
  end

  describe '#cancel!' do
    before do
      state.cancel!
    end

    it 'marks execution cancelled', :aggregate_failures do
      snap = state.snapshot

      expect(snap[:status]).to eq(:cancelled)
      expect(snap[:cancel_requested]).to be(true)
      expect(snap[:ended_at]).to be_present

      expect(state.cancel_requested?).to be(true)
      expect(state.ended_at).to eq(snap[:ended_at])
    end
  end

  describe '#complete!' do
    before do
      state.complete!
    end

    it 'marks execution completed' do
      expect(state.status).to eq(:completed)
    end
  end

  describe '#fail!' do
    before do
      state.fail!
    end

    it 'marks execution failed' do
      expect(state.status).to eq(:failed)
    end
  end

  describe '#mark_completed!' do
    let(:vulnerability_state) do
      instance_double(
        Vulnerabilities::BulkDuoWorkflow::VulnerabilityState,
        mark_completed!: result,
        claim_batch_enqueue!: true,
        claim_stage_enqueue!: true
      )
    end

    before do
      allow(Vulnerabilities::BulkDuoWorkflow::VulnerabilityState).to receive(:new).and_return(vulnerability_state)

      allow(vulnerability_state).to receive_messages(pending_ids: [3, 4], start_processing!: :processing)
    end

    where(:result, :batch_claimed, :stage_claimed) do
      :batch_complete | 1 | 0
      :stage_complete | 0 | 1
      :completed      | 0 | 0
    end

    with_them do
      it 'claims the appropriate continuation and returns the result' do
        expect(vulnerability_state).to receive(:claim_batch_enqueue!).exactly(batch_claimed).times

        expect(vulnerability_state).to receive(:claim_stage_enqueue!).exactly(stage_claimed).times

        transition, next_item_ids = state.mark_completed!([1, 2])

        expect(transition).to eq(result)

        case result
        when :batch_complete, :stage_complete
          expect(next_item_ids).to eq([3, 4])
        when :completed
          expect(next_item_ids).to be_empty
        end
      end
    end
  end

  describe '#active?' do
    where(:status, :active) do
      nil | false
      :created | true
      :running   | true
      :completed | false
      :failed    | false
      :cancelled | false
    end

    with_them do
      before do
        allow(state).to receive(:status).and_return(status)
      end

      it 'returns expected state' do
        expect(state.active?).to eq(active)
      end
    end
  end

  describe '#exists?' do
    it 'returns true when execution metadata exists' do
      expect(state.exists?).to be(true)
    end

    it 'returns false when execution metadata is missing' do
      metadata_key = "vulnerabilities:bulk_duo_workflow:{#{project.id}:#{workflow}}:#{state.execution_id}:metadata"
      Gitlab::Redis::SharedState.with { |r| r.del(metadata_key) }

      expect(state.exists?).to be(false)
    end
  end

  describe '#status' do
    where(:cancelled, :status) do
      false | :created
      true  | :cancelled
    end

    with_them do
      before do
        state.cancel! if cancelled
      end

      it 'returns status' do
        expect(state.status).to eq(status)
      end
    end
  end

  describe '#workflow_metadata' do
    it 'returns metadata' do
      expect(state.workflow_metadata).to eq(metadata.stringify_keys)
    end
  end

  describe '#batch_size' do
    it 'returns configured batch size' do
      expect(state.batch_size).to eq(described_class::BATCH_SIZE)
    end
  end

  describe '#append_to_stage!' do
    it 'delegates to VulnerabilityState' do
      vulnerability_state = instance_double(Vulnerabilities::BulkDuoWorkflow::VulnerabilityState)

      allow(Vulnerabilities::BulkDuoWorkflow::VulnerabilityState)
        .to receive(:new).and_return(vulnerability_state)

      expect(vulnerability_state)
        .to receive(:append_stage!).with(index: 0, item_ids: [1, 2])

      state.append_to_stage!(stage: :critical, item_ids: [1, 2])
    end
  end

  describe '#next_batch' do
    it 'delegates to VulnerabilityState' do
      vulnerability_state = instance_double(Vulnerabilities::BulkDuoWorkflow::VulnerabilityState)

      allow(Vulnerabilities::BulkDuoWorkflow::VulnerabilityState)
        .to receive(:new).and_return(vulnerability_state)

      expect(vulnerability_state)
        .to receive(:pending_ids).with(limit: described_class::BATCH_SIZE)

      state.next_batch
    end
  end

  describe '#snapshot' do
    it 'includes execution metadata' do
      expect(state.snapshot).to include(execution_id: state.execution_id, workflow: workflow)
    end
  end

  describe '#progress' do
    before do
      state.append_to_stage!(stage: :critical, item_ids: [1, 2, 3, 4, 5])

      state.start!
      state.start_processing!([2, 3, 4, 5])
      state.mark_completed!([3])
      state.mark_failed!([4])
      state.mark_cancelled!([5])
    end

    it 'returns execution progress' do
      expect(state.progress).to eq(
        total: 5,
        pending: 1,
        processing: 1,
        completed: 1,
        failed: 1,
        cancelled: 1,
        percentage: (3 * 100.0 / 5)
      )
    end
  end

  describe '#item_states' do
    before do
      state.append_to_stage!(stage: :critical, item_ids: [1, 2, 3, 4, 5])

      state.start!
      state.start_processing!([2, 3, 4, 5])
      state.mark_completed!([3])
      state.mark_failed!([4])
      state.mark_cancelled!([5])
    end

    it 'returns the state of every item' do
      expect(state.item_states).to contain_exactly(
        { uuid: '1', state: :pending },
        { uuid: '2', state: :processing },
        { uuid: '3', state: :completed },
        { uuid: '4', state: :failed },
        { uuid: '5', state: :cancelled }
      )
    end
  end

  describe '#contains_item?' do
    before do
      state.append_to_stage!(stage: :critical, item_ids: [1, 2, 3, 4, 5])

      state.start!
      state.start_processing!([2, 3, 4, 5])
      state.mark_completed!([3])
      state.mark_failed!([4])
      state.mark_cancelled!([5])
    end

    it 'returns true for items belonging to the execution', :aggregate_failures do
      expect(state.contains_item?(1)).to be(true)
      expect(state.contains_item?(2)).to be(true)
      expect(state.contains_item?(3)).to be(true)
      expect(state.contains_item?(4)).to be(true)
      expect(state.contains_item?(5)).to be(true)
    end

    it 'returns false for an item not belonging to the execution' do
      expect(state.contains_item?(6)).to be(false)
    end
  end

  describe '#pending_ids' do
    let(:stages) do
      [
        { name: 'critical', order: 0 },
        { name: 'high', order: 1 }
      ]
    end

    before do
      state.append_to_stage!(stage: :critical, item_ids: %w[c1 c2])
      state.append_to_stage!(stage: :high, item_ids: %w[h1 h2])
    end

    it 'returns pending ids across stages in order' do
      expect(state.pending_ids).to eq(%w[c1 c2 h1 h2])
    end

    it 'respects the limit across stages' do
      expect(state.pending_ids(limit: 3)).to eq(%w[c1 c2 h1])
    end
  end

  describe '#pending_ids_by_stage' do
    let(:stages) do
      [
        { name: 'critical', order: 0 },
        { name: 'high', order: 1 }
      ]
    end

    before do
      state.append_to_stage!(stage: :critical, item_ids: %w[c1 c2])
      state.append_to_stage!(stage: :high, item_ids: %w[h1])
    end

    it 'returns pending ids grouped by stage' do
      expect(state.pending_ids_by_stage).to eq(0 => %w[c1 c2], 1 => %w[h1])
    end
  end

  describe '#cancel_requested?' do
    it 'returns whether cancellation has been requested' do
      expect(state.cancel_requested?).to be(false)

      state.cancel!

      expect(state.cancel_requested?).to be(true)
    end
  end

  describe '#mark_cancelled!' do
    let(:vulnerability_state) do
      instance_double(
        Vulnerabilities::BulkDuoWorkflow::VulnerabilityState,
        claim_batch_enqueue!: true,
        claim_stage_enqueue!: true
      )
    end

    before do
      allow(Vulnerabilities::BulkDuoWorkflow::VulnerabilityState)
        .to receive(:new)
              .and_return(vulnerability_state)
    end

    it 'passes the stage order to VulnerabilityState' do
      expect(vulnerability_state).to receive(:mark_cancelled!).with([1, 2], stage_order: 1).and_return(:completed)

      transition, next_item_ids = state.mark_cancelled!([1, 2], stage_order: 1)

      expect(transition).to eq(:completed)
      expect(next_item_ids).to be_empty
    end
  end

  describe 'full staged lifecycle' do
    let(:stages) do
      [
        { name: 'critical', order: 0 },
        { name: 'high', order: 1 }
      ]
    end

    subject(:execution) do
      described_class.create!(
        project_id: project.id,
        workflow: workflow,
        stages: stages
      )
    end

    it 'processes all stages until the execution completes', :aggregate_failures do
      execution.append_to_stage!(stage: :critical, item_ids: [1, 2])
      execution.append_to_stage!(stage: :high, item_ids: [3, 4])

      expect(execution.start!).to eq(:running)

      expect(execution.next_batch).to match_array(%w[1 2])

      expect(execution.start_processing!([1, 2])).to eq(:processing)

      transition, next_item_ids = execution.mark_completed!([1, 2])
      expect(transition).to eq(:stage_complete)
      expect(next_item_ids).to match_array(%w[3 4])

      expect(execution.snapshot).to include(
        status: :running,
        current_stage: 1,
        processing_ids: match_array(%w[3 4])
      )

      transition, next_item_ids = execution.mark_completed!([3, 4])
      expect(transition).to eq(:completed)
      expect(next_item_ids).to be_empty

      expect(execution.snapshot).to include(
        status: :completed,
        current_stage: 1,
        pending_ids: [],
        processing_ids: [],
        completed_ids: match_array(%w[1 2 3 4]),
        failed_ids: [],
        cancelled_ids: []
      )

      expect(execution.snapshot[:ended_at]).to be_present
    end
  end
end

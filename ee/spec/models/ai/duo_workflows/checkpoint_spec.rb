# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Checkpoint, feature_category: :duo_agent_platform do
  def ms_timestamp(time)
    time.change(nsec: (time.nsec / 1000) * 1000)
  end

  let_it_be(:ts_first) { '619a978e-9f3a-7174-9d92-b51f500b8a5b' }
  let_it_be(:ts_second) { '719a978e-9f3a-7174-9d92-b51f500b8a5b' }

  let_it_be(:checkpoint1) do
    create(:duo_workflows_checkpoint, thread_ts: ts_first, created_at: ms_timestamp(3.days.ago))
  end

  let_it_be(:checkpoint2) do
    create(:duo_workflows_checkpoint, thread_ts: ts_second, created_at: ms_timestamp(2.days.ago))
  end

  let_it_be(:write1) do
    create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts, workflow: checkpoint1.workflow)
  end

  let_it_be(:write2) do
    create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts, workflow: checkpoint1.workflow)
  end

  it { is_expected.to validate_presence_of(:thread_ts) }
  it { is_expected.to validate_presence_of(:checkpoint) }
  it { is_expected.to validate_presence_of(:metadata) }

  it_behaves_like 'sync workflow attributes' do
    subject { build(:duo_workflows_checkpoint) }
  end

  it "touches workflow on save" do
    workflow = create(:duo_workflows_workflow)
    expect(workflow.created_at).to eq(workflow.updated_at)

    create(:duo_workflows_checkpoint, workflow: workflow)
    expect(workflow.updated_at).to be > workflow.created_at
  end

  describe '#normalize_checkpoint_ns' do
    it 'persists a blank checkpoint_ns as nil' do
      checkpoint = create(:duo_workflows_checkpoint, checkpoint_ns: '')

      expect(checkpoint.reload.checkpoint_ns).to be_nil
    end

    it 'preserves a non-blank checkpoint_ns' do
      checkpoint = create(:duo_workflows_checkpoint, checkpoint_ns: 'delegation:task-1')

      expect(checkpoint.reload.checkpoint_ns).to eq('delegation:task-1')
    end

    it 'is reachable via .earliest/.latest default (nil) lineage despite being created with an empty string' do
      described_class.delete_all
      # created_at is part of this partitioned table's composite primary key, so reload to
      # match Postgres's timestamp precision (avoids a false mismatch against the in-memory
      # value, which retains full nanosecond precision).
      checkpoint = create(:duo_workflows_checkpoint, checkpoint_ns: '').reload

      expect(described_class.earliest).to eq(checkpoint)
      expect(described_class.latest).to eq(checkpoint)
    end
  end

  describe '.ordered_with_writes' do
    it 'returns checkpoints ordered by thread_ts with writes included' do
      result = described_class.ordered_with_writes

      expect(result.to_a).to eq([checkpoint2, checkpoint1])
      expect(result[0].association(:checkpoint_writes)).to be_loaded
    end
  end

  describe '.with_checkpoint_writes' do
    it 'returns checkpoint, including checkpoint_writes' do
      result = described_class.with_checkpoint_writes

      expect(result.to_a).to match_array([checkpoint2, checkpoint1])
      expect(result[0].association(:checkpoint_writes)).to be_loaded
    end
  end

  describe '.earliest' do
    let_it_be(:ts_earliest) { '019a978e-9f3a-7174-9d92-b51f500b8a5b' }
    let_it_be(:checkpoint3) do
      create(:duo_workflows_checkpoint, thread_ts: ts_earliest, created_at: ms_timestamp(2.hours.ago))
    end

    it 'returns the checkpoint with the earliest thread_ts' do
      expect(described_class.earliest).to eq(checkpoint3)
    end

    context 'when there are no checkpoints' do
      it 'returns nil' do
        described_class.delete_all
        expect(described_class.earliest).to be_nil
      end
    end

    context 'with checkpoint_ns' do
      let_it_be(:ts_nested_earliest) { '029a978e-9f3a-7174-9d92-b51f500b8a5b' }
      let_it_be(:nested_checkpoint) do
        create(:duo_workflows_checkpoint, thread_ts: ts_nested_earliest, checkpoint_ns: 'delegation:task-1',
          created_at: ms_timestamp(1.hour.ago))
      end

      it 'only considers checkpoints in that namespace' do
        expect(described_class.earliest(checkpoint_ns: 'delegation:task-1')).to eq(nested_checkpoint)
      end

      it 'defaults to the top-level (blank checkpoint_ns) lineage, ignoring nested namespaces' do
        expect(described_class.earliest).to eq(checkpoint3)
      end

      it 'treats an explicit blank checkpoint_ns the same as the default' do
        expect(described_class.earliest(checkpoint_ns: '')).to eq(checkpoint3)
      end

      it 'returns nil for a namespace with no checkpoints' do
        expect(described_class.earliest(checkpoint_ns: 'delegation:unknown-task')).to be_nil
      end
    end
  end

  describe '.latest' do
    let_it_be(:ts_latest) { '919a978e-9f3a-7174-9d92-b51f500b8a5b' }
    let_it_be(:checkpoint3) do
      create(:duo_workflows_checkpoint, thread_ts: ts_latest, created_at: ms_timestamp(7.days.ago))
    end

    it 'returns the checkpoint with the latest thread_ts' do
      expect(described_class.latest).to eq(checkpoint3)
    end

    context 'when there are no checkpoints' do
      it 'returns nil' do
        described_class.delete_all
        expect(described_class.latest).to be_nil
      end
    end

    context 'with checkpoint_ns' do
      let_it_be(:ts_nested_latest) { '929a978e-9f3a-7174-9d92-b51f500b8a5b' }
      let_it_be(:nested_checkpoint) do
        create(:duo_workflows_checkpoint, thread_ts: ts_nested_latest, checkpoint_ns: 'delegation:task-1',
          created_at: ms_timestamp(1.hour.ago))
      end

      it 'only considers checkpoints in that namespace, not the top-level lineage' do
        expect(described_class.latest(checkpoint_ns: 'delegation:task-1')).to eq(nested_checkpoint)
      end

      it 'defaults to the top-level (blank checkpoint_ns) lineage, ignoring nested namespaces' do
        expect(described_class.latest).to eq(checkpoint3)
      end

      it 'treats an explicit blank checkpoint_ns the same as the default' do
        expect(described_class.latest(checkpoint_ns: '')).to eq(checkpoint3)
      end

      it 'returns nil for a namespace with no checkpoints' do
        expect(described_class.latest(checkpoint_ns: 'delegation:unknown-task')).to be_nil
      end
    end
  end

  describe '.created_on_or_before' do
    it 'includes only checkpoints created on or before the given time' do
      result = described_class.created_on_or_before(2.5.days.ago)

      expect(result).to include(checkpoint1)
      expect(result).not_to include(checkpoint2)
    end

    it 'bounds created_at' do
      expect(described_class.created_on_or_before(Time.current).to_sql).to include('created_at')
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }

    describe '#checkpoint_writes' do
      let_it_be(:write3) { create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts) }
      let_it_be(:write4) { create(:duo_workflows_checkpoint_write, workflow: checkpoint2.workflow) }

      it 'returns writes for the same workflow having same thread_ts' do
        expect(checkpoint1.checkpoint_writes).to match_array([write1, write2])
      end

      it 'has many checkpoint_writes' do
        is_expected.to have_many(:checkpoint_writes)
          .conditions(Ai::DuoWorkflows::CheckpointWrite.arel_table[:workflow_id]
            .eq(described_class.arel_table[:workflow_id]))
          .with_foreign_key(:thread_ts)
          .with_primary_key(:thread_ts)
          .inverse_of(:checkpoint)
      end
    end
  end

  describe '.find' do
    it 'finds by single id using find_by_id' do
      expect(described_class).to receive(:find_by_id).with(checkpoint1.id.first)
      described_class.find(checkpoint1.id.first)
    end

    it 'falls back to super for array arguments' do
      expect(
        described_class.find([checkpoint1.id.first, checkpoint1.created_at])
      ).to eq(checkpoint1)
    end
  end

  describe '#to_global_id' do
    it 'returns a GlobalID with the first id element' do
      gid = checkpoint1.to_global_id
      expect(gid).to be_a(GlobalID)
      expect(gid.model_id).to eq(checkpoint1.id.first.to_s)
    end
  end
end

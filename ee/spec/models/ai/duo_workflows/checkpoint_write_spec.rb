# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CheckpointWrite, feature_category: :duo_agent_platform do
  it { is_expected.to validate_presence_of(:workflow) }
  it { is_expected.to validate_presence_of(:thread_ts) }
  it { is_expected.to validate_presence_of(:task) }
  it { is_expected.to validate_presence_of(:idx) }
  it { is_expected.to validate_presence_of(:channel) }
  it { is_expected.to validate_presence_of(:write_type) }
  it { is_expected.to validate_length_of(:data).is_at_most(described_class::CHECKPOINT_WRITES_LIMIT) }

  describe 'associations' do
    it 'belongs to a checkpoint' do
      is_expected.to belong_to(:checkpoint)
        .conditions(Ai::DuoWorkflows::Checkpoint.arel_table[:workflow_id].eq(described_class.arel_table[:workflow_id]))
        .with_foreign_key(:thread_ts)
        .with_primary_key(:thread_ts)
        .inverse_of(:checkpoint_writes)
        .optional
    end

    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }
  end

  it_behaves_like 'sync workflow attributes' do
    subject { build(:duo_workflows_checkpoint_write) }
  end

  it_behaves_like 'a BulkInsertSafe model', described_class do
    let_it_be(:workflow) { create(:duo_workflows_workflow) }
    let(:valid_items_for_bulk_insertion) do
      build_list(:duo_workflows_checkpoint_write, 3, workflow: workflow, project: workflow.project)
    end

    let(:invalid_items_for_bulk_insertion) do
      build_list(:duo_workflows_checkpoint_write, 3, task: '', workflow: workflow, project: workflow.project)
    end
  end

  describe '.for_workflows_and_threads' do
    let_it_be(:workflow) { create(:duo_workflows_workflow) }
    let_it_be(:other_workflow) { create(:duo_workflows_workflow) }
    let_it_be(:matching_write) do
      create(:duo_workflows_checkpoint_write, workflow: workflow, thread_ts: 'thread-a', project: workflow.project)
    end

    let_it_be(:other_thread_write) do
      create(:duo_workflows_checkpoint_write, workflow: workflow, thread_ts: 'thread-b', project: workflow.project)
    end

    let_it_be(:other_workflow_write) do
      create(:duo_workflows_checkpoint_write, workflow: other_workflow, thread_ts: 'thread-a',
        project: other_workflow.project)
    end

    it 'only returns writes matching both the workflow_id and thread_ts pairs given' do
      result = described_class.for_workflows_and_threads([workflow.id], ['thread-a'])

      expect(result).to contain_exactly(matching_write)
    end
  end
end

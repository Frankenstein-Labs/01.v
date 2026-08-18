# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CheckpointHeader, feature_category: :duo_agent_platform do
  let_it_be(:workflow) { create(:duo_workflows_workflow) }

  subject(:header) { build(:duo_workflows_checkpoint_header, workflow: workflow) }

  describe 'associations' do
    it { is_expected.to belong_to(:workflow).class_name('Ai::DuoWorkflows::Workflow') }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:workflow) }
    it { is_expected.to validate_presence_of(:thread_ts) }
  end

  describe '.for_checkpoint_ns' do
    # Matched on thread_ts, not on the records themselves: the composite
    # [id, workflow_created_at] primary key makes ActiveRecord's `==` compare the
    # timestamp too, and the in-memory value carries sub-microsecond precision that
    # Postgres truncates, so a record never equals its own reloaded row.
    let_it_be(:top_level) { create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-top') }
    let_it_be(:nested) do
      create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-nested',
        checkpoint_ns: 'research_agent:0f8ba4c5')
    end

    it 'returns only headers in the given lineage' do
      expect(described_class.for_checkpoint_ns('research_agent:0f8ba4c5').map(&:thread_ts))
        .to contain_exactly('ts-nested')
    end

    it 'treats a blank namespace as the top-level lineage' do
      expect(described_class.for_checkpoint_ns('').map(&:thread_ts)).to contain_exactly('ts-top')
      expect(described_class.for_checkpoint_ns(nil).map(&:thread_ts)).to contain_exactly('ts-top')
    end
  end

  describe 'normalizing checkpoint_ns' do
    it 'stores a blank namespace as nil', :aggregate_failures do
      header = create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-blank',
        checkpoint_ns: '')

      expect(header.checkpoint_ns).to be_nil
      expect(described_class.for_checkpoint_ns(nil).map(&:thread_ts)).to include('ts-blank')
    end

    it 'leaves a namespace untouched' do
      header = create(:duo_workflows_checkpoint_header, workflow: workflow,
        checkpoint_ns: 'research_agent:0f8ba4c5')

      expect(header.checkpoint_ns).to eq('research_agent:0f8ba4c5')
    end

    it 'normalizes on the bulk insert path the shadow write uses' do
      now = Time.current
      header = build(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-bulk',
        checkpoint_ns: '', created_at: now, updated_at: now)

      described_class.bulk_insert!([header])

      expect(described_class.find_by(thread_ts: 'ts-bulk').checkpoint_ns).to be_nil
    end
  end

  describe '.in_reverse_checkpoint_order' do
    it 'orders by thread_ts descending, so the first row is the newest checkpoint' do
      create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-2')
      create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-3')
      create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-1')

      expect(described_class.in_reverse_checkpoint_order.map(&:thread_ts)).to eq(%w[ts-3 ts-2 ts-1])
    end
  end

  describe '.for_current_thread' do
    it 'orders the group by thread_ts, so the last row is the newest checkpoint' do
      # Insert the newest thread_ts first: a higher id must not count as newer.
      create(:duo_workflows_checkpoint_header, workflow: workflow, current_thread: 1, thread_ts: 'ts-3')
      create(:duo_workflows_checkpoint_header, workflow: workflow, current_thread: 1, thread_ts: 'ts-2')
      create(:duo_workflows_checkpoint_header, workflow: workflow, current_thread: 0, thread_ts: 'ts-1')

      # Assert on thread_ts, not the records: the composite primary key makes
      # object equality depend on workflow_created_at precision across reloads.
      expect(described_class.for_current_thread(1).map(&:thread_ts)).to eq(%w[ts-2 ts-3])
    end
  end

  describe 'syncing workflow container' do
    context 'with a project-level workflow' do
      it 'sets project_id from the workflow' do
        header.valid?
        expect(header.project_id).to eq(workflow.project_id)
      end
    end

    context 'with a namespace-level workflow' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, namespace: create(:group)) }

      it 'sets namespace_id from the workflow' do
        header.valid?
        expect(header.namespace_id).to eq(workflow.namespace_id)
      end
    end
  end
end

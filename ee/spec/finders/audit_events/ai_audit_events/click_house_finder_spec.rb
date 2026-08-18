# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AiAuditEvents::ClickHouseFinder, feature_category: :duo_agent_platform do
  let_it_be(:workflow) { create(:duo_workflows_workflow) }

  subject(:execute) { described_class.new(workflow: workflow).execute }

  it 'returns a ClickHouse query builder scoped to the workflow' do
    expect(execute).to be_a(::ClickHouse::Client::QueryBuilder)
    sql = execute.to_sql
    expect(sql).to include('ai_audit_events')
    expect(sql).to include(workflow.id.to_s)
    expect(sql).to match(/ORDER BY.*created_at.*DESC.*id.*DESC/im)
  end

  describe '.counts_for_workflows' do
    let(:workflow_ids) { [1, 2, 3] }
    let(:ch_rows) do
      [{ 'workflow_id' => 1, 'count' => 4 }, { 'workflow_id' => 2, 'count' => 7 }]
    end

    before do
      allow(::ClickHouse::Client).to receive(:select).and_return(ch_rows)
    end

    subject(:counts) { described_class.counts_for_workflows(workflow_ids) }

    it 'returns a hash of workflow_id to count' do
      expect(counts).to eq({ 1 => 4, 2 => 7 })
    end

    it 'returns 0 implicitly for workflow IDs with no events' do
      expect(counts.key?(3)).to be(false)
    end

    it 'queries the ai_audit_events table grouped by workflow_id' do
      counts
      expect(::ClickHouse::Client).to have_received(:select) do |query, _|
        expect(query.to_sql).to include('ai_audit_events')
        expect(query.to_sql).to include('workflow_id')
      end
    end

    context 'with min_created_at' do
      let(:min_created_at) { 7.days.ago }

      subject(:counts) { described_class.counts_for_workflows(workflow_ids, min_created_at: min_created_at) }

      it 'adds a created_at lower bound to enable partition pruning' do
        counts
        expect(::ClickHouse::Client).to have_received(:select) do |query, _|
          expect(query.to_sql).to include('created_at')
        end
      end
    end
  end
end

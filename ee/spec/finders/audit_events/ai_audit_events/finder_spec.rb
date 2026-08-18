# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AiAuditEvents::Finder, feature_category: :duo_agent_platform do
  let_it_be(:workflow) { create(:duo_workflows_workflow) }

  subject(:execute) { described_class.new(workflow: workflow).execute }

  context 'when ClickHouse is globally enabled for analytics' do
    before do
      allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    it 'dispatches to the ClickHouse finder' do
      ch_relation = double('clickhouse_relation') # rubocop:disable RSpec/VerifiedDoubles -- query builder, not a fixed interface
      expect(::AuditEvents::AiAuditEvents::ClickHouseFinder)
        .to receive(:new).with(workflow: workflow).and_return(instance_double(
          ::AuditEvents::AiAuditEvents::ClickHouseFinder, execute: ch_relation
        ))

      expect(execute).to be(ch_relation)
    end
  end

  context 'when ClickHouse is not globally enabled for analytics' do
    before do
      allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
    end

    it 'dispatches to the PostgreSQL finder' do
      expect(execute).to be_a(ActiveRecord::Relation)
      expect(execute.where_values_hash).to include('workflow_id' => workflow.id)
    end
  end
end

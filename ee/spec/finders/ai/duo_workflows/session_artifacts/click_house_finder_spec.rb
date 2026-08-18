# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::SessionArtifacts::ClickHouseFinder, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:params) { {} }

  subject(:result) { described_class.new(namespace: group, params: params).execute }

  it 'returns a ClickHouse query builder' do
    expect(result).to be_a(::ClickHouse::Client::QueryBuilder)
  end

  it 'queries the siphon_duo_workflows_workflows table' do
    expect(result.to_sql).to include('siphon_duo_workflows_workflows')
  end

  it 'scopes by namespace traversal path using with_organization format', :aggregate_failures do
    expect(result.to_sql).to include('startsWith')
    expect(result.to_sql).to include(group.traversal_path(with_organization: true))
  end

  it 'excludes siphon-deleted rows' do
    expect(result.to_sql).to include('_siphon_deleted')
  end

  it 'orders by updated_at DESC then id DESC' do
    expect(result.to_sql).to match(/ORDER BY.*updated_at.*DESC.*id.*DESC/im)
  end

  it 'deduplicates rows using argMax and GROUP BY', :aggregate_failures do
    expect(result.to_sql).to include('argMax')
    expect(result.to_sql).to include('GROUP BY')
  end

  context 'with workflowDefinition filter' do
    let(:params) { { workflow_definition: 'chat' } }

    it 'filters by workflow_definition', :aggregate_failures do
      expect(result.to_sql).to include('workflow_definition')
      expect(result.to_sql).to include('chat')
    end
  end

  context 'with not: { workflowDefinition } filter' do
    let(:params) { { not: { workflow_definition: 'chat' } } }

    it 'excludes the workflow_definition', :aggregate_failures do
      expect(result.to_sql).to include('workflow_definition')
      expect(result.to_sql).to include('chat')
    end
  end

  context 'with projectPath filter' do
    let(:params) { { project_path: project.full_path } }

    it 'filters by project traversal path in the inner query', :aggregate_failures do
      expect(result.to_sql).to include('startsWith')
      expect(result.to_sql).to include(project.project_namespace.traversal_path(with_organization: true))
    end

    context 'when the project path does not resolve' do
      let(:params) { { project_path: 'nonexistent/path' } }

      it 'returns a query that yields no results' do
        expect(result.to_sql).to include('`id` = 0')
      end
    end
  end

  context 'with not: { projectPath } filter' do
    let(:params) { { not: { project_path: project.full_path } } }

    it 'excludes by project traversal path in the inner query', :aggregate_failures do
      expect(result.to_sql).to include('not(startsWith')
      expect(result.to_sql).to include(project.project_namespace.traversal_path(with_organization: true))
    end
  end

  context 'when the not: { projectPath } does not resolve' do
    let(:params) { { not: { project_path: 'nonexistent/path' } } }

    it 'returns all namespace results with no exclusion filter applied' do
      expect(result.to_sql).not_to include('not(startsWith')
      expect(result.to_sql).to include(group.traversal_path(with_organization: true))
    end
  end

  context 'with workflowCreatedAfter filter' do
    let(:params) { { workflow_created_after: 2.days.ago } }

    it 'filters by created_at' do
      expect(result.to_sql).to include('created_at')
    end
  end

  context 'with workflowCreatedBefore filter' do
    let(:params) { { workflow_created_before: 2.days.ago } }

    it 'filters by created_at' do
      expect(result.to_sql).to include('created_at')
    end
  end

  context 'with workflowId filter' do
    let(:workflow_id) { 42 }
    let(:params) { { workflow_id: workflow_id } }

    it 'filters on the id column' do
      expect(result.to_sql).to match(/`id`\s*=\s*#{workflow_id}/)
    end
  end

  context 'with userId filter' do
    let(:user_id) { 99 }
    let(:params) { { user_id: user_id } }

    it 'filters on the user_id column' do
      expect(result.to_sql).to match(/`user_id`\s*=\s*#{user_id}/)
    end
  end

  context 'with not: { userId } filter' do
    let(:user_id) { 99 }
    let(:params) { { not: { user_id: user_id } } }

    it 'excludes the given user_id' do
      expect(result.to_sql).to match(/`user_id`\s*!=\s*#{user_id}/)
    end
  end
end

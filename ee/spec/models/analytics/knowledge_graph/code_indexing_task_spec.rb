# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Analytics::KnowledgeGraph::CodeIndexingTask, feature_category: :knowledge_graph do
  subject { build(:knowledge_graph_code_indexing_task) }

  describe 'table configuration' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('p_knowledge_graph_code_indexing_tasks')
    end

    it 'is a daily partitioned table' do
      expect(described_class.partitioning_strategy).to be_a(Gitlab::Database::Partitioning::Time::DailyStrategy)
      expect(described_class.partitioning_strategy.partitioning_key).to eq(:created_at)
    end
  end

  describe 'relations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:ref) }
    it { is_expected.to validate_length_of(:ref).is_at_most(255) }
    it { is_expected.to validate_presence_of(:commit_sha) }
    it { is_expected.to validate_length_of(:commit_sha).is_at_most(40) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:traversal_path) }
    it { is_expected.to validate_length_of(:traversal_path).is_at_most(1024) }
  end

  describe 'creating a record' do
    let_it_be(:project) { create(:project) }

    it 'persists the record successfully' do
      task = described_class.create!(
        project: project,
        ref: 'refs/heads/main',
        commit_sha: 'abc123def456',
        traversal_path: project.project_namespace.traversal_path(with_organization: true)
      )

      expect(task).to be_persisted
      expect(task.project).to eq(project)
      expect(task.ref).to eq('refs/heads/main')
      expect(task.commit_sha).to eq('abc123def456')
      expect(task.traversal_path).to eq(project.project_namespace.traversal_path(with_organization: true))
      expect(task.created_at).to be_present
    end
  end

  describe '.create_for_project' do
    let_it_be(:project) { create(:project) }

    context 'when knowledge graph indexing is enabled' do
      before do
        create(:knowledge_graph_enabled_namespace, namespace: project.root_ancestor)
      end

      it 'creates a task with the correct attributes' do
        task = described_class.create_for_project(project.id, 'refs/heads/main', 'abc123def456')

        expect(task).to be_persisted
        expect(task.project_id).to eq(project.id)
        expect(task.ref).to eq('refs/heads/main')
        expect(task.commit_sha).to eq('abc123def456')
        expect(task.traversal_path).to eq(project.project_namespace.traversal_path(with_organization: true))
      end
    end

    context 'when knowledge graph indexing is not enabled' do
      it 'returns nil' do
        expect(described_class.create_for_project(project.id, 'refs/heads/main', 'abc123def456')).to be_nil
      end
    end

    context 'when the project does not exist' do
      it 'returns nil' do
        expect(described_class.create_for_project(non_existing_record_id, 'refs/heads/main', 'abc123')).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::KnowledgeGraph::CodeIndexingWorker, feature_category: :knowledge_graph do
  let_it_be(:project) { create(:project) }

  let(:worker) { described_class.new }
  let(:ref) { 'refs/heads/main' }
  let(:commit_sha) { 'abc123def456' }

  describe '#perform' do
    subject(:perform) { worker.perform(project.id, ref, commit_sha) }

    before do
      stub_feature_flags(knowledge_graph_infra: true)
      create(:knowledge_graph_enabled_namespace, namespace: project.root_ancestor)
    end

    it 'creates a CodeIndexingTask' do
      expect { perform }.to change { Analytics::KnowledgeGraph::CodeIndexingTask.count }.by(1)

      task = Analytics::KnowledgeGraph::CodeIndexingTask.last
      expect(task.project_id).to eq(project.id)
      expect(task.ref).to eq(ref)
      expect(task.commit_sha).to eq(commit_sha)
      expect(task.traversal_path).to eq(project.project_namespace.traversal_path(with_organization: true))
    end

    context 'when the knowledge_graph_infra feature flag is disabled' do
      before do
        stub_feature_flags(knowledge_graph_infra: false)
      end

      it 'does not create a CodeIndexingTask' do
        expect { perform }.not_to change { Analytics::KnowledgeGraph::CodeIndexingTask.count }
      end
    end

    context 'when the project does not exist' do
      subject(:perform) { worker.perform(non_existing_record_id, ref, commit_sha) }

      it 'does not create a CodeIndexingTask' do
        expect { perform }.not_to change { Analytics::KnowledgeGraph::CodeIndexingTask.count }
      end
    end
  end
end

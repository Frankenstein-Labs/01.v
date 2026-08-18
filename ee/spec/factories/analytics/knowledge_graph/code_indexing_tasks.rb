# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_graph_code_indexing_task, class: '::Analytics::KnowledgeGraph::CodeIndexingTask' do
    project
    ref { 'refs/heads/main' }
    commit_sha { SecureRandom.hex(20) }
    traversal_path { project.project_namespace.traversal_path(with_organization: true) }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_graph_enabled_namespace, class: '::Analytics::KnowledgeGraph::EnabledNamespace' do
    namespace { association(:namespace) }
  end
end

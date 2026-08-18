# frozen_string_literal: true

FactoryBot.define do
  factory :namespace_cluster_agent_mapping,
    class: 'RemoteDevelopment::NamespaceClusterAgentMapping' do
    user
    agent factory: [:cluster_agent, :in_group]
    namespace { agent.project.namespace }
  end
end

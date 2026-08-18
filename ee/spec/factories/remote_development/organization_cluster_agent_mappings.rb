# frozen_string_literal: true

FactoryBot.define do
  factory :organization_cluster_agent_mapping,
    class: 'RemoteDevelopment::OrganizationClusterAgentMapping' do
    user
    agent factory: [:cluster_agent, :in_group]
    organization { agent.project.organization }
  end
end

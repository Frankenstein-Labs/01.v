# frozen_string_literal: true

FactoryBot.define do
  factory :ee_cluster_agent, class: 'Clusters::Agent', parent: :cluster_agent do
    trait :with_existing_workspaces_agent_config do
      unversioned_latest_workspaces_agent_config factory: :workspaces_agent_config
    end
  end
end

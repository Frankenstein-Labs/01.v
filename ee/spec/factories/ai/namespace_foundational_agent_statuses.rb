# frozen_string_literal: true

FactoryBot.define do
  factory :namespace_foundational_agent_statuses, class: 'Ai::NamespaceFoundationalAgentStatus' do
    association :namespace, factory: :namespace
    reference { 'security_analyst_agent' }
    enabled { true }
  end
end

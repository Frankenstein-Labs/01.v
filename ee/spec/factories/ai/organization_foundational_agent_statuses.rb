# frozen_string_literal: true

FactoryBot.define do
  factory :organization_foundational_agents_status, class: 'Ai::OrganizationFoundationalAgentStatus' do
    organization(factory: :organization)

    reference { 'security_analyst_agent' }
    enabled { true }
  end
end

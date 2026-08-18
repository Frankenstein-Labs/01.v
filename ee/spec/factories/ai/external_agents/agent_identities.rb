# frozen_string_literal: true

FactoryBot.define do
  factory :ai_agent_identity, class: 'Ai::ExternalAgents::AgentIdentity' do
    user
    project
    agent_type { 'claude-code' }
    machine_fingerprint { SecureRandom.hex(32) }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_ai_audit_event, class: 'AuditEvents::AiAuditEvent' do
    transient do
      user { association(:user) }
      target_project { association(:project) }
    end

    cloud_event_id { SecureRandom.uuid }
    author_id { user.id }
    project_id { target_project.id }
    created_at { Time.current }
    event_name { 'ai_agent_session_started' }
    ip_address { IPAddr.new('127.0.0.1') }
    workflow_id { 1 }
    details do
      {
        session_id: 'session-abc123',
        agent_id: 'duo-workflow'
      }
    end
  end
end

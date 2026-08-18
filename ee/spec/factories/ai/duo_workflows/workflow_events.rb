# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_event, class: 'Ai::DuoWorkflows::Event' do
    workflow { association(:duo_workflows_workflow) }
    event_type { 'pause' }
    event_status { 'queued' }
    correlation_id_value { nil }
  end
end

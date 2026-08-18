# frozen_string_literal: true

FactoryBot.define do
  factory :cd_application_flow_definition, class: 'Cd::ApplicationFlowDefinition' do
    application { association(:cd_application) }
    # Smallest valid document: steps must be non-empty, and a wait needs no environment.
    definition { "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n" }
  end
end

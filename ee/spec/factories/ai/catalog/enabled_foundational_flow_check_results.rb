# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_enabled_foundational_flow_check_result,
    class: 'Ai::Catalog::EnabledFoundationalFlowCheckResult' do
    organization { association(:common_organization) }
    enabled_foundational_flow { association(:ai_catalog_enabled_foundational_flow, :for_namespace) }
    check_id { 1 }
    status { :success }
    message { 'Check passed' }

    trait :failed do
      status { :failure }
      message { 'Check failed' }
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_code_enabled_namespace, class: 'Ai::ActiveContext::Code::EnabledNamespace' do
    namespace factory: :group
    association :active_context_connection, factory: [:ai_active_context_connection, :inactive]

    trait :ready do
      state { :ready }
    end
  end
end

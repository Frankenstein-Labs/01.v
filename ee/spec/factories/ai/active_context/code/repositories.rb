# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_code_repository, class: 'Ai::ActiveContext::Code::Repository' do
    association :project
    association :enabled_namespace, factory: :ai_active_context_code_enabled_namespace
    connection_id { enabled_namespace.connection_id }

    trait :ready do
      state { :ready }
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_collection, class: 'Ai::ActiveContext::Collection' do
    name { ActiveContextHelpers.code_collection_name }
    association :connection, factory: [:ai_active_context_connection, :elasticsearch]

    trait :code_collection do
      name { ActiveContextHelpers.code_collection_name }
      collection_class { "Ai::ActiveContext::Collections::Code" }
      include_ref_fields { false }
      chunk_strategy { 'code_bytes' }
      chunk_strategy_size { 1000 }
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :namespace_ai_settings, class: '::Ai::NamespaceSetting' do
    namespace
  end
end

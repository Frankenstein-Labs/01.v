# frozen_string_literal: true

FactoryBot.define do
  factory :ai_settings, class: '::Ai::Setting' do
    organization
  end
end

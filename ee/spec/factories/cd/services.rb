# frozen_string_literal: true

FactoryBot.define do
  factory :cd_service, class: 'Cd::Service' do
    association :application, factory: :cd_application
    sequence(:name) { |n| "service-#{n}" }
  end
end

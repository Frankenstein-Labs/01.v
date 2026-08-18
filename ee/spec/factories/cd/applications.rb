# frozen_string_literal: true

FactoryBot.define do
  factory :cd_application, class: 'Cd::Application' do
    organization
    sequence(:name) { |n| "application-#{n}" }
  end
end

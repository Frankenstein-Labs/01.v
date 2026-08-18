# frozen_string_literal: true

FactoryBot.define do
  factory :cd_application_link, class: 'Cd::ApplicationLink' do
    application { association(:cd_application) }
    sequence(:name) { |n| "Application link #{n}" }
    sequence(:url) { |n| "https://example.com/link-#{n}" }
    link_type { :other }
  end
end

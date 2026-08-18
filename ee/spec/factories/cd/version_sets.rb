# frozen_string_literal: true

FactoryBot.define do
  factory :cd_version_set, class: 'Cd::VersionSet' do
    application { association(:cd_application) }
    sequence(:name) { |n| "release-#{n}" }
  end
end

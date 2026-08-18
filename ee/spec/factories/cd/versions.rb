# frozen_string_literal: true

FactoryBot.define do
  factory :cd_version, class: 'Cd::Version' do
    association :artifact_source, factory: :cd_artifact_source
    sequence(:name) { |n| "v1_0_#{n}" }
  end
end

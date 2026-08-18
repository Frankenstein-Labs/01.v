# frozen_string_literal: true

FactoryBot.define do
  factory :cd_rollout, class: 'Cd::Rollout' do
    version_set { association(:cd_version_set) }
    application { version_set.application }
    state { :pending }
  end
end

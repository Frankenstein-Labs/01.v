# frozen_string_literal: true

FactoryBot.define do
  factory :ci_hosted_runner, class: 'Ci::HostedRunner' do
    runner factory: :ci_runner
  end
end

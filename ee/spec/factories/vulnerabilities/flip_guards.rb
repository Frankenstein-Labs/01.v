# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_flip_guard, class: 'Vulnerabilities::FlipGuard' do
    association :finding, factory: :vulnerabilities_finding
    automated_transition_count { 1 }
    first_automatic_transition_at { 1.day.ago }
    last_automatic_transition_at { Time.current }
    is_guarded { false }

    after(:build) do |flip_guard, _|
      flip_guard.project ||= flip_guard.finding&.project
    end
  end
end

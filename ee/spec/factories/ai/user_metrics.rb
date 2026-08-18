# frozen_string_literal: true

FactoryBot.define do
  factory :ai_user_metrics, class: 'Ai::UserMetrics' do
    user
    last_duo_activity_on { Time.zone.today }
  end
end

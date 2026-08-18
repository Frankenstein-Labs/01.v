# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_seat_assignment, class: 'GitlabSubscriptions::SeatAssignment' do
    namespace { association(:group) }
    organization { association(:organization, :default) }
    user

    trait :active do
      last_activity_on { 1.day.ago }
    end

    trait :dormant do
      last_activity_on { 91.days.ago }
    end
  end
end

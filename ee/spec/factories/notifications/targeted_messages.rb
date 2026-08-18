# frozen_string_literal: true

FactoryBot.define do
  factory :targeted_message, class: 'Notifications::TargetedMessage' do
    target_type { :banner_page_level }
    starts_at { 1.hour.from_now }
    ends_at { 2.hours.from_now }

    namespaces { [association(:namespace)] }
  end
end

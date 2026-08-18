# frozen_string_literal: true

FactoryBot.define do
  factory :targeted_message_dismissal, class: 'Notifications::TargetedMessageDismissal' do
    targeted_message
    user
    namespace
  end
end

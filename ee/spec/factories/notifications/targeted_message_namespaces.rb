# frozen_string_literal: true

FactoryBot.define do
  factory :targeted_message_namespace, class: 'Notifications::TargetedMessageNamespace' do
    targeted_message
    namespace
  end
end

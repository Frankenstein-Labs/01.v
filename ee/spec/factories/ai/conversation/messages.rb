# frozen_string_literal: true

FactoryBot.define do
  factory :ai_conversation_message, class: '::Ai::Conversation::Message' do
    thread { association :ai_conversation_thread }
    role { :user }
    content { 'Message content' }
    message_xid { SecureRandom.uuid }
    extras { {}.to_json }
    error_details { [].to_json }

    trait :assistant do
      role { 'assistant' }
    end
  end
end

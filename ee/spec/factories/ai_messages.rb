# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :ai_message, class: 'Gitlab::Llm::AiMessage' do
    id { nil }
    association :user
    role { 'user' }
    request_id { SecureRandom.uuid }
    content { 'user message' }
    timestamp { Time.current }
    extras { nil }
    errors { nil }
    ai_action { :explain_code }
    client_subscription_id { nil }
    type { nil }
    chunk_id { nil }
    thread { nil }
    add_attribute(:context) { {} }

    transient do
      resource { nil }
      user_agent { nil }
    end

    initialize_with do
      context[:resource] = resource if resource
      context[:user_agent] = user_agent if user_agent

      new(
        id: id,
        role: role,
        user: user,
        request_id: request_id,
        content: content,
        timestamp: timestamp,
        extras: extras,
        errors: errors,
        ai_action: ai_action,
        client_subscription_id: client_subscription_id,
        context: Gitlab::Llm::AiMessageContext.new(context),
        type: type,
        chunk_id: chunk_id
      )
    end

    trait :explain_code do
      ai_action { :explain_code }
    end

    trait :explain_vulnerability do
      ai_action { :explain_vulnerability }
    end

    trait :resolve_vulnerability do
      ai_action { :resolve_vulnerability }
    end

    trait :summarize_new_merge_request do
      ai_action { :summarize_new_merge_request }
    end

    trait :generate_commit_message do
      ai_action { :generate_commit_message }
    end

    trait :summarize_review do
      ai_action { :summarize_review }
    end

    trait :generate_description do
      ai_action { :generate_description }
    end

    trait :measure_comment_temperature do
      ai_action { :measure_comment_temperature }
    end

    trait :tanuki_bot do
      ai_action { :tanuki_bot }
    end

    trait :summarize_comments do
      ai_action { :summarize_comments }
    end

    trait :categorize_question do
      ai_action { :categorize_question }
    end

    trait :assistant do
      role { 'assistant' }
    end

    trait :review_merge_request do
      ai_action { :review_merge_request }
    end

    trait :feature_discovery_search do
      ai_action { :feature_discovery_search }
    end

    skip_create

    factory :ai_chat_message, class: 'Gitlab::Llm::ChatMessage' do
      ai_action { :chat }

      to_create(&:save!)
    end
  end
end

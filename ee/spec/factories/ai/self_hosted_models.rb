# frozen_string_literal: true

FactoryBot.define do
  factory :ai_self_hosted_model, class: '::Ai::SelfHostedModel' do
    endpoint { 'http://localhost:11434/v1' }
    model { :mistral }
    provider { :api }
    name { 'mistral-7b-ollama-api' }
    api_token { 'token' }
    identifier { 'provider/some-model' }

    trait :embedding do
      model { :embedding }
    end

    trait :general do
      model { :general }
    end
  end
end

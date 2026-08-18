# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_flow_callback_hook, class: 'Ai::DuoWorkflows::FlowCallbackHook' do
    url { generate(:url) }
    organization { association(:organization) }
    filter { {} }

    trait :token do
      token { generate(:token) }
    end

    trait :signing_token do
      signing_token { "whsec_#{Base64.strict_encode64(SecureRandom.bytes(32))}" }
    end
  end
end

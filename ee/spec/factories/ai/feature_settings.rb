# frozen_string_literal: true

FactoryBot.define do
  factory :ai_feature_setting, class: '::Ai::FeatureSetting' do
    add_attribute(:feature) { :code_generations }
    provider { :self_hosted }
    self_hosted_model { provider.to_sym == :self_hosted ? association(:ai_self_hosted_model) : nil }

    trait :review_merge_request do
      add_attribute(:feature) { :review_merge_request }
    end

    trait :review_merge_request_dap do
      add_attribute(:feature) { :review_merge_request_dap }
    end

    trait :duo_agent_platform do
      add_attribute(:feature) { :duo_agent_platform }
    end

    trait :sast_vulnerability_fp_detection do
      add_attribute(:feature) { :sast_vulnerability_fp_detection }
    end

    trait :secret_vulnerability_fp_detection do
      add_attribute(:feature) { :secret_vulnerability_fp_detection }
    end

    trait :sast_vulnerability_resolution do
      add_attribute(:feature) { :sast_vulnerability_resolution }
    end

    trait :security_review do
      add_attribute(:feature) { :security_review }
    end

    trait :resolve_dependency_bump do
      add_attribute(:feature) { :resolve_dependency_bump }
    end
  end
end

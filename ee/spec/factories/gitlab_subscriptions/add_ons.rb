# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_add_on, class: 'GitlabSubscriptions::AddOn' do
    name { GitlabSubscriptions::AddOn.names[:code_suggestions] }
    description { GitlabSubscriptions::AddOn.descriptions[:code_suggestions] }

    trait :product_analytics do
      name { GitlabSubscriptions::AddOn.names[:product_analytics] }
      description { GitlabSubscriptions::AddOn.descriptions[:product_analytics] }
    end

    trait :duo_core do
      name { GitlabSubscriptions::AddOn.names[:duo_core] }
      description { GitlabSubscriptions::AddOn.descriptions[:duo_core] }
    end

    trait :duo_pro do
      name { GitlabSubscriptions::AddOn.names[:code_suggestions] }
      description { GitlabSubscriptions::AddOn.descriptions[:code_suggestions] }
    end

    trait :duo_enterprise do
      name { GitlabSubscriptions::AddOn.names[:duo_enterprise] }
      description { GitlabSubscriptions::AddOn.descriptions[:duo_enterprise] }
    end

    trait :duo_amazon_q do
      name { GitlabSubscriptions::AddOn.names[:duo_amazon_q] }
      description { GitlabSubscriptions::AddOn.descriptions[:duo_amazon_q] }
    end

    trait :self_hosted_dap do
      name { GitlabSubscriptions::AddOn.names[:self_hosted_dap] }
      description { GitlabSubscriptions::AddOn.descriptions[:self_hosted_dap] }
    end

    trait :gitlab_credits do
      name { GitlabSubscriptions::AddOn.names[:gitlab_credits] }
      description { GitlabSubscriptions::AddOn.descriptions[:gitlab_credits] }
    end

    trait :secrets_manager do
      name { GitlabSubscriptions::AddOn.names[:secrets_manager] }
      description { GitlabSubscriptions::AddOn.descriptions[:secrets_manager] }
    end
  end
end

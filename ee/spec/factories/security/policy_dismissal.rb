# frozen_string_literal: true

FactoryBot.define do
  factory :policy_dismissal, class: 'Security::PolicyDismissal' do
    project
    merge_request
    security_policy
    user
    dismissal_types { Security::PolicyDismissal::DISMISSAL_TYPES.values.sample(2) }
    security_findings_uuids { [SecureRandom.uuid] }
    status { :open }

    trait :preserved do
      status { :preserved }
    end
  end
end

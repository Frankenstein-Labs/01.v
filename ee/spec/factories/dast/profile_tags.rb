# frozen_string_literal: true

FactoryBot.define do
  factory :dast_profile_tag, class: 'Dast::ProfileTag' do
    association :dast_profile, factory: :dast_profile
    association :tag, factory: :ci_tag

    project_id { dast_profile.project_id }
  end
end

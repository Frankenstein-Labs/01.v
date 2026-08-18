# frozen_string_literal: true

FactoryBot.define do
  factory :group_hook do
    url { generate(:url) }
    name { generate(:name) }
    description { "Description of #{name}" }
    filter { {} }

    group

    trait :url_variables do
      url_variables { { 'abc' => 'supers3cret', 'def' => 'foobar' } }
    end

    trait :token do
      token { generate(:token) }
    end

    trait :all_events_enabled do
      push_events { true }
      merge_requests_events { true }
      tag_push_events { true }
      repository_update_events { true }
      issues_events { true }
      confidential_issues_events { true }
      note_events { true }
      confidential_note_events { true }
      job_events { true }
      pipeline_events { true }
      project_events { true }
      wiki_page_events { true }
      releases_events { true }
      milestone_events { true }
      subgroup_events { true }
      emoji_events { true }
      resource_access_token_events { true }
      member_events { true }
      vulnerability_events { true }
      feature_flag_events { true }
      deployment_events { true }
    end
  end
end

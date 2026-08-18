# frozen_string_literal: true

FactoryBot.define do
  factory :security_project_tracked_context, class: 'Security::ProjectTrackedContext' do
    project
    sequence(:context_name) { |n| "feature-branch-#{n}" }
    context_type { :branch }
    is_default { false }
    state { Security::ProjectTrackedContext::STATES[:untracked] }

    trait :tracked do
      state { Security::ProjectTrackedContext::STATES[:tracked] }
    end

    trait :untracked do
      state { Security::ProjectTrackedContext::STATES[:untracked] }
    end

    trait :archiving do
      state { Security::ProjectTrackedContext::STATES[:archiving] }
    end

    trait :deleting do
      state { Security::ProjectTrackedContext::STATES[:deleting] }
    end

    trait :default do
      context_name { 'main' }
      is_default { true }
      state { Security::ProjectTrackedContext::STATES[:tracked] }
    end

    trait :tag do
      context_type { :tag }
      sequence(:context_name) { |n| "v1.#{n}.0" }
    end
  end
end

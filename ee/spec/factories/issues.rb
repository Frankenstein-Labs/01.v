# frozen_string_literal: true

FactoryBot.modify do
  factory :issue do
    trait :requirement do
      association :work_item_type, :requirement, factory: :work_item_system_defined_type
    end

    trait :objective do
      association :work_item_type, :objective, factory: :work_item_system_defined_type
    end

    trait :key_result do
      association :work_item_type, :key_result, factory: :work_item_system_defined_type
    end

    trait :test_case do
      association :work_item_type, :test_case, factory: :work_item_system_defined_type
    end

    trait :epic do
      association :work_item_type, :epic, factory: :work_item_system_defined_type
    end

    trait :published do
      after(:create) do |issue|
        issue.create_status_page_published_incident!
      end
    end

    trait :with_sla do
      issuable_sla
    end

    trait :with_synced_epic do
      project { nil }
      association :namespace, factory: :group
      association :author, factory: :user
      association :work_item_type, :epic, factory: :work_item_system_defined_type
      synced_epic do
        association(:epic,
          group: namespace,
          title: title,
          description: description,
          created_at: created_at,
          updated_at: updated_at,
          author: author,
          updated_by: updated_by,
          state: state,
          confidential: confidential
        )
      end

      after(:create) do |issue, _|
        issue.synced_epic.update!(iid: issue.iid, created_at: issue.created_at)
      end
    end

    transient do
      epic { nil }
      epic_issue_relative_position { nil }
    end

    after(:build) do |issue, evaluator|
      epic = evaluator.epic
      issue.epic = epic if epic.present?
    end

    # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- this is not a direct association of the factory created here
    after(:create) do |issue, evaluator|
      epic = evaluator.epic

      if epic.present?
        work_item_parent_link = create(:parent_link,
          work_item_id: issue.id,
          work_item_parent: epic.work_item,
          relative_position: evaluator.epic_issue_relative_position
        )

        issue.create_epic_issue!(
          epic: evaluator.epic,
          work_item_parent_link: work_item_parent_link,
          relative_position: evaluator.epic_issue_relative_position
        )
      end
    end
    # rubocop:enable RSpec/FactoryBot/StrategyInCallback
  end
end

FactoryBot.define do
  factory :requirement, parent: :issue do
    association :work_item_type, :requirement, factory: :work_item_system_defined_type
  end
end

FactoryBot.define do
  factory :quality_test_case, parent: :issue do
    association :work_item_type, :test_case, factory: :work_item_system_defined_type
  end
end

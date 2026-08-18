# frozen_string_literal: true

FactoryBot.define do
  factory :epic_issue, traits: [:with_parent_link] do
    transient do
      epic { nil }
      issue { nil }
    end

    relative_position { RelativePositioning::START_POSITION }

    trait :with_parent_link do
      work_item_parent_link do
        association(
          :parent_link,
          work_item_id: issue&.id || issue_id,
          relative_position: relative_position,
          work_item_parent: epic&.work_item
        )
      end
    end

    after(:build) do |epic_issue, evaluator|
      epic = evaluator.epic
      issue = evaluator.issue

      epic_issue.epic = case
                        when epic.present?
                          epic
                        when issue.present?
                          create(:epic, group: issue.project.group)
                        else
                          create(:epic)
                        end

      epic_issue.issue = issue.presence || create(:issue, project: create(:project, group: epic_issue.epic.group))

      # Update parent link relationships
      epic_issue.work_item_parent_link.work_item_parent = epic_issue.epic.work_item
      if epic_issue.issue.persisted?
        epic_issue.work_item_parent_link.work_item = WorkItem.find(epic_issue.issue.id)
      else
        work_item = WorkItem.new(epic_issue.issue.attributes)
        epic_issue.work_item_parent_link.work_item = work_item
      end
    end
  end
end

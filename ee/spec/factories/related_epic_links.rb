# frozen_string_literal: true

FactoryBot.define do
  factory :related_epic_link, class: 'Epic::RelatedEpicLink', traits: [:with_related_work_item_link] do
    source factory: :epic
    target factory: :epic

    trait :with_related_work_item_link do
      related_work_item_link do
        association(:work_item_link,
          source: source&.work_item,
          target: target&.work_item,
          link_type: link_type,
          created_at: created_at,
          updated_at: updated_at
        )
      end
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :epic, traits: [:has_internal_id, :with_synced_work_item, :with_work_item_parent] do
    title { generate(:title) }
    group
    author

    trait :use_fixed_dates do
      start_date { Date.new(2010, 1, 1) }
      start_date_fixed { Date.new(2010, 1, 1) }
      start_date_is_fixed { true }
      end_date { Date.new(2010, 1, 3) }
      due_date_fixed { Date.new(2010, 1, 3) }
      due_date_is_fixed { true }
    end

    trait :confidential do
      confidential { true }
    end

    trait :opened do
      state { :opened }
    end

    trait :closed do
      state { :closed }
      closed_at { Time.now }
    end

    factory :labeled_epic do
      transient do
        labels { [] }
      end

      after(:create) do |epic, evaluator|
        epic.update!(labels: evaluator.labels)
      end
    end

    trait :with_work_item_parent do
      work_item_parent_link do
        if parent
          association(:parent_link, work_item: work_item, work_item_parent: parent.work_item,
            relative_position: relative_position)
        end
      end
    end

    trait :with_synced_work_item do
      work_item do
        association(:work_item,
          :epic,
          project: nil,
          namespace: group,
          title: title,
          description: description,
          created_at: created_at,
          updated_at: updated_at,
          author: author,
          iid: iid,
          updated_by: updated_by,
          state: state,
          confidential: confidential,
          start_date: start_date,
          due_date: end_date
        )
      end
    end

    after(:create) do |epic, _|
      if epic.work_item
        epic.work_item.update_columns(
          created_at: epic.created_at,
          updated_at: epic.updated_at,
          relative_position: epic.id
        )
        # work_item association is saved first so it gets the lower iid, so we want to use that.
        # we also want to avoid altering the updated_at value, while setting the IID,
        # so we use `update_columns` instead of `update!`
        epic.update_columns(iid: epic.work_item.iid)
      end
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :elastic_reindexing_task, class: 'Search::Elastic::ReindexingTask' do
    state { :initial }
    in_progress { true }

    trait :with_subtask do
      subtasks { [association(:elastic_reindexing_subtask)] }
    end
  end

  factory :elasticsearch_reindexing_state do
    state { :in_progress }  # default state
    error_message { nil }   # default error message

    trait :initial do
      state { :initial }
    end

    trait :indexing_paused do
      state { :indexing_paused }
    end

    trait :reindexing do
      state { :reindexing }
    end

    trait :success do
      state { :success }
    end

    trait :failure do
      state { :failure }
      error_message { "An error occurred" }
    end

    trait :original_index_deleted do
      state { :original_index_deleted }
    end
  end
end

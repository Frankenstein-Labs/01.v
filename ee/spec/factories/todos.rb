# frozen_string_literal: true

FactoryBot.modify do
  factory :todo do
    trait :duo_pro_access do
      action { Todo::DUO_PRO_ACCESS_GRANTED }
      target { user }
    end

    trait :duo_enterprise_access do
      action { Todo::DUO_ENTERPRISE_ACCESS_GRANTED }
      target { user }
    end

    trait :duo_core_access do
      action { Todo::DUO_CORE_ACCESS_GRANTED }
      target { user }
    end

    trait :merge_train_removed do
      action { Todo::MERGE_TRAIN_REMOVED }
    end

    trait :duo_workflow_input_required do
      action { Todo::DUO_WORKFLOW_INPUT_REQUIRED }
      target { association(:duo_workflows_workflow) }
    end
  end
end

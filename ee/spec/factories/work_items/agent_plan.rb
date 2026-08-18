# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_agent_plan, class: 'WorkItems::AgentPlan' do
    transient do
      work_item { nil }
    end

    content { 'Sample agent plan content' }
    ai_planning_enabled { false }

    after(:build) do |agent_plan, evaluator|
      agent_plan.work_item = evaluator.work_item if evaluator.work_item

      unless agent_plan.work_item
        agent_plan.work_item = create(:work_item) # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- needed for the association

        agent_plan.namespace = agent_plan.work_item.namespace
      end
    end
  end
end

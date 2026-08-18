# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_weights_source, class: 'WorkItems::WeightsSource' do
    association :work_item
    namespace { work_item&.namespace }
  end
end

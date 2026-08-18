# frozen_string_literal: true

FactoryBot.define do
  factory :color, class: 'WorkItems::Color' do
    color { '#1068bf' }
    association :work_item, :epic
  end
end

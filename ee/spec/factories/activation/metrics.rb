# frozen_string_literal: true

FactoryBot.define do
  factory :activation_metric, class: 'Activation::Metric' do
    user
    namespace
    metric { :merged_mr }
  end
end

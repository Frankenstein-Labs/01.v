# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_namespace_statistic, class: 'Vulnerabilities::NamespaceStatistic' do
    namespace

    after(:build) do |statistic, _|
      statistic.traversal_ids = statistic.namespace&.traversal_ids
    end
  end
end

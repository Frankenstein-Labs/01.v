# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_namespace_historical_statistic, class: 'Vulnerabilities::NamespaceHistoricalStatistic' do
    namespace
    letter_grade { 'a' }
    date { Date.current }

    after(:build) do |statistic, _|
      statistic.traversal_ids = statistic.namespace&.traversal_ids
    end
  end
end

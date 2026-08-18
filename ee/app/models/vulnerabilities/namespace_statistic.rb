# frozen_string_literal: true

module Vulnerabilities
  class NamespaceStatistic < ::SecApplicationRecord
    include ::Namespaces::Traversal::Traversable
    include EachBatch

    ignore_columns %i[age_average age_standard_deviation risk_score], remove_with: '18.8', remove_after: '2025-12-20'

    self.table_name = 'vulnerability_namespace_statistics'

    belongs_to :group, foreign_key: :namespace_id, inverse_of: :vulnerability_namespace_statistic, optional: false
    belongs_to :namespace
    validates :total, numericality: { greater_than_or_equal_to: 0 }
    validates :critical, numericality: { greater_than_or_equal_to: 0 }
    validates :high, numericality: { greater_than_or_equal_to: 0 }
    validates :medium, numericality: { greater_than_or_equal_to: 0 }
    validates :low, numericality: { greater_than_or_equal_to: 0 }
    validates :unknown, numericality: { greater_than_or_equal_to: 0 }
    validates :info, numericality: { greater_than_or_equal_to: 0 }
    validates :traversal_ids, presence: true

    scope :by_namespace, ->(namespace) { where(namespace: namespace) }
  end
end

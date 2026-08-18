# frozen_string_literal: true

module Ai
  class EventsCount < ApplicationRecord
    include PartitionedTable

    self.table_name = "ai_events_counts"

    # Ensure ActiveRecord generates queries correctly for partitioned table.
    self.primary_key = :id

    partitioned_by :events_date, strategy: :monthly, retain_for: 3.months

    enum :event, Ai::UsageEvent.events

    validates :user_id, :organization_id, :event, :events_date, :total_occurrences, presence: true
    validates :total_occurrences, numericality: { greater_than_or_equal_to: 0 }

    belongs_to :user
    belongs_to :namespace, optional: true
    belongs_to :organization, class_name: 'Organizations::Organization'

    scope :for_namespace, ->(namespace) {
      if namespace.group_namespace?
        cte = Gitlab::SQL::CTE.new(:namespace_cte, Namespace
          .project_namespaces
          .where("traversal_ids @> '{?}'", namespace.id)
          .select(:id)
        )

        with(cte.to_arel)
          .where("namespace_id IN (SELECT id FROM namespace_cte)")
      else
        where(namespace_id: namespace.id)
      end
    }

    scope :for_event, ->(event) { where(event: event) }
    scope :in_date_range, ->(from, to) { where(events_date: from..to) }

    def self.total_occurrences_for(namespace:, event:, from:, to:)
      for_namespace(namespace)
        .for_event(event)
        .in_date_range(from, to)
        .sum(:total_occurrences)
    end
  end
end

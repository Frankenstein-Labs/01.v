# frozen_string_literal: true

module Ai
  class FeatureAccessRule < ApplicationRecord
    include FeatureAccessRuleable

    self.table_name = 'ai_instance_accessible_entity_rules'

    belongs_to :through_namespace,
      class_name: 'Namespace',
      optional: true,
      inverse_of: :accessible_ai_features_on_instance

    validates :accessible_entity,
      uniqueness: { conditions: -> { where(through_namespace_id: nil) } },
      if: -> { through_namespace_id.nil? }

    scope :accessible_for_user, ->(user, accessible_entity) {
      group_based_ids = joins(
        "INNER JOIN members " \
          "ON members.source_id = ai_instance_accessible_entity_rules.through_namespace_id " \
          "AND members.source_type = 'Namespace'"
      ).where(accessible_entity: accessible_entity, members: { user_id: user.id }).select(:id)

      default_ids = where(accessible_entity: accessible_entity, through_namespace_id: nil).select(:id)

      where(id: group_based_ids).or(where(id: default_ids))
    }

    class << self
      def duo_namespace_access_rules
        group_by_through_namespace all
      end

      def duo_root_namespace_access_rules
        root_ns_rule_ids = joins(:through_namespace)
          .where(namespaces: { parent_id: nil, type: 'Group' })
          .select(:id)
        default_rule_ids = where(through_namespace_id: nil).select(:id)

        group_by_through_namespace(
          where(id: root_ns_rule_ids).or(where(id: default_rule_ids))
        )
      end

      def group_by_through_namespace(scope)
        scope
          .includes(:through_namespace)
          .order(Arel.sql('through_namespace_id NULLS FIRST'), :accessible_entity)
          .group_by(&:through_namespace_id)
      end

      def duo_namespace_access_rules=(values)
        values = values.map(&:deep_symbolize_keys).reject(&:blank?)

        delete_all

        return if values.empty?

        timestamp = Time.current
        rules = values.flat_map do |rule|
          features = rule[:features].reject(&:blank?)
          next [] if features.blank?

          through_namespace_id = rule.dig(:through_namespace, :id).presence

          features.map do |access_entity|
            new(
              through_namespace_id: through_namespace_id,
              accessible_entity: access_entity,
              created_at: timestamp,
              updated_at: timestamp
            )
          end
        end

        bulk_insert!(rules) if rules.any?
      end
    end
  end
end

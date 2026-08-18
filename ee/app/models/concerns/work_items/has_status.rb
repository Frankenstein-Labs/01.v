# frozen_string_literal: true

module WorkItems
  module HasStatus
    extend ActiveSupport::Concern

    included do
      has_one :current_status, class_name: 'WorkItems::Statuses::CurrentStatus',
        foreign_key: 'work_item_id', inverse_of: :work_item

      scope :with_status, ->(status, mapping = nil, status_roles: []) {
        relation = left_joins(:current_status)

        if status.is_a?(::WorkItems::Statuses::SystemDefined::Status)
          relation = with_system_defined_status(status)
        else
          matching_condition = { work_item_current_statuses: { custom_status_id: status.id } }

          if mapping.present?
            matching_condition[:work_item_type_id] = mapping.work_item_type_id

            if mapping.time_constrained?
              matching_condition[:work_item_current_statuses][:updated_at] = mapping.time_range
            end
          end

          relation = relation
            .where.not(work_item_current_statuses: { custom_status_id: nil })
            .where(matching_condition)

          build_role_relation = ->(role, work_item_type_id) {
            base_relation = case role.to_sym
                            when :open then opened
                            when :duplicate then closed.where.not(duplicated_to_id: nil)
                            when :closed then closed.where(duplicated_to_id: nil)
                            end
            base_relation.where(work_item_type_id: work_item_type_id).without_current_status
          }

          # The old status was a default status before so we include those items that
          # don't have a current status record and were created within the time range of the mapping.
          if mapping.present? && mapping.old_status_role.present?
            include_default = build_role_relation.call(mapping.old_status_role, mapping.work_item_type_id)
            include_default = include_default.where(created_at: mapping.time_range) if mapping.time_constrained?
            relation = relation.or(include_default)
          end

          status_roles.each do |role_definition|
            include_default = build_role_relation.call(role_definition[:role], role_definition[:work_item_type_id])
            relation = relation.or(include_default)
          end

          if status.converted_from_system_defined_status_identifier.present?
            system_defined_status = WorkItems::Statuses::SystemDefined::Status.find(
              status.converted_from_system_defined_status_identifier
            )

            relation = relation.or(with_system_defined_status(system_defined_status, mapping))
          end
        end

        relation
      }

      scope :with_system_defined_status, ->(status, mapping = nil) {
        return none unless status.is_a?(::WorkItems::Statuses::SystemDefined::Status)

        matching_condition = { work_item_current_statuses: { system_defined_status_id: status.id } }

        if mapping.present?
          matching_condition[:work_item_type_id] = mapping.work_item_type_id
          matching_condition[:work_item_current_statuses][:updated_at] = mapping.time_range if mapping.time_constrained?
        end

        relation = left_joins(:current_status)
                    .where.not(work_item_current_statuses: { system_defined_status_id: nil })
                    .where(matching_condition)

        return relation if mapping.present?

        lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first

        with_default_status = case status.id
                              when lifecycle.default_open_status_id
                                opened
                              when lifecycle.default_duplicate_status_id
                                closed.where.not(duplicated_to_id: nil)
                              when lifecycle.default_closed_status_id
                                closed.where(duplicated_to_id: nil)
                              end

        return relation if with_default_status.nil?

        relation.or(
          with_default_status.without_current_status.with_issue_type(lifecycle.work_item_base_types)
        )
      }

      scope :without_current_status, -> { left_joins(:current_status).where(work_item_current_statuses: { id: nil }) }

      scope :not_in_statuses, ->(statuses) {
        return all if statuses.blank?

        items_to_exclude = statuses.reduce(unscoped.none) do |relation, status|
          relation.or(with_status(status))
        end

        merge(items_to_exclude.invert_where)
      }

      scope :with_status_joins, -> {
        converted_statuses_join = <<-SQL.squish
          LEFT JOIN namespaces ON namespaces.id = #{table_name}.namespace_id
          LEFT JOIN work_item_custom_statuses converted_statuses ON
            converted_statuses.converted_from_system_defined_status_identifier =
              work_item_current_statuses.system_defined_status_id
            AND converted_statuses.namespace_id = namespaces.traversal_ids[1]
        SQL

        left_joins(current_status: :custom_status).joins(converted_statuses_join)
      }

      scope :order_status_asc, -> {
        with_status_joins.order(Arel.sql("#{generate_status_order_sql} ASC NULLS LAST, id DESC"))
      }

      scope :order_status_desc, -> {
        with_status_joins.order(Arel.sql("#{generate_status_order_sql} DESC NULLS FIRST, id DESC"))
      }

      def self.generate_status_order_sql
        system_defined_sort_orders = WorkItems::Statuses::SystemDefined::Status.sort_order_by_id
        system_defined_status_cases = system_defined_sort_orders.map do |id, category|
          "WHEN #{id} THEN #{category}"
        end.join(' ')

        lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first
        default_open_status = lifecycle.default_open_status
        default_duplicate_status = lifecycle.default_duplicate_status
        default_closed_status = lifecycle.default_closed_status

        default_open_sort_order = system_defined_sort_orders[default_open_status.id]
        default_duplicate_sort_order = system_defined_sort_orders[default_duplicate_status.id]
        default_closed_sort_order = system_defined_sort_orders[default_closed_status.id]

        opened_state_value = Issue.available_states[:opened]
        closed_state_value = Issue.available_states[:closed]

        mappings_exist_check = "EXISTS (
          SELECT 1 FROM work_item_custom_status_mappings WHERE namespace_id = namespaces.traversal_ids[1]
        )"

        custom_status_has_mapping_check = "EXISTS (
          SELECT 1 FROM work_item_custom_status_mappings
          WHERE old_status_id = work_item_current_statuses.custom_status_id
            AND work_item_type_id = #{table_name}.work_item_type_id
            AND namespace_id = namespaces.traversal_ids[1]
            AND (valid_from IS NULL OR valid_from <= work_item_current_statuses.updated_at)
            AND (valid_until IS NULL OR valid_until > work_item_current_statuses.updated_at)
        )"

        system_status_has_mapping_check = "EXISTS (
          SELECT 1 FROM work_item_custom_statuses inner_converted_statuses
          JOIN work_item_custom_status_mappings ON
            work_item_custom_status_mappings.old_status_id = inner_converted_statuses.id
          WHERE
            inner_converted_statuses.converted_from_system_defined_status_identifier =
              work_item_current_statuses.system_defined_status_id
            AND inner_converted_statuses.namespace_id = namespaces.traversal_ids[1]
            AND work_item_custom_status_mappings.work_item_type_id = #{table_name}.work_item_type_id
            AND work_item_custom_status_mappings.namespace_id =
              namespaces.traversal_ids[1]
            AND (work_item_custom_status_mappings.valid_from IS NULL OR
              work_item_custom_status_mappings.valid_from <= work_item_current_statuses.updated_at)
            AND (work_item_custom_status_mappings.valid_until IS NULL OR
              work_item_custom_status_mappings.valid_until > work_item_current_statuses.updated_at)
        )"

        <<-SQL.squish
          CASE
            WHEN work_item_current_statuses.custom_status_id IS NOT NULL THEN
              CASE
                WHEN #{mappings_exist_check} AND #{custom_status_has_mapping_check} THEN
                  (SELECT mapped_statuses.category
                  FROM work_item_custom_status_mappings
                  JOIN work_item_custom_statuses mapped_statuses ON mapped_statuses.id = work_item_custom_status_mappings.new_status_id
                  WHERE work_item_custom_status_mappings.old_status_id = work_item_current_statuses.custom_status_id
                    AND work_item_custom_status_mappings.work_item_type_id = #{table_name}.work_item_type_id
                    AND work_item_custom_status_mappings.namespace_id = namespaces.traversal_ids[1]
                    AND (work_item_custom_status_mappings.valid_from IS NULL OR work_item_custom_status_mappings.valid_from <= work_item_current_statuses.updated_at)
                    AND (work_item_custom_status_mappings.valid_until IS NULL OR work_item_custom_status_mappings.valid_until > work_item_current_statuses.updated_at)
                  LIMIT 1)
                ELSE
                  work_item_custom_statuses.category
              END
            WHEN work_item_current_statuses.system_defined_status_id IS NOT NULL THEN
              CASE
                WHEN #{mappings_exist_check} AND #{system_status_has_mapping_check} THEN
                  (SELECT mapped_statuses.category
                  FROM work_item_custom_statuses inner_converted_statuses
                  JOIN work_item_custom_status_mappings ON work_item_custom_status_mappings.old_status_id = inner_converted_statuses.id
                  JOIN work_item_custom_statuses mapped_statuses ON mapped_statuses.id = work_item_custom_status_mappings.new_status_id
                  WHERE inner_converted_statuses.converted_from_system_defined_status_identifier = work_item_current_statuses.system_defined_status_id
                    AND inner_converted_statuses.namespace_id = namespaces.traversal_ids[1]
                    AND work_item_custom_status_mappings.work_item_type_id = #{table_name}.work_item_type_id
                    AND work_item_custom_status_mappings.namespace_id = namespaces.traversal_ids[1]
                    AND (work_item_custom_status_mappings.valid_from IS NULL OR work_item_custom_status_mappings.valid_from <= work_item_current_statuses.updated_at)
                    AND (work_item_custom_status_mappings.valid_until IS NULL OR work_item_custom_status_mappings.valid_until > work_item_current_statuses.updated_at)
                  LIMIT 1)
                ELSE
                  COALESCE(
                    converted_statuses.category,
                    CASE work_item_current_statuses.system_defined_status_id #{system_defined_status_cases} END
                  )
              END
            ELSE
              CASE
                WHEN #{table_name}.state_id = #{opened_state_value} THEN #{default_open_sort_order}
                WHEN #{table_name}.state_id = #{closed_state_value} AND #{table_name}.duplicated_to_id IS NOT NULL
                  THEN #{default_duplicate_sort_order}
                WHEN #{table_name}.state_id = #{closed_state_value} AND #{table_name}.duplicated_to_id IS NULL
                  THEN #{default_closed_sort_order}
                ELSE #{default_open_sort_order}
              END
          END
        SQL
      end

      def status_with_fallback
        current_status_with_fallback&.status
      end

      def current_status_with_fallback
        return current_status if current_status.present?

        lifecycle = find_lifecycle
        return unless lifecycle

        default_status = lifecycle.default_status_for_work_item(self)
        return unless default_status

        if lifecycle.custom?
          build_current_status(custom_status: default_status, updated_at: created_at)
        else
          build_current_status(system_defined_status: default_status, updated_at: created_at)
        end
      end

      def find_lifecycle
        root_namespace_id = namespace&.traversal_ids&.first
        ::WorkItems::Statuses::Lifecycles::Provider.new(root_namespace_id).find_by_type(work_item_type)
      end
    end
  end
end

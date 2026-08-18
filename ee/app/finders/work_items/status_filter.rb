# frozen_string_literal: true

module WorkItems
  class StatusFilter < ::Issuables::BaseFilter
    include Gitlab::Utils::StrongMemoize

    def filter(issuables)
      return issuables unless can_filter_by_status?(issuables)

      statuses_for_filtering = find_statuses_for_filtering
      return issuables.none unless statuses_for_filtering.present?

      apply_status_filters(issuables, statuses_for_filtering)
    end

    private

    def can_filter_by_status?(issuables)
      status_param_present? && work_item_status_feature_available? &&
        issuables.respond_to?(:with_status)
    end

    def status_param_present?
      status_hash&.slice(:id, :name).present?
    end

    def work_item_status_feature_available?
      return License.feature_available?(:work_item_status) unless parent

      parent.root_ancestor&.licensed_feature_available?(:work_item_status)
    end

    def find_statuses_for_filtering
      requested_statuses = find_requested_status
      return [] unless requested_statuses.present?

      statuses = if requested_statuses.is_a?(Array)
                   requested_statuses.map { |status| { status: status, mapping: nil } }
                 else
                   [{ status: requested_statuses, mapping: nil }]
                 end

      all_mappings = []

      statuses.each do |status_mapping|
        status = status_mapping[:status]
        if status.is_a?(::WorkItems::Statuses::Custom::Status)
          mappings = find_statuses_mapping_to(status)
          all_mappings.concat(mappings) if mappings.present?
        end
      end

      statuses.concat(all_mappings).uniq
    end

    def find_requested_status
      status = status_hash[:id]
      status = find_status_by_name(status_hash[:name]) unless status.present?
      status
    end

    def find_status_by_name(name)
      return unless name.present?

      ::WorkItems::Statuses::Finder.new(root_ancestor, { 'name' => name }, current_user).execute
    end

    def find_statuses_mapping_to(status)
      return [] unless status.is_a?(::WorkItems::Statuses::Custom::Status)

      namespace = status.namespace
      return [] unless namespace

      mappings_to_status = load_cached_mappings(namespace).select { |m| m.new_status_id == status.id }
      return [] if mappings_to_status.empty?

      mappings_to_status.map do |mapping|
        {
          status: mapping.old_status,
          mapping: mapping
        }
      end
    end

    def load_cached_mappings(namespace)
      cache_key = "work_items:status_mappings_for_filter:#{namespace.id}"

      ::Gitlab::SafeRequestStore.fetch(cache_key) do
        ::WorkItems::Statuses::Custom::Mapping
          .with_namespace_id(namespace.id)
          .includes(:old_status) # rubocop:disable CodeReuse/ActiveRecord -- Preloading depends on the context
          .to_a
      end
    end

    def apply_status_filters(issuables, statuses_for_filtering)
      combined_relation = statuses_for_filtering.reduce(issuables.none) do |relation, status_mapping|
        # When it's the requested custom status, figure out whether it's a default status for
        # work item types, so we can also include items without a current status record.
        status_roles = status_mapping[:mapping].nil? ? build_status_roles(status_mapping[:status]) : []

        relation.or(
          issuables.with_status(status_mapping[:status], status_mapping[:mapping], status_roles: status_roles)
        )
      end

      # Excludes items that match direct status criteria but would be mapped to a different status
      exclude_items_mapped_away_from_direct_matches(combined_relation, statuses_for_filtering)
    end

    def build_status_roles(status)
      requested_work_item_types.filter_map do |work_item_type|
        build_status_role(work_item_type, status)
      end
    end

    def requested_work_item_types
      # We don't have to lookup default types if the param doesn't exist because
      # the frontend provides all supported types if we don't filter by type explicitly.
      return [] unless params[:issue_types].present?

      ::WorkItems::TypesFramework::Provider.new(parent).by_base_types(params[:issue_types])
    end

    def build_status_role(work_item_type, status)
      lifecycle = work_item_type.custom_lifecycle_for(root_ancestor&.id)
      return unless lifecycle

      role = lifecycle.role_for_status(status)
      return unless role.present?

      { role: role, work_item_type_id: work_item_type.id }
    end

    def exclude_items_mapped_away_from_direct_matches(relation, statuses_for_filtering)
      # Find all mappings that could transform items away from our target statuses
      # - old_status is one of our target statuses (or converts to one of our target statuses)
      # - new_status is NOT one of our target statuses
      statuses_for_filtering.each do |status_filter|
        target_status = status_filter[:status]
        next unless target_status.is_a?(::WorkItems::Statuses::Custom::Status)

        target_status_ids = statuses_for_filtering.map { |sf| sf[:status].id }
        all_relevant_mappings = load_all_relevant_mappings(statuses_for_filtering)

        conflicting_mappings = find_custom_status_conflicting_mappings(
          target_status, all_relevant_mappings, target_status_ids
        )

        conflicting_mappings.each do |mapping|
          relation = apply_mapping_exclusion_condition(relation, mapping, target_status)
        end
      end

      relation
    end

    def load_all_relevant_mappings(statuses_for_filtering)
      relevant_namespaces = statuses_for_filtering
        .filter_map { |sf| sf[:status].try(:namespace) }
        .uniq

      relevant_namespaces.flat_map do |namespace|
        load_cached_mappings(namespace)
      end
    end

    def find_custom_status_conflicting_mappings(target_status, all_relevant_mappings, target_status_ids)
      conflicting_mappings = []

      # Find direct mappings FROM this target status
      direct_mappings = all_relevant_mappings.select do |mapping|
        mapping.old_status_id == target_status.id &&
          target_status_ids.exclude?(mapping.new_status_id)
      end
      conflicting_mappings.concat(direct_mappings)

      # Find mappings from system-defined status this custom status was converted from
      if target_status.converted_from_system_defined_status_identifier.present?
        system_mappings = all_relevant_mappings.select do |mapping|
          mapping.old_status&.converted_from_system_defined_status_identifier ==
            target_status.converted_from_system_defined_status_identifier &&
            target_status_ids.exclude?(mapping.new_status_id)
        end
        conflicting_mappings.concat(system_mappings)
      end

      conflicting_mappings
    end

    # rubocop:disable CodeReuse/ActiveRecord -- context-specific dynamic logic
    def apply_mapping_exclusion_condition(relation, mapping, target_status)
      base_condition = { work_item_type_id: mapping.work_item_type_id }
      time_condition = mapping.time_constrained? ? { updated_at: mapping.time_range } : {}

      custom_condition = base_condition.merge(
        work_item_current_statuses: { custom_status_id: target_status.id }.merge(time_condition)
      )
      relation = relation.where.not(custom_condition)

      if target_status.converted_from_system_defined_status_identifier.present?
        system_condition = base_condition.merge(
          work_item_current_statuses: {
            system_defined_status_id: target_status.converted_from_system_defined_status_identifier
          }.merge(time_condition)
        )
        relation = relation.where.not(system_condition)
      end

      relation
    end
    # rubocop:enable CodeReuse/ActiveRecord

    def root_ancestor
      parent&.root_ancestor
    end

    def status_hash
      params[:status]&.to_h&.with_indifferent_access
    end
    strong_memoize_attr :status_hash
  end
end

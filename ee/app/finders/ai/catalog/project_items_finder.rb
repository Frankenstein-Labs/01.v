# frozen_string_literal: true

module Ai
  module Catalog
    # Finds AI catalog items for a specific project
    #
    # Arguments:
    #   current_user - User performing the search (required for feature flag and permission checks)
    #   project - Project to find AI catalog items for
    #   params - Hash containing search parameters:
    #     :all_available - Boolean, when true includes public items from the project's organization
    #     :item_types - Array of item types to filter by. E.g.: ['agent', 'flow']
    #     :enabled - Boolean, filters items by their enabled state in the project:
    #                - true: returns only enabled items
    #                - false: returns only disabled items
    #                - nil/blank: returns all items regardless of enabled state
    #     :search - String to search for in item name and description
    #
    # Returns ActiveRecord::Relation
    class ProjectItemsFinder
      def initialize(current_user, project, params: {})
        @current_user = current_user
        @project = project
        @params = params
      end

      def execute
        return Item.none unless Ability.allowed?(current_user, :read_ai_catalog_item, project)

        items = init_collection
        items = by_item_type(items)
        items = by_enabled_state(items)
        items = by_search(items)
        ordered(items)
      end

      private

      attr_reader :current_user, :project, :params

      def init_collection
        items = Item.not_deleted.for_project(project)

        return items unless params[:all_available]

        items.or(available_items_outside_project)
      end

      def available_items_outside_project
        base = Item.not_deleted.in_organization(project.organization)

        public_scope = base.visibility_public
        if restrict_to_group_hierarchy?
          public_scope = public_scope.within_group_hierarchy_or_foundational(root_ancestor)
        end

        return public_scope unless root_ancestor.is_a?(::Group)

        restricted_scope = base.restricted_within_group_hierarchy(project)
        public_scope.or(restricted_scope)
      end

      def restrict_to_group_hierarchy?
        root_ancestor.ai_catalog_restricted_to_group_hierarchy
      end

      def root_ancestor
        @root_ancestor ||= project.root_ancestor
      end

      def by_item_type(items)
        filtered_types = get_filtered_item_types

        return Ai::Catalog::Item.none if filtered_types.empty?
        return items if filtered_types == all_types

        items.with_item_type(filtered_types)
      end

      def by_enabled_state(items)
        return items if params[:enabled].nil?

        enabled_items = project.configured_ai_catalog_items.by_enabled(true)

        if params[:enabled]
          items.id_in(enabled_items.select(:ai_catalog_item_id))
        else
          items.id_not_in(enabled_items.select(:ai_catalog_item_id))
        end
      end

      def by_search(items)
        return items if params[:search].blank?

        items.search(params[:search])
      end

      def ordered(items)
        unless Item::SORT_SCOPES.key?(params[:sort])
          return items.visible_to_user_with_priority_ordering(current_user, allow_restricted: true)
        end

        items.sort_by_key(params[:sort])
      end

      def get_filtered_item_types
        types = params[:item_types].presence || all_types
        types.map!(&:to_sym)

        types -= [Ai::Catalog::Item::FLOW_TYPE] unless Ability.allowed?(current_user, :read_ai_catalog_flow, project)

        unless Ability.allowed?(current_user, :read_ai_catalog_third_party_flow, project)
          types -= [Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE]
        end

        types
      end

      def all_types
        Ai::Catalog::Item.item_types.keys
      end
    end
  end
end

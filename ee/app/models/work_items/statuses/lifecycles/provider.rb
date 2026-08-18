# frozen_string_literal: true

module WorkItems
  module Statuses
    module Lifecycles
      # Single source of truth for resolving the status lifecycle of a work item type
      # in a given namespace.
      #
      # A lifecycle is either an in-code system-defined lifecycle or a database-backed
      # custom lifecycle. The rule is: use the custom lifecycle attached to this type in
      # the namespace if one exists, otherwise fall back to the system-defined lifecycle.
      #
      # Expects a root namespace id. Custom lifecycles are keyed by root namespace, so
      # callers must pass the root namespace id (the id every existing caller already
      # resolves before calling). The custom lifecycles for that namespace are loaded
      # once, indexed by type, and cached in the request store so all types share the
      # same index within a request.
      class Provider
        def initialize(root_namespace_id)
          @root_namespace_id = root_namespace_id
        end

        def find_by_type(type)
          find_custom_by_type(type) || type.system_defined_lifecycle
        end

        def find_custom_by_type(type)
          return unless root_namespace_id

          index[type.persistable_id]
        end

        private

        attr_reader :root_namespace_id

        def index
          ::Gitlab::SafeRequestStore.fetch(cache_key) { build_index }
        end

        def cache_key
          "work_items_lifecycle_provider:#{root_namespace_id}"
        end

        def build_index
          type_custom_lifecycles.each_with_object({}) do |type_custom_lifecycle, memo|
            memo[type_custom_lifecycle.work_item_type_id] = type_custom_lifecycle.lifecycle
          end
        end

        def type_custom_lifecycles
          ::WorkItems::TypeCustomLifecycle
            .with_namespace_id(root_namespace_id)
            .includes(lifecycle: [
              :statuses, :default_open_status, :default_closed_status, :default_duplicate_status
            ])
        end
      end
    end
  end
end

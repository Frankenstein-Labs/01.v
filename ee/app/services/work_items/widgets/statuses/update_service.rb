# frozen_string_literal: true

module WorkItems
  module Widgets
    module Statuses
      class UpdateService
        include Gitlab::InternalEventsTracking

        def initialize(work_item, current_user, status = :default)
          @original = work_item
          @work_item = ensure_work_item(work_item)
          @current_user = current_user

          if status == :default
            @auto_transition = true
            @status = lifecycle&.default_status_for_work_item(@work_item)
          else
            @auto_transition = false
            @status = status
          end
        end

        def execute
          return unless status_in_lifecycle?

          # Check if current status explicit values are set. Using work_item.current_status.status would follow the
          # mappings resulting in potentially current_status.custom_status_id or current_status.system_defined_status_id
          # to continue to point to a value that needs to look up a mapping.
          current_status = work_item.current_status
          return if current_status&.custom_status == status
          return if current_status&.system_defined_status == status

          update_work_item_status
          sync_original_association
          create_system_note

          return if @auto_transition

          track_internal_event(
            'change_work_item_status_value',
            namespace: work_item.project&.namespace || work_item.namespace,
            project: work_item.project,
            user: current_user,
            additional_properties: {
              label: status.category.to_s
            }
          )
        end

        private

        attr_reader :work_item, :current_user, :status

        def status_in_lifecycle?
          status && lifecycle && lifecycle.has_status_id?(status.id)
        end

        def lifecycle
          @lifecycle ||= work_item.work_item_type.status_lifecycle_for(root_ancestor&.id)
        end

        def update_work_item_status
          current_status = work_item.current_status || work_item.build_current_status
          current_status.status = status

          current_status.save!
        end

        # `ensure_work_item` loads a fresh WorkItem instance when handed an Issue,
        # so the status is written to a different object than the caller holds.
        # Reset the caller's cached association so it re-reads the new value.
        # No-op when the caller passed the same object we wrote to (WorkItem
        # callers), which preserves the `previous_changes` their
        # `after_update_commit` callbacks depend on.
        def sync_original_association
          return if @original.equal?(work_item)
          return unless @original.respond_to?(:current_status)

          @original.association(:current_status).reset
        end

        def create_system_note
          return unless work_item.current_status.previous_changes.key?(:custom_status_id) ||
            work_item.current_status.previous_changes.key?(:system_defined_status_id)

          ::SystemNotes::IssuablesService.new(
            noteable: work_item,
            container: work_item.namespace,
            author: current_user
          ).change_work_item_status(work_item.current_status.status)
        end

        def root_ancestor
          work_item.resource_parent&.root_ancestor
        end

        def ensure_work_item(work_item)
          return work_item if work_item.is_a?(WorkItem)

          WorkItem.find_by_id(work_item) if work_item.is_a?(Issue)
        end
      end
    end
  end
end

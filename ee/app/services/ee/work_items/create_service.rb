# frozen_string_literal: true

module EE
  module WorkItems
    module CreateService
      extend ::Gitlab::Utils::Override
      include ::WorkItems::SyncAsEpic

      override :execute
      def execute(skip_system_notes: false)
        if params_include_state_and_status_changes?
          return error('State event and status widget cannot be changed at the same time', :bad_request)
        end

        super
      end

      private

      attr_reader :widget_params, :callbacks

      override :run_after_create_callbacks
      def run_after_create_callbacks(work_item)
        create_epic_for!(work_item) if work_item.group_epic_work_item?
        super
      end
    end
  end
end

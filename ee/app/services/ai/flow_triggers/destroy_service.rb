# frozen_string_literal: true

module Ai
  module FlowTriggers
    class DestroyService < BaseService
      def initialize(trigger:, current_user:)
        @trigger = trigger
        @current_user = current_user
      end

      def execute
        if @trigger.destroy
          audit_flow_trigger('flow_trigger_deleted', @trigger)
          ServiceResponse.success
        else
          ServiceResponse.error(message: 'Failed to delete the flow trigger')
        end
      end
    end
  end
end

# frozen_string_literal: true

module Analytics
  module CustomDashboards
    class UpdateService
      include Gitlab::Allowable

      def initialize(current_user:, dashboard:, params:)
        @current_user = current_user
        @dashboard = dashboard
        @params = params
      end

      def execute
        return error_response('Dashboard not found') unless @dashboard
        return error_response('You are not authorized to update this dashboard') unless can_update?

        if @dashboard.update(@params.merge(updated_by: @current_user))
          success_response
        else
          error_response(@dashboard.errors.full_messages)
        end
      end

      private

      def can_update?
        can?(@current_user, :update_custom_dashboard, @dashboard)
      end

      def success_response
        ServiceResponse.success(payload: { dashboard: @dashboard })
      end

      def error_response(message)
        ServiceResponse.error(message: message, payload: { dashboard: @dashboard })
      end
    end
  end
end

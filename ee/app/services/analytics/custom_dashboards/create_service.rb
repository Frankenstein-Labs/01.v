# frozen_string_literal: true

module Analytics
  module CustomDashboards
    class CreateService
      include ::Gitlab::Allowable

      def initialize(current_user:, organization:, params:)
        @current_user = current_user
        @organization = organization
        @params = params
      end

      def execute
        return authorization_error unless authorized?

        dashboard = ::Analytics::CustomDashboards::Dashboard.new(
          **params,
          organization: organization,
          created_by_id: current_user.id,
          updated_by_id: current_user.id
        )

        if dashboard.save
          ServiceResponse.success(payload: { dashboard: dashboard })
        else
          ServiceResponse.error(
            message: dashboard.errors.full_messages.to_sentence,
            payload: { errors: dashboard.errors.full_messages }
          )
        end
      end

      private

      attr_reader :current_user, :organization, :params

      def authorized?
        can?(current_user, :create_custom_dashboard, organization)
      end

      def authorization_error
        ServiceResponse.error(
          message: _('You are not authorized to create dashboards in this organization')
        )
      end
    end
  end
end

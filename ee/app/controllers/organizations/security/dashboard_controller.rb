# frozen_string_literal: true

module Organizations
  module Security
    class DashboardController < ::Organizations::ApplicationController
      feature_category :vulnerability_management
      urgency :low

      before_action :ensure_feature_enabled!
      before_action :authorize_read_security_resource!

      def show; end

      private

      def ensure_feature_enabled!
        render_404 unless Feature.enabled?(:organization_security_dashboard, organization)
      end

      def authorize_read_security_resource!
        render_404 unless can?(current_user, :read_security_resource, organization)
      end
    end
  end
end

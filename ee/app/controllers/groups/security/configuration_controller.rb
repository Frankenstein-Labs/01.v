# frozen_string_literal: true

module Groups
  module Security
    class ConfigurationController < Groups::ApplicationController
      layout 'group'

      before_action :authorize_security_configuration!

      feature_category :security_testing_configuration

      def show
        push_frontend_feature_flag(:security_inventory_filtering, group.root_ancestor)
        push_frontend_feature_flag(:security_scan_profiles_status_indicators, group.root_ancestor)
      end

      private

      def can_access_attributes?
        can?(current_user, :admin_security_attributes, group.root_ancestor) &&
          group.licensed_feature_available?(:security_attributes)
      end

      def can_access_scan_profiles?
        can?(current_user, :read_security_scan_profiles, group.root_ancestor) &&
          group.licensed_feature_available?(:security_scan_profiles)
      end

      def authorize_security_configuration!
        render_403 unless can_access_attributes? || can_access_scan_profiles?
      end
    end
  end
end

# frozen_string_literal: true

module Groups
  module AddOns
    class DiscoverDuoProController < Groups::ApplicationController
      before_action :authorize_discover_page

      feature_category :onboarding
      urgency :low

      def show
        render GitlabSubscriptions::DiscoverDuoProComponent.new(namespace: @group)
      end

      private

      def authorize_discover_page
        render_404 unless GitlabSubscriptions::Trials::DuoPro.show_duo_pro_discover?(@group, current_user)
      end
    end
  end
end

# frozen_string_literal: true

module Profiles
  class GitlabCreditsDashboardController < Profiles::ApplicationController
    before_action :ensure_feature_available!

    feature_category :consumables_cost_management
    urgency :low

    def index
      @hide_search_settings = true
      @group = eligible_group

      render_404 unless @group
    end

    private

    def ensure_feature_available!
      return render_404 unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      return render_404 unless ::Feature.enabled?(:user_gitlab_credits_dashboard, current_user)

      render_404 unless current_user.human?
    end

    def eligible_group
      group = current_user.user_preference.duo_default_namespace_with_fallback

      return unless group&.group_namespace?
      return unless group.root?
      return unless group.gitlab_credits_entitled?

      group
    end
  end
end

# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoCommon
      extend ActiveSupport::Concern

      include OneTrustCSP
      include GoogleAnalyticsCSP
      include ::Gitlab::Utils::StrongMemoize
      include SafeFormatHelper

      included do
        layout 'minimal'

        skip_before_action :set_confirm_warning

        before_action :check_feature_available!
        before_action :check_trial_eligibility!
      end

      private

      def set_group_name
        return unless namespace || GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)

        @group_name = (namespace || eligible_namespaces.first).name
      end

      def check_feature_available!
        render_404 unless ::Gitlab::Saas.feature_available?(:subscriptions_trials)
      end

      def check_trial_eligibility!
        return if eligible_for_trial?

        render 'gitlab_subscriptions/trials/duo/access_denied', status: :forbidden
      end

      def eligible_for_trial?
        eligible_namespaces.any? && namespace_in_params_eligible?
      end

      def namespace_in_params_eligible?
        GitlabSubscriptions::Trials.eligible_namespace?(general_params[:namespace_id], eligible_namespaces)
      end

      def namespace
        current_user.owned_groups.find_by_id(general_params[:namespace_id])
      end
      strong_memoize_attr :namespace

      def general_params
        params.permit(:namespace_id, :step)
      end

      def success_doc_link
        assign_doc_url = helpers.help_page_path(
          'subscriptions/subscription-add-ons.md', anchor: 'assign-gitlab-duo-seats'
        )
        assign_link = helpers.link_to('', assign_doc_url, target: '_blank', rel: 'noopener noreferrer')
        tag_pair(assign_link, :assign_link_start, :assign_link_end)
      end

      def track_event(action)
        Gitlab::InternalEvents
          .track_event(action, user: current_user, namespace: namespace || eligible_namespaces.first)
      end
    end
  end
end

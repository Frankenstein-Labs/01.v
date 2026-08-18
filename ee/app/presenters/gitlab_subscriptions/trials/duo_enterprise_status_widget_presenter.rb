# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoEnterpriseStatusWidgetPresenter < Gitlab::View::Presenter::Simple
      include Gitlab::Utils::StrongMemoize

      EXPIRED_TRIAL_WIDGET = 'expired_duo_enterprise_trial_widget'

      presents ::Namespace, as: :namespace

      def eligible_for_widget?
        return false unless GitlabSubscriptions::DuoEnterprise.namespace_plan_eligible?(namespace)

        duo_enterprise_status = GitlabSubscriptions::Trials::AddOnStatus.new(
          add_on_purchase: duo_enterprise_trial_add_on_purchase
        )

        duo_enterprise_status.show? && !user_dismissed_widget?
      end

      def attributes
        {
          trial_widget_data_attrs: {
            trial_type: 'duo_enterprise',
            trial_days_used: trial_status.days_used,
            days_remaining: trial_status.days_remaining,
            percentage_complete: trial_status.percentage_complete,
            group_id: namespace.id,
            trial_discover_page_path: group_add_ons_discover_duo_enterprise_path(namespace),
            purchase_now_url: subscription_portal_url,
            feature_id: EXPIRED_TRIAL_WIDGET
          }
        }
      end

      private

      def duo_enterprise_trial_add_on_purchase
        GitlabSubscriptions::Trials::DuoEnterprise.any_add_on_purchase_for_namespace(namespace)
      end
      strong_memoize_attr :duo_enterprise_trial_add_on_purchase

      def trial_status
        GitlabSubscriptions::TrialStatus.new(duo_enterprise_trial_add_on_purchase.started_at,
          duo_enterprise_trial_add_on_purchase.expires_on)
      end
      strong_memoize_attr :trial_status

      def user_dismissed_widget?
        user.dismissed_callout_for_group?(feature_name: EXPIRED_TRIAL_WIDGET, group: namespace)
      end
    end
  end
end

# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module GitlabCom
      class StatusWidgetPresenter < Gitlab::View::Presenter::Simple
        include Gitlab::Utils::StrongMemoize

        presents ::Namespace, as: :namespace

        EXPIRED_TRIAL_WIDGET = 'expired_trial_status_widget'

        def eligible_for_widget?
          eligible_trial_active? || eligible_expired_trial?
        end

        def attributes
          {
            trial_widget_data_attrs: {
              trial_type: 'ultimate_with_dap',
              trial_days_used: trial_status.days_used,
              days_remaining: trial_status.days_remaining,
              percentage_complete: trial_status.percentage_complete,
              group_id: namespace.id,
              trial_discover_page_path: group_discover_path(namespace),
              purchase_now_url: group_billings_path(namespace),
              feature_id: EXPIRED_TRIAL_WIDGET
            }
          }
        end

        private

        def eligible_trial_active?
          GitlabSubscriptions::Trials.namespace_plan_eligible_for_active?(namespace) &&
            namespace.gitlab_subscription_end_date.present? &&
            namespace.gitlab_subscription_end_date > Date.current
        end

        def eligible_expired_trial?
          !user_dismissed_widget? && trial_recently_expired?
        end

        def trial_recently_expired?
          # this does not cover the edge case that a premium namespace trailing ultimate becomes free around
          # the same time as trial expires, see https://gitlab.com/gitlab-org/gitlab/-/work_items/588952 for follow-up
          GitlabSubscriptions::Trials.recently_expired?(namespace)
        end
        strong_memoize_attr :trial_recently_expired?

        def trial_status
          if trial_recently_expired?
            GitlabSubscriptions::TrialStatus.new(namespace.trial_starts_on, namespace.trial_ends_on)
          else
            GitlabSubscriptions::TrialStatus.new(namespace.gitlab_subscription_start_date,
              namespace.gitlab_subscription_end_date)
          end
        end
        strong_memoize_attr :trial_status

        def user_dismissed_widget?
          user.dismissed_callout_for_group?(feature_name: EXPIRED_TRIAL_WIDGET, group: namespace)
        end
      end
    end
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/presenters/jh/gitlab_subscriptions/trials/status_widget_presenter.rb
GitlabSubscriptions::Trials::GitlabCom::StatusWidgetPresenter.prepend_mod

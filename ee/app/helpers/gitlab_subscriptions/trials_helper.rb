# frozen_string_literal: true

module GitlabSubscriptions
  module TrialsHelper
    def glm_source
      ::Gitlab.config.gitlab.host
    end

    def show_tier_badge_for_new_trial?(namespace, user)
      ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
        !namespace.paid? &&
        namespace.private? &&
        namespace.eligible_for_trial? &&
        can?(user, :read_billing, namespace)
    end

    def trial_duration
      GitlabSubscriptions::TrialDurationService.new.execute
    end

    private

    def support_link
      link_to('', Gitlab::Saas.customer_support_url, target: '_blank', rel: 'noopener noreferrer')
    end

    def errors_message(errors)
      support_message = _('Please reach out to %{support_link_start}GitLab Support%{support_link_end} for assistance')
      full_message = [support_message, errors.to_sentence.presence].compact.join(': ')

      "#{full_message}."
    end
  end
end

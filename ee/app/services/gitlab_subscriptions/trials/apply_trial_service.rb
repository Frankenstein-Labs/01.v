# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class ApplyTrialService < BaseApplyTrialService
      extend ::Gitlab::Utils::Override

      override :generate_trial
      def generate_trial
        response = execute_trial_request

        if response[:success]
          # We need to stick to an up to date replica or primary db here in order
          # to properly observe the add_on_purchase that CustomersDot created.
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/499720
          Namespace.sticking.find_caught_up_replica(:namespace, namespace.id)

          after_success_hook

          ServiceResponse.success
        else
          ServiceResponse.error(message: response.dig(:data, :errors), reason: GENERIC_TRIAL_ERROR)
        end
      end

      def valid_to_generate_trial?
        namespace.present? && GitlabSubscriptions::Trials.namespace_eligible?(namespace)
      end

      private

      def execute_trial_request
        trial_user_information.merge!(add_on_name: 'duo_enterprise', trial_type: trial_type)

        client.generate_trial(uid: uid, trial_user: trial_user_information)
      end

      def trial_type
        GitlabSubscriptions::Trials.trial_type_for_namespace(namespace)
      end

      def add_on_purchase_finder
        GitlabSubscriptions::Trials::DuoEnterprise
      end

      def after_success_hook
        ::Onboarding::ProgressService.new(namespace).execute(action: :trial_started)

        clear_dap_access_cache
      end

      def clear_dap_access_cache
        # Clear DAP access caches for the user who started the trial.
        # Other namespace members will get access when their cache expires.
        User.clear_group_with_ai_available_cache(uid)
      end
    end
  end
end

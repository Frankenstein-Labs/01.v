# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class ApplyDuoProService < ::GitlabSubscriptions::Trials::BaseApplyTrialService
      extend ::Gitlab::Utils::Override

      override :initialize
      def initialize(uid:, trial_user_information:)
        trial_user_information[:add_on_name] = 'code_suggestions'

        super
      end

      def valid_to_generate_trial?
        namespace.present? && GitlabSubscriptions::DuoPro.namespace_eligible?(namespace) &&
          GitlabSubscriptions::DuoPro.no_add_on_purchase_for_namespace?(namespace)
      end

      private

      def execute_trial_request
        client.generate_addon_trial(uid: uid, trial_user: trial_user_information)
      end

      def add_on_purchase_finder
        GitlabSubscriptions::Trials::DuoPro
      end
    end
  end
end

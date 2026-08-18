# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class BaseApplyTrialService
      include ::Gitlab::Utils::StrongMemoize

      GENERIC_TRIAL_ERROR = :generic_trial_error

      def self.execute(args = {})
        instance = new(**args)
        instance.execute
      end

      def initialize(uid:, trial_user_information:)
        @uid = uid
        @trial_user_information = trial_user_information
      end

      def execute
        if valid_to_generate_trial?
          generate_trial
        else
          ServiceResponse.error(message: 'Not valid to generate a trial with current information')
        end
      end

      def generate_trial
        response = execute_trial_request

        if response[:success]
          after_success_hook

          # We need to stick to an up to date replica or primary db here in order
          # to properly observe the add_on_purchase that CustomersDot created.
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/499720
          Namespace.sticking.find_caught_up_replica(:namespace, namespace.id)
          add_on_purchase = add_on_purchase_finder.any_add_on_purchase_for_namespace(namespace)
          assign_seat(add_on_purchase, user)

          ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
        else
          ServiceResponse.error(message: response.dig(:data, :errors), reason: GENERIC_TRIAL_ERROR)
        end
      end

      def valid_to_generate_trial?
        raise NoMethodError, "Subclasses must implement valid_to_generate_trial? method"
      end

      private

      attr_reader :uid, :trial_user_information

      def execute_trial_request
        raise NoMethodError, "Subclasses must implement execute_trial_request method"
      end

      def add_on_purchase_finder
        raise NoMethodError, 'Subclasses must implement add_on_purchase_finder method'
      end

      def client
        Gitlab::SubscriptionPortal::Client
      end

      def user
        User.find_by_id(uid)
      end
      strong_memoize_attr :user

      def namespace
        Namespace.find_by_id(trial_user_information[:namespace_id])
      end
      strong_memoize_attr :namespace

      def assign_seat(add_on_purchase, user)
        ::GitlabSubscriptions::UserAddOnAssignments::Saas::CreateWithoutNotificationService.new(
          add_on_purchase: add_on_purchase,
          user: user
        ).execute
      end

      def after_success_hook
        # overridden in subclasses
      end
    end
  end
end

GitlabSubscriptions::Trials::BaseApplyTrialService.prepend_mod

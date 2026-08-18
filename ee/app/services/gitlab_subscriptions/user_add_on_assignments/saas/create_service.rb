# frozen_string_literal: true

module GitlabSubscriptions
  module UserAddOnAssignments
    module Saas
      class CreateService < ::GitlabSubscriptions::UserAddOnAssignments::Saas::CreateWithoutNotificationService
        extend ::Gitlab::Utils::Override

        private

        override :after_success_hook
        def after_success_hook
          super

          duo_success_actions if duo_pro? || duo_enterprise?
        end

        def duo_success_actions
          enqueue_onboarding_progress_action
          create_iterable_trigger
        end

        def enqueue_onboarding_progress_action
          ::Onboarding::ProgressService.async(namespace.id, 'duo_seat_assigned')
        end

        def create_iterable_trigger
          ::Onboarding::CreateIterableTriggerWorker.perform_async(iterable_params)
        end

        def iterable_params
          ::Onboarding.add_on_seat_assignment_iterable_params(
            user,
            ::GitlabSubscriptions::AddOns::VARIANTS[add_on_purchase.add_on_name.to_sym][:product_interaction],
            namespace
          )
        end
      end
    end
  end
end

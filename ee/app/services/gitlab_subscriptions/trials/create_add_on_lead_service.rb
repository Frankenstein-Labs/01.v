# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class CreateAddOnLeadService
      def execute(company_params)
        response = client.generate_addon_trial_lead(company_params)

        if response[:success]
          ServiceResponse.success
        else
          error_message = response.dig(:data, :errors) || 'Submission failed'
          ServiceResponse.error(message: error_message, reason: :submission_failed)
        end
      end

      private

      def client
        Gitlab::SubscriptionPortal::Client
      end
    end
  end
end

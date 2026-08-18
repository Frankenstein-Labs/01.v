# frozen_string_literal: true

module GitlabSubscriptions
  class TrackCartAbandonmentCreditsPurchaseService
    def initialize(user:, namespace:, monthly_commitment_credits:)
      @user = user
      @namespace = namespace
      @monthly_commitment_credits = monthly_commitment_credits
    end

    def execute
      return ServiceResponse.error(message: 'User opt-in required to track credits purchase') unless user_opted_in?

      enqueue_worker

      ServiceResponse.success
    end

    private

    attr_reader :user, :namespace, :monthly_commitment_credits

    def user_opted_in?
      user.onboarding_status_email_opt_in
    end

    def enqueue_worker
      GitlabSubscriptions::CartAbandonmentCreditsPurchaseWorker.perform_in(
        3.hours,
        user.id,
        namespace.id,
        monthly_commitment_credits
      )
    end
  end
end

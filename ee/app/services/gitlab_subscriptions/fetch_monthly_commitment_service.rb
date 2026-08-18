# frozen_string_literal: true

module GitlabSubscriptions
  class FetchMonthlyCommitmentService
    def initialize(namespace_id:)
      @namespace_id = namespace_id
    end

    def execute
      client = ::Gitlab::SubscriptionPortal::SubscriptionUsageClient.new(namespace_id: @namespace_id)
      response = client.get_monthly_commitment

      return ServiceResponse.success(payload: { total_credits: 0 }) unless response[:success]

      total_credits = response.dig(:monthlyCommitment, :totalCredits) || 0

      ServiceResponse.success(payload: { total_credits: total_credits })
    end
  end
end

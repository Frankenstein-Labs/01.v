# frozen_string_literal: true

module Types
  module Ai
    class CreditsDenialReasonEnum < BaseEnum
      graphql_name 'AiCreditsDenialReason'
      description 'Reason GitLab credits are unavailable.'

      value 'USAGE_BILLING_FORBIDDEN',
        description: 'Usage billing is not available for the account.',
        value: 'usage_billing_forbidden'
    end
  end
end

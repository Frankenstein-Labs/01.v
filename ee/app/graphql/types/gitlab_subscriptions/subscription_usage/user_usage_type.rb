# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    module SubscriptionUsage
      class UserUsageType < BaseObject
        graphql_name 'GitlabSubscriptionUsageUserUsage'
        description 'Describes the usage of consumables for a user under the subscription'

        authorize :read_user

        field :credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'GitLab Credits used by the user.'
        # rubocop: disable GraphQL/ExtractType -- different types of usage that start with monthly_
        field :monthly_commitment_credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Monthly Commitment GitLab Credits used by the user.'
        field :monthly_waiver_credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Monthly Waiver GitLab Credits used by the user.'
        # rubocop: enable GraphQL/ExtractType
        field :overage_credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Overage GitLab Credits used by the user.'
        field :paid_tier_trial_credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Paid Tier Trial GitLab Credits used by the user.'
        # rubocop: disable GraphQL/ExtractType -- these are different totals
        field :total_credits,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Total GitLab Credits available for the user.'
        field :total_credits_used,
          type: GraphQL::Types::Float,
          null: true,
          description: 'Total GitLab Credits used by the user across all wallets.'
        # rubocop: enable GraphQL/ExtractType
      end
    end
  end
end

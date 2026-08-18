# frozen_string_literal: true

module Types
  module SecretsManagement
    # rubocop:disable Graphql/AuthorizeTypes -- authorize is enforced at the field level on GroupType
    class EntitlementType < BaseObject
      graphql_name 'SecretsManagerEntitlement'
      description 'Secrets Manager entitlement for a top-level group.'

      authorize_granular_token permissions: :read_secrets_manager,
        boundary: :group,
        boundary_type: :group

      Adapter = Struct.new(:entitlement, :group, keyword_init: true) do
        delegate :state, :blocked_reason, :trial_started_at, :trial_expires_at,
          :credits_remaining, :credits_total, :on_demand_enabled, to: :entitlement
      end

      field :state, ::Types::SecretsManagement::EntitlementStateEnum,
        null: false,
        description: 'Resolved entitlement state.',
        experiment: { milestone: '19.2' }

      field :blocked_reason, ::Types::SecretsManagement::EntitlementBlockedReasonEnum,
        null: true,
        description: 'Reason the entitlement is blocked; null when state is not BLOCKED.',
        experiment: { milestone: '19.2' }

      # rubocop:disable GraphQL/ExtractType -- these are intentionally top-level fields
      field :trial_started_at, ::Types::TimeType,
        null: true,
        description: 'Timestamp when the Secrets Manager trial started.',
        experiment: { milestone: '19.2' }

      field :trial_expires_at, ::Types::TimeType,
        null: true,
        description: 'Timestamp when the Secrets Manager trial expires.',
        experiment: { milestone: '19.2' }

      field :credits_remaining, GraphQL::Types::Int,
        null: true,
        description: 'Number of trial credits remaining.',
        experiment: { milestone: '19.2' }

      field :credits_total, GraphQL::Types::Int,
        null: true,
        description: 'Initial trial credit allocation for the current trial period.',
        experiment: { milestone: '19.2' }
      # rubocop:enable GraphQL/ExtractType

      field :on_demand_enabled, GraphQL::Types::Boolean,
        null: true,
        description: 'Indicates whether on-demand purchasing is enabled for the namespace.',
        experiment: { milestone: '19.2' }
    end
    # rubocop:enable Graphql/AuthorizeTypes
  end
end

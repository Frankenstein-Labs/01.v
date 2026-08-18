# frozen_string_literal: true

module Mutations
  module GitlabSubscriptions
    module BudgetCaps
      class UpsertFlatUserCap < BaseMutation
        graphql_name 'UpsertFlatUserCap'

        authorize_granular_token permissions: :update_subscription_usage_cap,
          boundaries: [
            { boundary_argument: :namespace_path, boundary_type: :group },
            { boundary: :instance, boundary_type: :instance }
          ]

        include ResolvesSubscriptionTarget

        description 'Update the flat per-user budget cap for a subscription.'

        argument :namespace_path, GraphQL::Types::String,
          required: false,
          description: 'Path of the top-level group namespace. ' \
            'Omit for self-managed instance scope.'

        argument :flat_user_cap, GraphQL::Types::Float,
          required: true,
          validates: { numericality: { greater_than_or_equal_to: 0 } },
          description: 'Default per-user budget cap applied to all users.'

        argument :flat_user_cap_enabled, GraphQL::Types::Boolean,
          required: true,
          description: 'Whether the flat per-user budget cap is enabled.'

        # rubocop:disable GraphQL/ExtractType -- flat structure matches CDot API contract
        field :flat_user_cap, GraphQL::Types::Float,
          null: true,
          description: 'Updated flat per-user budget cap.'

        field :flat_user_cap_enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Whether the flat per-user budget cap is enabled.'
        # rubocop:enable GraphQL/ExtractType

        def resolve(flat_user_cap:, flat_user_cap_enabled:, namespace_path: nil)
          subscription_target, namespace = resolve_target(namespace_path)
          authorize_mutation!(subscription_target, namespace)

          client = build_subscription_usage_client(
            subscription_target, namespace
          )
          result = client.upsert_flat_user_cap(
            flat_user_cap: flat_user_cap,
            flat_user_cap_enabled: flat_user_cap_enabled
          )

          if result[:success]
            cap = result[:subscriptionBudgetCap]
            {
              flat_user_cap: cap[:flatUserCap],
              flat_user_cap_enabled: cap[:flatUserCapEnabled],
              errors: []
            }
          else
            {
              flat_user_cap: nil,
              flat_user_cap_enabled: nil,
              errors: result[:errors]
            }
          end
        end
      end
    end
  end
end

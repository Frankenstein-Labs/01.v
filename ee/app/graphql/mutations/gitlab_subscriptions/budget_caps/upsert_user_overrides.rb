# frozen_string_literal: true

module Mutations
  module GitlabSubscriptions
    module BudgetCaps
      class UpsertUserOverrides < BaseMutation
        graphql_name 'UpsertUserBudgetCapOverrides'

        authorize_granular_token permissions: :update_subscription_usage_cap,
          boundaries: [
            { boundary_argument: :namespace_path, boundary_type: :group },
            { boundary: :instance, boundary_type: :instance }
          ]

        include ResolvesSubscriptionTarget

        description 'Bulk upsert per-user budget cap overrides.'

        argument :overrides,
          [UserOverrideInputType],
          required: true,
          description: 'List of per-user budget cap overrides to upsert.'

        argument :namespace_path, GraphQL::Types::String,
          required: false,
          description: 'Path of the top-level group namespace. ' \
            'Omit for self-managed instance scope.'

        field :user_overrides,
          [::Types::GitlabSubscriptions::SubscriptionUsage::BudgetCaps::UserOverrideType],
          null: true,
          description: 'Updated user budget cap overrides.'

        MAX_OVERRIDES = 200

        def resolve(overrides:, namespace_path: nil)
          validate_overrides_limit!(overrides)

          subscription_target, namespace = resolve_target(namespace_path)
          authorize_mutation!(subscription_target, namespace)

          cdot_overrides = prepare_overrides(overrides, namespace)

          client = build_subscription_usage_client(
            subscription_target, namespace
          )
          result = client.upsert_user_budget_cap_overrides(
            overrides: cdot_overrides
          )

          if result[:success]
            usage = build_subscription_usage(
              subscription_target, namespace, client
            )

            {
              user_overrides: wrap_overrides(
                result[:userBudgetCapOverrides], usage
              ),
              errors: []
            }
          else
            { user_overrides: nil, errors: result[:errors] }
          end
        end

        private

        def validate_overrides_limit!(overrides)
          return if overrides.size <= MAX_OVERRIDES

          raise Gitlab::Graphql::Errors::ArgumentError,
            "Cannot upsert more than #{MAX_OVERRIDES} overrides at once"
        end

        def prepare_overrides(overrides, namespace)
          user_ids = []
          cdot_overrides = overrides.map do |o|
            id = o[:user_id].model_id
            user_ids << id.to_i
            {
              entityId: id.to_s,
              capAmount: o[:cap],
              enabled: o[:enabled]
            }
          end

          unique_ids = user_ids.uniq
          validate_user_ids!(unique_ids)
          validate_namespace_membership!(unique_ids, namespace) if namespace

          cdot_overrides
        end

        def validate_user_ids!(user_ids)
          return if user_ids.empty?

          existing_ids = User.id_in(user_ids).limit(user_ids.size).select(:id).map(&:id)
          return if existing_ids.size == user_ids.size

          missing_ids = user_ids - existing_ids
          missing_gids = missing_ids.map do |id|
            ::Gitlab::GlobalId.as_global_id(id, model_name: 'User').to_s
          end

          raise Gitlab::Graphql::Errors::ArgumentError,
            "Users not found: #{missing_gids.join(', ')}"
        end

        def validate_namespace_membership!(user_ids, namespace)
          eligible_ids = namespace.gitlab_duo_eligible_user_ids
          non_member_ids = user_ids.reject { |id| eligible_ids.include?(id) }
          return if non_member_ids.empty?

          non_member_gids = non_member_ids.map do |id|
            ::Gitlab::GlobalId.as_global_id(
              id, model_name: 'User'
            ).to_s
          end

          raise Gitlab::Graphql::Errors::ArgumentError,
            "Users are not part of the namespace: #{non_member_gids.join(', ')}"
        end

        def build_subscription_usage(subscription_target, namespace, client)
          ::GitlabSubscriptions::SubscriptionUsage.new(
            subscription_target: subscription_target,
            subscription_usage_client: client,
            namespace: namespace
          )
        end

        def wrap_overrides(overrides, policy_subject)
          Array.wrap(overrides).map do |node|
            ::GitlabSubscriptions::SubscriptionsUsage::BudgetCaps::UserOverride.new(
              entity_id: node[:entityId],
              cap: node[:cap],
              cap_enabled: node[:capEnabled],
              created_at: node[:createdAt],
              updated_at: node[:updatedAt],
              declarative_policy_subject: policy_subject
            )
          end
        end
      end
    end
  end
end

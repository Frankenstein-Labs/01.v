# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicyStore
      class CreateService < BaseService
        # rubocop:disable Lint/UselessMethodDefinition -- narrows params to required, unlike the base default
        def initialize(organization:, current_user:, params:)
          super
        end
        # rubocop:enable Lint/UselessMethodDefinition

        def execute
          return experiment_not_active_error unless experiment_active?
          return forbidden_error unless authorized?(:create_govern_policy)
          return conflicting_scope_error if conflicting_scope?

          policy = ::Gitlab::PolicyStore.create(policy_attributes)

          ServiceResponse.success(payload: { policy: policy })
        rescue ::Gitlab::PolicyStore::ValidationError => error
          ServiceResponse.error(message: error.message, reason: :invalid)
        end

        private

        def policy_attributes
          {
            organization_id: organization.id,
            name: params[:name],
            description: params[:description],
            trigger_type: params[:trigger_type],
            rules: params[:rules],
            actions: params[:actions],
            policy_scope: params[:policy_scope],
            scope_rego: params[:scope_rego],
            mode: params[:mode],
            lifecycle_state: params[:lifecycle_state]
          }.compact
        end
      end
    end
  end
end

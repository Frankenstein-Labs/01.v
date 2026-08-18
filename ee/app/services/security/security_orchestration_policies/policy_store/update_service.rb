# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicyStore
      class UpdateService < BaseService
        def initialize(organization:, current_user:, policy_id:, params:)
          super(organization: organization, current_user: current_user, params: params)

          @policy_id = policy_id
        end

        def execute
          return experiment_not_active_error unless experiment_active?
          return forbidden_error unless authorized?(:update_govern_policy)
          return conflicting_scope_error if conflicting_scope?
          return policy_not_found_error unless find_policy(policy_id)

          policy = ::Gitlab::PolicyStore.update(policy_id, params)

          ServiceResponse.success(payload: { policy: policy })
        rescue ::Gitlab::PolicyStore::NotFound
          policy_not_found_error
        rescue ::Gitlab::PolicyStore::ValidationError => error
          ServiceResponse.error(message: error.message, reason: :invalid)
        end

        private

        attr_reader :policy_id
      end
    end
  end
end

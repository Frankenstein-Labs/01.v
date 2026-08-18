# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicyStore
      class ListService < BaseService
        def initialize(organization:, current_user:, trigger_type: nil)
          super(organization: organization, current_user: current_user)

          @trigger_type = trigger_type
        end

        def execute
          return experiment_not_active_error unless experiment_active?
          return forbidden_error unless authorized?(:read_govern_policy)

          policies = ::Gitlab::PolicyStore.list(organization_id: organization.id, trigger_type: trigger_type)

          ServiceResponse.success(payload: { policies: policies })
        end

        private

        attr_reader :trigger_type
      end
    end
  end
end

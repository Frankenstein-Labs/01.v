# frozen_string_literal: true

module Mutations
  module Ai
    module FlowTriggers
      class Delete < BaseMutation
        graphql_name 'AiFlowTriggerDelete'

        authorize :manage_ai_flow_triggers

        argument :id, ::Types::GlobalIDType[::Ai::FlowTrigger],
          required: true,
          description: 'ID of the flow trigger to delete.'

        def resolve(id:)
          trigger = authorized_find!(id: id)
          result = ::Ai::FlowTriggers::DestroyService.new(
            trigger: trigger,
            current_user: current_user
          ).execute

          { errors: result.success? ? [] : [result.message] }
        end
      end
    end
  end
end

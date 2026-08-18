# frozen_string_literal: true

module Resolvers
  module Ai
    class FlowTriggersResolver < BaseResolver
      alias_method :project, :object

      type ::Types::Ai::FlowTriggerType.connection_type, null: true

      authorize :manage_ai_flow_triggers

      argument :ids, [::Types::GlobalIDType[::Ai::FlowTrigger]],
        required: false,
        default_value: nil,
        description: 'Filter AI flow triggers by IDs.'

      def resolve(ids: nil)
        if ids
          project.ai_flow_triggers.with_ids(ids.map(&:model_id))
        else
          project.ai_flow_triggers
        end
      end
    end
  end
end

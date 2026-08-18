# frozen_string_literal: true

module Types
  module Ai
    module FlowTrigger
      class EventTypeEnum < BaseEnum
        graphql_name 'AiFlowTriggerEventType'
        description 'Possible event types for flow triggers.'

        ::Ai::FlowTrigger::EVENT_TYPES.each do |event_type, id|
          value event_type.upcase, description: "Flow trigger #{event_type} event.", value: id
        end
      end
    end
  end
end

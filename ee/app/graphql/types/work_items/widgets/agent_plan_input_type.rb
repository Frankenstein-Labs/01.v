# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      class AgentPlanInputType < BaseInputObject
        graphql_name 'WorkItemWidgetAgentPlanInput'

        argument :content, GraphQL::Types::String,
          required: false,
          description: 'Content of the agent plan.'

        argument :readiness_score, GraphQL::Types::Int,
          required: false,
          experiment: { milestone: '19.3' },
          description: copy_field_description(::Types::WorkItems::Widgets::AgentPlanType, :readiness_score)
      end
    end
  end
end

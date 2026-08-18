# frozen_string_literal: true

module Mutations
  module Ai
    module FlowTriggers
      class Update < BaseMutation
        graphql_name 'AiFlowTriggerUpdate'

        authorize :manage_ai_flow_triggers

        argument :id, ::Types::GlobalIDType[::Ai::FlowTrigger],
          required: true,
          description: 'ID of the flow trigger to update.'

        argument :user_id, ::Types::GlobalIDType[::User],
          prepare: ->(global_id, _ctx) { global_id&.model_id&.to_i },
          required: false,
          description: 'Service account for the AI flow trigger.'

        argument :description, GraphQL::Types::String,
          required: false,
          description: 'Description of the AI flow trigger.'

        argument :event_types, [GraphQL::Types::Int],
          required: false,
          description: 'Event types that triggers the AI flow.'

        argument :config_path, GraphQL::Types::String,
          required: false,
          description: 'Path to the configuration file for the AI flow trigger.'

        argument :ai_catalog_item_consumer_id, ::Types::GlobalIDType[::Ai::Catalog::ItemConsumer],
          prepare: ->(global_id, _ctx) { global_id&.model_id&.to_i },
          required: false,
          description: 'AI catalog item consumer to use instead of config_path.'

        argument :filter, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- filter schema is not model backend
          required: false,
          experiment: { milestone: '18.11' },
          description: 'Filter conditions for the AI flow trigger.'

        field :ai_flow_trigger,
          Types::Ai::FlowTriggerType,
          description: 'Updated AI flow trigger.'

        def resolve(id:, **params)
          trigger = authorized_find!(id: id)

          response = ::Ai::FlowTriggers::UpdateService.new(project: trigger.project,
            current_user: context[:current_user], trigger: trigger).execute(params)

          if response.success?
            trigger = response.payload

            { ai_flow_trigger: trigger, errors: [] }
          else
            {
              ai_flow_trigger: nil,
              errors: [response.message]
            }
          end
        end
      end
    end
  end
end

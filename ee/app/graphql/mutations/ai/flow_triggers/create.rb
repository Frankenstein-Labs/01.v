# frozen_string_literal: true

module Mutations
  module Ai
    module FlowTriggers
      class Create < BaseMutation
        graphql_name 'AiFlowTriggerCreate'

        include FindsProject

        authorize :manage_ai_flow_triggers

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Full path of the project the AI flow trigger is associated with.'

        argument :user_id, ::Types::GlobalIDType[::User],
          prepare: ->(global_id, _ctx) { global_id&.model_id&.to_i },
          required: false,
          description: 'Service account for the AI flow trigger.'

        argument :description, GraphQL::Types::String,
          required: true,
          description: 'Description of the AI flow trigger.'

        argument :event_types, [GraphQL::Types::Int],
          required: false,
          description: 'Event types that triggers the AI flow.'

        argument :filter, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- filter schema is not model backend
          required: false,
          experiment: { milestone: '19.0' },
          description: 'Filter conditions for the AI flow trigger.'

        argument :config_path, GraphQL::Types::String,
          required: false,
          description: 'Path to the configuration file for the AI flow trigger.'

        argument :ai_catalog_item_consumer_id, ::Types::GlobalIDType[::Ai::Catalog::ItemConsumer],
          prepare: ->(global_id, _ctx) { global_id&.model_id&.to_i },
          required: false,
          description: 'AI catalog item consumer to use instead of config_path.'

        field :ai_flow_trigger,
          Types::Ai::FlowTriggerType,
          description: 'Created AI flow trigger.'

        def resolve(project_path:, **params)
          project = authorized_find!(project_path)

          response = ::Ai::FlowTriggers::CreateService.new(project: project,
            current_user: context[:current_user]).execute(params)

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

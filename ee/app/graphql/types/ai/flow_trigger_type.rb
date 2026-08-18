# frozen_string_literal: true

module Types
  module Ai
    class FlowTriggerType < BaseObject
      graphql_name 'AiFlowTriggerType'
      description 'Represents an AI flow trigger'

      connection_type_class Types::CountableConnectionType

      authorize :read_ai_flow_triggers

      field :id, GraphQL::Types::ID,
        null: false,
        description: 'ID of the flow trigger.'

      field :description, GraphQL::Types::String,
        null: false,
        description: 'Description of the flow trigger.'

      field :event_types, [GraphQL::Types::Int],
        null: false,
        description: 'List of events that triggers the flow.'

      # rubocop:disable GraphQL/ExtractType -- not for now
      field :config_path, GraphQL::Types::String,
        null: true,
        description: 'Path to the configuration file for the trigger.'

      field :config_url, GraphQL::Types::String,
        null: true,
        description: 'Web URL to the configuration file for the trigger.',
        calls_gitaly: true
      # rubocop:enable GraphQL/ExtractType

      field :ai_catalog_item_consumer, Types::Ai::Catalog::ItemConsumerType,
        null: true,
        description: 'AI catalog item consumer associated with the trigger.'

      field :project, ::Types::ProjectType,
        null: false,
        description: 'Project of the flow trigger.'

      field :user, ::Types::UserType,
        null: true,
        method: :service_account,
        description: 'Service account of the flow trigger.'

      field :created_at, Types::TimeType,
        null: false,
        description: 'Timestamp of when the flow trigger was created.'

      field :updated_at, Types::TimeType,
        null: false,
        description: 'Timestamp of when the flow trigger was last updated.'

      field :filter, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- filter schema is not model backend
        null: true,
        experiment: { milestone: '18.11' },
        description: 'Filter conditions for the AI flow trigger.'

      field :precondition, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- precondition uses same schema as filter
        null: true,
        experiment: { milestone: '18.11' },
        method: :foundational_flow_precondition,
        description: 'Enforced filter conditions from the foundational flow definition.'

      def config_url
        return unless object.config_path.present? && object.project.default_branch

        id = File.join(object.project.default_branch, object.config_path)
        ::Gitlab::Routing.url_helpers.project_blob_path(object.project, id)
      end
    end
  end
end

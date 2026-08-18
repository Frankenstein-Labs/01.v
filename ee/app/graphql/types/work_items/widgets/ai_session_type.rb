# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      # rubocop:disable Graphql/AuthorizeTypes -- Disabling widget level authorization
      class AiSessionType < BaseObject
        graphql_name 'WorkItemWidgetAiSession'
        description 'Represents an AI session widget'

        authorize_granular_token skip_reason: :parent_authorizes

        implements ::Types::WorkItems::WidgetInterface

        field :duo_workflows,
          ::Types::Ai::DuoWorkflows::WorkflowType.connection_type,
          null: true,
          description: 'Duo Workflow sessions associated with the work item.' do
            extension ::Gitlab::Graphql::Limit::FieldCallCount, limit: 1
          end
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end

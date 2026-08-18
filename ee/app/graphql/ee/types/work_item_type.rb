# frozen_string_literal: true

module EE
  module Types
    module WorkItemType # rubocop:disable Gitlab/BoundedContexts -- Types::WorkItemType is CE class
      extend ActiveSupport::Concern

      prepended do
        field :promoted_to_epic_url, GraphQL::Types::String, null: true,
          description: 'URL of the epic that the work item has been promoted to.'

        field :duo_workflow_links,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkItemDuoWorkflowLinksResolver,
          description: 'GitLab Duo Agent Platform sessions linked to the work item.' do
            extension ::Gitlab::Graphql::Limit::FieldCallCount, limit: 1
          end
      end
    end
  end
end

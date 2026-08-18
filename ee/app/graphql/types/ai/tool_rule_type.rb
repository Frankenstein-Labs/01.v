# frozen_string_literal: true

module Types
  module Ai
    # rubocop: disable Graphql/AuthorizeTypes -- parent authorization is enough
    class ToolRuleType < Types::BaseObject
      graphql_name 'AiToolRule'
      description 'A governance rule for an AI agent tool'

      authorize_granular_token skip_reason: :parent_authorizes

      field :id, # rubocop: disable GraphQL/FieldHashKey -- BaseObject#id calls to_global_id on plain hashes; explicit override required
        GraphQL::Types::ID,
        null: false,
        description: 'Tool name. Used as stable identifier. Always the tool name string and never a database ID.'

      field :name,
        GraphQL::Types::String,
        null: false,
        description: 'Name of the tool as registered in the tool registry.'

      field :action_type,
        Types::Ai::ToolActionTypeEnum,
        null: false,
        description: 'Action type categorisation for the tool.'

      field :category,
        GraphQL::Types::String,
        null: false,
        description: 'Display category for the tool. For example, GitLab Read, Files, and Commands.'

      field :source,
        Types::Ai::ToolSourceEnum,
        null: false,
        description: 'Source of the tool. Either "gitlab" or "mcp".'

      field :web_access,
        Types::Ai::ToolPermissionEnum,
        null: true,
        description: 'Permission mode for web surface. Null means no rule is set and ' \
          'the value falls back to the default privileged group.'

      field :local_access,
        Types::Ai::ToolPermissionEnum,
        null: true,
        description: 'Permission mode for local or IDE surface. Null means no rule is set and ' \
          'the value falls back to the default privileged group.'

      field :background_access,
        Types::Ai::BackgroundToolPermissionEnum,
        null: true,
        experiment: { milestone: '19.3' },
        description: 'Permission mode for the background-flow surface. Null means no rule is set and ' \
          'the value falls back to the default privileged group.'

      def id
        object[:id]
      end

      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end

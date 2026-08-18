# frozen_string_literal: true

module Types
  module Analytics
    module AiMetricsBasic
      # rubocop: disable Graphql/AuthorizeTypes -- always authorized by Resolver
      class NamespaceMetricsType < BaseObject
        graphql_name 'AiMetricsBasic'
        description <<~DESC
          AI-related metrics with three months of data retention.
          Premium and Ultimate only.
        DESC

        field :code_suggestions,
          resolver: Resolvers::Analytics::AiMetricsBasic::CodeSuggestionMetricsResolver,
          null: true,
          description: 'Code Suggestions metrics.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end

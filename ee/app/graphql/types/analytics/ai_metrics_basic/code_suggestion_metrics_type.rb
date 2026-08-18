# frozen_string_literal: true

module Types
  module Analytics
    module AiMetricsBasic
      # rubocop: disable Graphql/AuthorizeTypes -- authorized by parent type
      class CodeSuggestionMetricsType < BaseObject
        graphql_name 'codeSuggestionMetricsBasic'
        description <<~DESC
          AI-related metrics with three months of data retention.
          Premium and Ultimate only.
        DESC

        field :accepted_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions accepted.',
          null: true
        field :shown_count, GraphQL::Types::Int,
          description: 'Total count of code suggestions shown.',
          null: true
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end

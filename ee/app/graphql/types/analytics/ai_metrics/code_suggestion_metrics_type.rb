# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- authorized by parent type
      class CodeSuggestionMetricsType < ::Types::Analytics::AiMetricsBasic::CodeSuggestionMetricsType
        graphql_name 'codeSuggestionMetrics'
        description "Requires ClickHouse. Premium and Ultimate only."

        field :accepted_lines_of_code, GraphQL::Types::Int,
          description: 'Sum of lines of code from code suggestions accepted.',
          null: true
        field :contributors_count, GraphQL::Types::Int,
          description: 'Number of code contributors who used GitLab Duo Code Suggestions features.',
          null: true
        field :ide_names, [::GraphQL::Types::String],
          description: 'List of IDE names with at least one suggestion shown or accepted.',
          null: true
        field :languages, [::GraphQL::Types::String],
          description: 'List of languages with at least one suggestion shown or accepted.',
          null: true
        field :shown_lines_of_code, GraphQL::Types::Int,
          description: 'Sum of lines of code from code suggestions shown.',
          null: true
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end

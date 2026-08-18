# frozen_string_literal: true

module Types
  module Boards
    class BoardEpicInputType < BoardIssuableInputBaseType
      graphql_name 'EpicFilters'

      class NegatedEpicBoardIssueInputType < BoardIssuableInputBaseType
        argument :custom_field, [::Types::WorkItems::Widgets::CustomFieldFilterInputType],
          required: false,
          experiment: { milestone: '18.4' },
          description: 'Filter by negated custom fields.'
      end

      argument :not, NegatedEpicBoardIssueInputType,
        required: false,
        description: 'Negated epic arguments.'

      argument :or, Types::Epics::UnionedEpicFilterInputType,
        required: false,
        description: 'List of arguments with inclusive OR.'

      argument :search, GraphQL::Types::String,
        required: false,
        description: 'Search query for epic title or description.'

      argument :confidential, GraphQL::Types::Boolean,
        required: false,
        description: 'Filter by confidentiality.'

      argument :custom_field, [::Types::WorkItems::Widgets::CustomFieldFilterInputType],
        required: false,
        experiment: { milestone: '17.10' },
        description: 'Filter by custom fields.'
    end
  end
end

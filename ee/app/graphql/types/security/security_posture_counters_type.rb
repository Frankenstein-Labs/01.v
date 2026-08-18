# frozen_string_literal: true

module Types
  module Security
    class SecurityPostureCountersType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Authorization is done in resolver layer
      graphql_name 'SecurityPostureCounters'
      description 'Aggregated security posture counters for a namespace.'

      field :with_scanners, GraphQL::Types::Int,
        null: false,
        experiment: { milestone: '19.0' },
        description: 'Number of unarchived projects with at least one security scanner configured.'

      field :with_failures, GraphQL::Types::Int,
        null: false,
        experiment: { milestone: '19.0' },
        description: 'Number of unarchived projects with at least one failed scan.'

      field :with_stale, GraphQL::Types::Int,
        null: false,
        experiment: { milestone: '19.0' },
        description: 'Number of unarchived projects with at least one stale scan.'
    end
  end
end

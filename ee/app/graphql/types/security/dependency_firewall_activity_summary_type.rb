# frozen_string_literal: true

module Types
  module Security
    # rubocop: disable Graphql/AuthorizeTypes -- authorization is handled on the parent field
    class DependencyFirewallActivitySummaryType < BaseObject
      graphql_name 'DependencyFirewallActivitySummary'
      description 'Aggregate dependency firewall enforcement activity totals for a group or project.'

      field :active_rules, GraphQL::Types::Int, null: false,
        description: 'Number of active (enabled) dependency firewall rules.'
      field :allowed, GraphQL::Types::Int, null: false,
        description: 'Total allowed (pass-through) enforcement events in the window.'
      field :blocked, GraphQL::Types::Int, null: false,
        description: 'Total blocked enforcement events in the window.'
      field :blocking_rules, GraphQL::Types::Int, null: false,
        description: 'Number of active rules in enforce (blocking) mode.'
      field :total_triggers, GraphQL::Types::Int, null: false,
        description: 'Total enforcement events (blocked + warned + allowed) in the window.'
      field :warned, GraphQL::Types::Int, null: false,
        description: 'Total warned enforcement events in the window.'
      field :warning_rules, GraphQL::Types::Int, null: false,
        description: 'Number of active rules in warn mode.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end

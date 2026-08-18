# frozen_string_literal: true

module Types
  module Namespaces
    # rubocop: disable Graphql/AuthorizeTypes -- Authorization is handled in the parent NamespaceType class
    class PlanType < BaseObject
      graphql_name 'NamespacePlan'
      description 'Represents a subscription plan.'

      field :is_paid, GraphQL::Types::Boolean, null: true, method: :paid?, description: 'True if plan is paid.'
      field :name, GraphQL::Types::String, null: true, description: 'Name of the plan.'
      field :title, GraphQL::Types::String, null: true, description: 'Title of the plan.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end

# frozen_string_literal: true

module Types
  # rubocop: disable Graphql/AuthorizeTypes
  class VulnerablePackageType < BaseObject
    graphql_name 'VulnerablePackage'
    description 'Represents a vulnerable package. Used in vulnerability dependency data'

    authorize_granular_token skip_reason: :parent_authorizes

    field :name, GraphQL::Types::String, null: true,
      description: 'Name of the vulnerable package.'

    field :path, GraphQL::Types::String, null: true,
      description: 'Path of the vulnerable package.'
  end
end

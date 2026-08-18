# frozen_string_literal: true

module Types
  # rubocop: disable Graphql/AuthorizeTypes
  class VulnerableDependencyType < BaseObject
    graphql_name 'VulnerableDependency'
    description 'Represents a vulnerable dependency. Used in vulnerability location data'

    authorize_granular_token skip_reason: :parent_authorizes

    field :package, ::Types::VulnerablePackageType,
      null: true, description: 'Package associated with the vulnerable dependency.'

    field :version, GraphQL::Types::String,
      null: true, description: 'Version of the vulnerable dependency.'
  end
end

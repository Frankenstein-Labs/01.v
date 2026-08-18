# frozen_string_literal: true

module Types
  module Ai
    # rubocop: disable Graphql/AuthorizeTypes -- reachable only via the already-authorized
    # AiFlowsMetadata query (see Resolvers::Ai::FlowsMetadataResolver)
    class FlowCapabilityType < Types::BaseObject
      graphql_name 'AiFlowCapability'
      description 'A capability the instance advertises for Duo Agent Platform flows.'

      authorize_granular_token skip_reason: :parent_authorizes

      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the capability.'

      field :metadata, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- payload shape varies per capability
        null: true,
        description: 'Arbitrary JSON-encoded metadata associated with the capability.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end

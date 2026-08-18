# frozen_string_literal: true

module Types
  module Ai
    # rubocop: disable Graphql/AuthorizeTypes -- reachable only via the already-authorized
    # top-level `aiFlowsMetadata` query field (see Resolvers::Ai::FlowsMetadataResolver)
    class FlowsMetadataType < Types::BaseObject
      graphql_name 'AiFlowsMetadata'
      description 'Metadata describing Duo Agent Platform flow capabilities available to the caller.'

      authorize_granular_token permissions: :read_flows_metadata,
        boundaries: [
          { boundary: :group, boundary_type: :group },
          { boundary: :project, boundary_type: :project },
          { boundary: :instance, boundary_type: :instance }
        ]

      field :capabilities, [Types::Ai::FlowCapabilityType],
        null: false,
        description: 'List of capabilities the instance advertises for Duo Agent Platform flows.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end

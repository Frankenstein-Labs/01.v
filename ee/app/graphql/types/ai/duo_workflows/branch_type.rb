# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      # rubocop: disable Graphql/AuthorizeTypes -- the resolver authorizes the session first
      class BranchType < Types::BaseObject
        graphql_name 'DuoWorkflowBranch'
        description 'Alternative branch of a Duo Agent Platform session, created by retrying a message'
        # Nothing to authorize while the field returns no branches. The read that fills
        # it in authorizes the session first, in the merge request that adds it.
        authorize_granular_token skip_reason: :parent_authorizes

        field :fork_thread_ts, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true,
          description: 'Identifier of the checkpoint to resume the session from to switch to the branch.'

        field :messages, [Types::Ai::DuoWorkflows::DuoMessageType],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false,
          description: 'Messages the branch added after the point it diverged, oldest first.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end

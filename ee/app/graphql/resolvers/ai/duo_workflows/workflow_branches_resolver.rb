# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowBranchesResolver < BaseResolver
        # Nullable: the branches read, which lands separately, nulls the field for a
        # caller that may not see the session.
        type [Types::Ai::DuoWorkflows::BranchType], null: true

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: true,
          description: 'Global ID of the session.'

        argument :thread_ts, GraphQL::Types::String,
          required: true,
          description: 'Identifier of the checkpoint that introduced a user message, from ' \
            '`DuoMessage.threadTs`. Returns the other attempts at the same turn, so the branch ' \
            'that message belongs to is excluded.'

        # rubocop:disable Lint/UnusedMethodArgument -- both arguments are read once the
        # branches are reconstructed; the shape is defined here so the frontend can
        # build against it.
        def resolve(workflow_id:, thread_ts:)
          # Always empty: this merge request only settles the schema. Reconstructing the
          # branches lands separately, and authorizing the session lands with it, since
          # there is nothing yet to authorize access to.
          []
        end
        # rubocop:enable Lint/UnusedMethodArgument
      end
    end
  end
end

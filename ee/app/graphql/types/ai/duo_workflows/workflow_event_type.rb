# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowEventType < Types::BaseObject
        graphql_name 'DuoWorkflowEvent'
        description "Events that describe the history and progress of a GitLab Duo Agent Platform session"
        present_using ::Ai::DuoWorkflows::WorkflowCheckpointEventPresenter
        authorize :read_duo_workflow_event

        COMPRESS_LEVEL = 6 # Fast and good zlib compression

        def self.authorization_scopes
          [:api, :read_api, :ai_features, :ai_workflows]
        end

        field :checkpoint, Types::JsonStringType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          deprecated: { reason: 'Checkpoints are big & contain internal langgraph details', milestone: '18.7' },
          description: 'Checkpoint of the event.'

        field :compressed_checkpoint, GraphQL::Types::String,
          null: true,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Checkpoint of the event, zlib-compressed and Base64-encoded.'

        field :metadata, Types::JsonStringType,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Metadata associated with the event.'

        field :workflow_status, Types::Ai::DuoWorkflows::WorkflowStatusEnum,
          description: 'Status of the session.'

        field :execution_status, GraphQL::Types::String,
          null: false, description: "Granular status of the session's execution.",
          experiment: { milestone: '17.10' }

        field :errors, [GraphQL::Types::String],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true, description: 'Message errors.'

        field :thread_ts, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'UUID v7 timestamp identifier for the conversation thread/session in LangGraph state management.'

        # rubocop:disable GraphQL/ExtractType -- no need to extract fields into a separate field
        field :parent_ts, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'UUID v7 timestamp identifier of the parent message for branched conversations or responses.'

        field :checkpoint_ns, GraphQL::Types::String,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          experiment: { milestone: '19.3' },
          description: 'LangGraph checkpoint namespace this checkpoint belongs to. Blank for the ' \
            'session\'s own top-level checkpoint lineage; this field only ever surfaces that lineage ' \
            '(via first_checkpoint/latest_checkpoint), never a nested subgraph invocation\'s own.'

        field :workflow_goal, GraphQL::Types::String,
          description: 'Goal of the session.'

        field :workflow_definition, GraphQL::Types::String,
          description: 'GitLab Duo Agent Platform flow type based on its capabilities.'
        # rubocop:enable GraphQL/ExtractType -- we want to keep this way for backwards compatibility

        field :duo_messages, [Types::Ai::DuoWorkflows::DuoMessageType],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          description: 'Messages from the ui_chat_log for the checkpoint.'

        field :last_duo_message, Types::Ai::DuoWorkflows::DuoMessageType,
          null: true,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          experiment: { milestone: '19.3' },
          description: 'Most recent message from the ui_chat_log for the checkpoint. ' \
            'Cheaper than duoMessages for list previews: it reads only the latest message ' \
            'instead of the full chat log.'

        # rubocop:disable GraphQL/ExtractType -- no need to extract fields into a separate field
        field :checkpoint_writes, [Types::Ai::DuoWorkflows::CheckpointWriteType],
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          experiment: { milestone: '19.3' },
          description: 'Pending writes associated with the checkpoint, e.g. interrupts awaiting resumption.'
        # rubocop:enable GraphQL/ExtractType -- no need to extract fields into a separate field

        def compressed_checkpoint
          checkpoint = object.checkpoint
          return unless checkpoint

          Base64.strict_encode64(Zlib::Deflate.deflate(checkpoint.to_json, COMPRESS_LEVEL))
        end

        # `checkpoint_writes` isn't preloaded by the callers of this type (e.g. the
        # first_checkpoint/latest_checkpoint fields resolve one Checkpoint per workflow
        # independently), so a naive `object.checkpoint_writes` here would issue a
        # separate query per resolved checkpoint. Batch those into a single query across
        # every checkpoint requested in this GraphQL request.
        def checkpoint_writes
          BatchLoader::GraphQL.for([object.workflow_id, object.thread_ts]).batch(default_value: []) do |keys, loader|
            workflow_ids = keys.map(&:first).uniq
            thread_tss = keys.map(&:last).uniq

            ::Ai::DuoWorkflows::CheckpointWrite.for_workflows_and_threads(workflow_ids, thread_tss).find_each do |write|
              loader.call([write.workflow_id, write.thread_ts]) { |writes| writes << write }
            end
          end
        end
      end
    end
  end
end

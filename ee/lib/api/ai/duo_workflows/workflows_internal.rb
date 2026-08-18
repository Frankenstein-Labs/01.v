# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      # This API is intended to be consumed by a running Duo Workflow using
      # the ai_workflows scope token. These are requests coming from Duo Workflow
      # Service and Duo Workflow Executor. We should not add any more requests to
      # this API than needed by those 2 components. Otherwise add to
      # `API::Ai::DuoWorkflows::Workflows`.
      class WorkflowsInternal < ::API::Base
        include PaginationParams
        include APIGuard

        COMPRESS_LEVEL = 6 # Fast and good zlib compression

        helpers ::API::Helpers::DuoWorkflowHelpers

        allow_access_with_scope :ai_workflows

        feature_category :duo_agent_platform

        before { authenticate! }

        helpers do
          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(human_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
          end

          def human_user
            current_user
          end

          def find_event!(workflow, id)
            workflow.events.find(id)
          end

          def render_response(response)
            if response.success?
              status :ok
              response.payload
            else
              status_code = error_status_for(response.reason)
              render_api_error!(response.message, status_code)
            end
          end

          def error_status_for(reason)
            {
              not_found: :not_found,
              unauthorized: :unauthorized,
              invalid_token_ownership: :forbidden,
              insufficient_token_scope: :forbidden,
              failed_to_revoke: :unprocessable_entity
            }.fetch(reason, :bad_request)
          end

          def compress_checkpoint(checkpoint_data)
            Base64.strict_encode64(Zlib::Deflate.deflate(checkpoint_data.to_json, COMPRESS_LEVEL))
          end

          def uncompress_checkpoint(compressed_data)
            ::Gitlab::Json.parse(Zlib::Inflate.inflate(Base64.strict_decode64(compressed_data)))
          rescue ArgumentError, Zlib::Error, JSON::ParserError => e
            bad_request!("Invalid compressed checkpoint data: #{e.message}")
          end

          # Rebuilds channel_values on the slim headers of one page, and batch-loads
          # their checkpoint_writes (a plain query per header otherwise, since
          # BulkInsertSafe forbids the association). Scoped to the page because
          # reconstruction is markedly more expensive than a header-only read.
          def reconstruct_page!(workflow, headers)
            return if headers.empty?

            writes_by_thread_ts = ::Ai::DuoWorkflows::CheckpointWrite
              .for_workflows_and_threads([workflow.id], headers.map(&:thread_ts))
              .group_by(&:thread_ts)
            blobs_by_thread_ts = workflow.blobs_by_thread_ts_for(headers)

            headers.each do |header|
              header.checkpoint_writes_preload = writes_by_thread_ts[header.thread_ts] || []
              header.checkpoint = header.checkpoint.merge(
                'channel_values' => workflow.reconstructed_channel_values_from(header, blobs_by_thread_ts)
              )
            end
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            desc 'Revoke ai_workflows token' do
              tags %w[gitlab_duo_workflows internal_operations]
              success code: 200
              failure [
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 422, message: 'Unprocessable Entity' }
              ]
            end
            params do
              requires :token, type: String, desc: 'The access token to revoke'
            end
            route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
            post :revoke_token do
              service = ::Ai::DuoWorkflows::RevokeTokenService.new(
                token: params[:token],
                current_user: current_user
              )

              render_response(service.execute)
            end

            namespace :workflows do
              desc 'Get workflow details' do
                tags %w[gitlab_duo_workflows internal_operations]
              end
              params do
                requires :id, type: Integer, desc: 'The ID of the workflow'
              end
              namespace '/:id' do
                params do
                  requires :id, type: Integer, desc: 'The ID of the workflow', documentation: { example: 1 }
                end
                route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                get do
                  require_gitlab_workhorse!

                  workflow = find_workflow!(params[:id])
                  push_ai_gateway_headers(scope: workflow.resource_parent,
                    subject: workflow.service_account || current_user)

                  present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow
                end

                desc 'Update the workflow status' do
                  tags %w[gitlab_duo_workflows internal_operations]
                  success code: 200
                end
                params do
                  requires :id, type: Integer, desc: 'The ID of the workflow', documentation: { example: 1 }
                  requires :status_event, type: String, desc: 'The status event',
                    documentation: { example: 'finish' }
                end
                route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                patch do
                  workflow = find_workflow!(params[:id])
                  forbidden! unless current_user.can?(:update_duo_workflow, workflow)

                  service = ::Ai::DuoWorkflows::UpdateWorkflowStatusService.new(
                    workflow: workflow,
                    status_event: params[:status_event],
                    current_user: current_user
                  )

                  render_response(service.execute)
                end

                namespace :checkpoints do
                  before do
                    require_gitlab_workhorse!
                  end
                  desc 'Create workflow checkpoint' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :thread_ts, type: String, desc: 'The thread ts'
                    optional :parent_ts, type: String, desc: 'The parent ts'
                    optional :checkpoint_ns, type: String, limit: 4096,
                      desc: 'LangGraph checkpoint namespace this checkpoint belongs to. ' \
                        'Omitted (or blank) for the flow\'s own top-level checkpoint lineage; ' \
                        'set to LangGraph\'s namespace string for one nested subgraph invocation, ' \
                        'e.g. a delegated subagent dispatched by DelegationNode.'
                    optional :checkpoint, type: Hash, desc: "Checkpoint content"
                    optional :compressed_checkpoint, type: String,
                      desc: "Checkpoint content zlib compressed and base64 encoded"
                    requires :metadata, type: Hash, desc: "Checkpoint metadata"
                    optional :model_metadata_json, type: String, desc: "JSON string of the model metadata"
                    optional :flow_metadata_json, type: String, desc: "JSON string of the flow metadata"
                    optional :current_thread, type: Integer, default: 0,
                      desc: 'Thread grouping hint for blob reconstruction'
                    optional :channel_blobs, type: Array, limit: 100,
                      desc: 'Per-channel blobs for incremental checkpoint storage' do
                      requires :channel, type: String, limit: 255, desc: 'Channel name'
                      requires :version, type: String, limit: 255, desc: 'Channel version'
                      requires :write_type, type: String, limit: 255,
                        desc: 'Blob serialization type. The read path decodes zlib-compressed JSON, ' \
                          'so producers must send "json".'
                      requires :step_action, type: String, values: %w[conversation compaction],
                        desc: 'Append or replace signal (conversation or compaction)'
                      # base64 of the 1 MiB raw BLOB_DATA_LIMIT is 4 * ceil(1_048_576 / 3) = 1_398_104 chars;
                      # bounding here rejects oversized payloads before Base64.strict_decode64 allocates them.
                      requires :data, type: String, limit: 1_398_104, desc: 'Base64-encoded blob bytes'
                    end
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                  post do
                    workflow = find_workflow!(params[:id])
                    checkpoint = if params[:checkpoint].present?
                                   params[:checkpoint]
                                 elsif params[:compressed_checkpoint].present?
                                   uncompress_checkpoint(params[:compressed_checkpoint])
                                 end

                    bad_request!('Either checkpoint or compressed_checkpoint must be provided') unless checkpoint

                    checkpoint_params = declared_params(include_missing: false)
                                          .except(:id)
                                          .merge(checkpoint: checkpoint)

                    service = ::Ai::DuoWorkflows::CreateCheckpointService.new(
                      workflow: workflow, params: checkpoint_params)
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:checkpoint], with: ::API::Entities::Ai::DuoWorkflows::BasicCheckpoint
                  end

                  desc 'List all workflow checkpoints' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  params do
                    optional :accept_compressed, type: Boolean, default: false, desc: "Return compressed checkpoints"
                    optional :checkpoint_ns, type: String, limit: 4096,
                      desc: 'Only return checkpoints belonging to this LangGraph checkpoint namespace ' \
                        '(the flow\'s own top-level lineage if omitted or blank). Unset (the default): ' \
                        'return checkpoints from every lineage, unfiltered, preserving prior behavior.'
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                  get do
                    workflow = find_workflow!(params[:id])

                    # An incremental workflow writes a header for every checkpoint
                    # (independent of write_incremental_only, which only drops the full
                    # row), so headers are a superset of `checkpoints` here: read them
                    # alone rather than merging. Blobs also carry the pre-compaction
                    # history the full row truncates.
                    reconstruct = workflow.reconstruct_from_blobs_for_list?
                    checkpoints = if reconstruct
                                    workflow.checkpoint_headers.in_reverse_checkpoint_order
                                  else
                                    workflow.checkpoints.ordered_with_writes
                                  end

                    checkpoints = checkpoints.for_checkpoint_ns(params[:checkpoint_ns]) if params.key?(:checkpoint_ns)

                    checkpoints = paginate(checkpoints)
                    reconstruct_page!(workflow, checkpoints) if reconstruct

                    if params[:accept_compressed]
                      checkpoints.each { |cp| cp.compressed_checkpoint = compress_checkpoint(cp.checkpoint) }
                    end

                    present checkpoints, with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                  end

                  # Reconstructs a checkpoint from the slim header + incremental
                  # blobs, keyed by the langgraph thread_ts, without reading the full
                  # p_duo_workflows_checkpoints row (which is being retired). thread_ts
                  # is the durable identifier the gateway already holds; the numeric
                  # checkpoint id is tied to the full-checkpoint table.
                  desc 'Get a workflow checkpoint reconstructed from incremental blobs' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  params do
                    requires :thread_ts, type: String, desc: 'The langgraph thread_ts of the checkpoint'
                    optional :accept_compressed, type: Boolean, default: false, desc: "Return compressed checkpoint"
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                  get 'by_thread_ts' do
                    workflow = find_workflow!(params[:id])

                    # The gateway owns the read decision: it calls this only when
                    # dw_read_blobs_api (pushed via push_feature_flags) is on and the
                    # workflow's incremental_checkpoints_enabled column is true. So the
                    # endpoint does not re-check those flags -- it serves whenever a
                    # header exists. A workflow without blobs has no header and 404s.
                    header = workflow.checkpoint_header_for(params[:thread_ts])
                    not_found! unless header

                    # The slim header omits channel_values; rebuild it from blobs so
                    # the gateway receives a complete checkpoint. Done before
                    # compression so the compressed payload carries the values too.
                    header.checkpoint = header.checkpoint.merge(
                      'channel_values' => workflow.reconstructed_channel_values(header)
                    )

                    header.compressed_checkpoint = compress_checkpoint(header.checkpoint) if params[:accept_compressed]

                    present header, with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                  end

                  params do
                    requires :checkpoint_id, type: Integer, desc: 'The ID of the checkpoint'
                  end
                  namespace '/:checkpoint_id' do
                    desc 'Get details on a workflow checkpoint' do
                      tags %w[gitlab_duo_workflows internal_operations]
                    end
                    params do
                      requires :checkpoint_id, type: Integer, desc: 'The ID of the checkpoint',
                        documentation: { example: 1 }
                      optional :accept_compressed, type: Boolean, default: false, desc: "Return compressed checkpoint"
                    end
                    route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                    get do
                      workflow = find_workflow!(params[:id])
                      checkpoint = workflow.checkpoints.with_checkpoint_writes.find_by_id(params[:checkpoint_id])

                      not_found! unless checkpoint

                      if params[:accept_compressed]
                        checkpoint.compressed_checkpoint = compress_checkpoint(checkpoint.checkpoint)
                      end

                      present checkpoint, with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
                    end
                  end
                end

                namespace :checkpoint_writes_batch do
                  before do
                    require_gitlab_workhorse!
                  end

                  desc 'Create multiple workflow checkpoint writes' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :thread_ts, type: String, desc: 'The thread ts'
                    requires :checkpoint_writes, type: Array, allow_blank: false, desc: 'List of checkpoint writes' do
                      requires :task, type: String, desc: 'The task id'
                      requires :idx, type: Integer, desc: 'The index of checkpoint write'
                      requires :channel, type: String, desc: 'The channel'
                      requires :write_type, type: String, desc: 'The type of data'
                      requires :data, type: String, desc: 'The checkpoint write data'
                    end
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                  post do
                    workflow = find_workflow!(params[:id])
                    result = ::Ai::DuoWorkflows::CreateCheckpointWriteBatchService.new(
                      workflow: workflow,
                      params: declared_params(include_missing: false).except(:id)
                    ).execute

                    bad_request!(result.message) if result.error?

                    status :ok
                  end
                end

                namespace :events do
                  desc 'Create workflow event' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :event_type, type: String, values: ::Ai::DuoWorkflows::Event.event_types.keys,
                      desc: 'The type of event'
                    requires :message, type: String, desc: "Message from the human"
                    optional :correlation_id, type: String, desc: "Correlation ID for tracking events",
                      regexp: ::Ai::DuoWorkflows::Event::UUID_REGEXP
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                  post do
                    workflow = find_workflow!(params[:id])
                    event_params = declared_params(include_missing: false).except(:id)
                    service = ::Ai::DuoWorkflows::CreateEventService.new(
                      workflow: workflow,
                      params: event_params.merge(event_status: :queued)
                    )
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:event], with: ::API::Entities::Ai::DuoWorkflows::Event
                  end

                  desc 'List all workflow events' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                  get do
                    workflow = find_workflow!(params[:id])
                    events = workflow.events.queued
                    present paginate(events), with: ::API::Entities::Ai::DuoWorkflows::Event
                  end

                  desc 'Update workflow event' do
                    tags %w[gitlab_duo_workflows internal_operations]
                  end
                  params do
                    requires :id, type: Integer, desc: 'The ID of the workflow'
                    requires :event_id, type: Integer, desc: 'The ID of the event'
                    requires :event_status, type: String, values: %w[queued delivered], desc: 'The status of the event'
                  end
                  route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
                  put '/:event_id' do
                    workflow = find_workflow!(params[:id])
                    event = find_event!(workflow, params[:event_id])
                    event_params = declared_params(include_missing: false).except(:id, :event_id)
                    service = ::Ai::DuoWorkflows::UpdateEventService.new(
                      event: event,
                      params: event_params
                    )
                    result = service.execute

                    bad_request!(result[:message]) if result[:status] == :error

                    present result[:event], with: ::API::Entities::Ai::DuoWorkflows::Event
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

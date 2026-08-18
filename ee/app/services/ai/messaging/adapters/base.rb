# frozen_string_literal: true

module Ai
  module Messaging
    module Adapters
      class Base
        TriggerBundle = Data.define(
          :current_user, :service_account, :flow_reference,
          :flow_config_id, :flow_config_schema_version, :flow_version,
          :item_version, :project, :goal, :resource,
          :additional_context, :source_branch
        ) do
          def initialize(
            current_user:, service_account:, flow_reference:, project:, goal:,
            flow_config_id: nil, flow_config_schema_version: nil, flow_version: nil,
            item_version: nil, resource: nil, additional_context: nil, source_branch: nil
          )
            super
          end
        end

        # Async path: returned instance has callback_context only, not full constructor state.
        def self.from_callback_context(_ctx)
          raise Gitlab::AbstractMethodError
        end

        def self.adapter_key
          raise Gitlab::AbstractMethodError
        end

        # Whether this surface streams live progress (plan/tool/agent updates) while
        # the flow runs. Gated at enqueue time so adapters that don't stream never
        # schedule a ProgressDeliveryWorker -- the cost is the scheduled job itself.
        # Opting in (returning true) is a capability bundle: such adapters MUST also
        # implement #on_progress.
        def self.supports_live_progress?
          false
        end

        # Entry point for surfaces whose flow the adapter framework runs itself
        # (via ExecuteWorkflowService): it links composite identity, ensures
        # service-account membership, then runs the flow through
        # with_lifecycle_hooks. @GitLabDuo and Slack use this today; they can move
        # to with_lifecycle_hooks once execution/provisioning are decoupled from
        # the adapter. A service-account failure short-circuits with that reason
        # so the wrapper delivers the right error.
        def trigger(bundle)
          with_lifecycle_hooks do |ctx|
            link_composite_identity!(bundle.service_account, bundle.current_user, bundle.project.organization)

            member_result = ::Ai::ServiceAccountMemberAddService
              .new(bundle.project, bundle.service_account).execute

            unless member_result.success?
              next [ServiceResponse.error(message: member_result.message, reason: :service_account_error), nil]
            end

            result = execute_flow(bundle, ctx)
            [result, result.payload&.dig(:workflow)]
          end
        end

        def build_callback_context
          raise Gitlab::AbstractMethodError
        end

        # Runs the synchronous lifecycle for a flow whose execution lives in the
        # block: the block runs the flow, returns [response, workflow], and must
        # persist the callback context on the workflow so CallbackWorker can
        # deliver the result later. Execution and provisioning are the block's
        # concern, not this method's.
        #
        # on_request_received runs before build_callback_context so adapters can
        # stash state (e.g. a progress note id) into the context.
        def with_lifecycle_hooks
          ack = require_success { on_request_received }
          return ack if ack.error?

          ctx = build_callback_context
          response, workflow = yield(ctx)

          if response.success?
            handle_error { on_flow_enqueued(callback_context: ctx, workflow: workflow) }
          else
            handle_error do
              on_flow_failed(callback_context: ctx, error: response.reason || :execute_workflow_failed, workflow: nil)
            end
          end

          response
        end

        # Posts the flow's final answer to the surface. MUST return truthy only when the
        # message actually reached it: adapters swallow their own transport errors, so this
        # return value is CallbackWorker's only signal to re-attempt a lost delivery.
        def deliver_result(callback_context:, message:, workflow:) # rubocop:disable Lint/UnusedMethodArgument -- abstract method defines the contract for subclasses
          raise Gitlab::AbstractMethodError
        end

        def deliver_error(callback_context:, error:) # rubocop:disable Lint/UnusedMethodArgument -- abstract method defines the contract for subclasses
          raise Gitlab::AbstractMethodError
        end

        def on_request_received; end

        # Fires synchronously once the flow has been submitted to CI (workload
        # enqueued). The container has not finished setup yet (clone, CLI install,
        # setup scripts) and the agent is not running. Adapters that have the real
        # workflow object can persist identifiers or show a "spinning up" indicator
        # here -- but should defer user-facing "started" output to on_flow_started.
        def on_flow_enqueued(callback_context:, workflow:); end

        # Fires asynchronously when the workflow first transitions to :running
        # (created -> running), i.e. the agent has actually begun. Driven by
        # WorkflowStartedEvent -> CallbackWorker, so the adapter is reconstructed
        # via from_callback_context: only callback_context + workflow are available.
        #
        # Runs in an at-least-once worker (CallbackWorker), so implementations
        # MUST be idempotent -- guard non-idempotent side effects (e.g. posting a
        # message) on persisted state so a redelivery does not duplicate them.
        def on_flow_started(callback_context:, workflow:); end

        def on_flow_completed(callback_context:, workflow:); end

        # Fires while the workflow is running, each time new progress is available,
        # paced by ProgressDeliveryWorker (coalesced: at most ~one call per
        # in-flight delivery per workflow).
        #
        # delta is an Ai::DuoWorkflows::ProgressReader::Delta carrying both views
        # of the same point in time (the flow's own ui_chat_log format):
        #   * delta.messages     -- the current cumulative snapshot. Replace
        #     surfaces (e.g. Slack, which rewrites its whole message) render from
        #     this so they keep still-current state like the active todo list even
        #     when this tick's change was an unrelated entry.
        #   * delta.new_messages -- only the entries appended since the last
        #     delivery. Append/stream surfaces that emit just what changed use this.
        # delta.empty? is false only when there is something new to deliver.
        #
        # Abstract: adapters that opt into live progress (supports_live_progress?)
        # implement this to render on their surface. Runs in an at-least-once
        # worker with replace semantics, so implementations must be idempotent --
        # re-rendering the same delta must be harmless.
        def on_progress(delta:, callback_context:) # rubocop:disable Lint/UnusedMethodArgument -- abstract method defines the contract for subclasses
          raise Gitlab::AbstractMethodError
        end

        # workflow: nil on sync failures (Base#trigger), workflow: <obj> on async (CallbackWorker).
        # Adapters that need conditional cleanup branch on workflow.present?.
        # Always called inside safe {} by the framework, so deliver_error errors are swallowed.
        def on_flow_failed(callback_context:, error:, workflow: nil) # rubocop:disable Lint/UnusedMethodArgument -- workflow kwarg is part of the public API for subclass overrides
          deliver_error(callback_context: callback_context, error: error)
        end

        private

        def execute_flow(bundle, ctx)
          ::Ai::Catalog::ExecuteWorkflowService.new(
            bundle.current_user,
            container: bundle.project,
            goal: bundle.goal,
            service_account: bundle.service_account,
            flow_definition: bundle.flow_reference,
            flow_config_id: bundle.flow_config_id,
            flow_config_schema_version: bundle.flow_config_schema_version,
            flow_version: bundle.flow_version,
            item_version: bundle.item_version,
            source_branch: bundle.source_branch || bundle.project.default_branch_or_main,
            additional_context: bundle.additional_context,
            messaging_callback_context: enriched_callback_context(ctx, bundle),
            **resource_params(bundle.resource)
          ).execute
        end

        def link_composite_identity!(service_account, scoped_user, organization)
          return unless composite_identity_eligible?(scoped_user, organization)
          return unless service_account&.composite_identity_enforced?

          ::Gitlab::Auth::Identity.link_from_web_request(
            service_account: service_account,
            scoped_user: scoped_user
          )
        end

        def composite_identity_eligible?(user, organization)
          return false unless user
          return false if ai_settings(organization).duo_workflow_oauth_application.nil?

          true
        end

        def ai_settings(organization)
          ::Ai::Setting.for_organization_read_only(organization)
        end

        # ExecuteWorkflowService expects iid, not id.
        def resource_params(resource)
          case resource
          when Issue then { issue_id: resource.iid }
          when MergeRequest then { merge_request_id: resource.iid }
          else {}
          end
        end

        # .compact strips nil values (e.g. item_version); downstream readers
        # should treat absent keys and nil keys identically.
        def enriched_callback_context(ctx, bundle)
          ctx.merge(
            'adapter' => self.class.adapter_key,
            'service_account_id' => bundle.service_account.id,
            'flow_reference' => bundle.flow_reference,
            'flow_config_id' => bundle.flow_config_id,
            'flow_config_schema_version' => bundle.flow_config_schema_version,
            'flow_version' => bundle.flow_version,
            'item_version' => bundle.item_version
          ).compact
        end

        def require_success
          result = yield
          result.is_a?(ServiceResponse) && result.error? ? result : ServiceResponse.success
        rescue StandardError => e
          ::Gitlab::ErrorTracking.track_exception(e, adapter: self.class.name)
          ServiceResponse.error(message: e.message, reason: :hook_failed)
        end

        def handle_error
          yield
        rescue StandardError => e
          ::Gitlab::ErrorTracking.track_exception(e, adapter: self.class.name)
        end
      end
    end
  end
end

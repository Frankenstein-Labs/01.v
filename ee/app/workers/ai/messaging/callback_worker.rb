# frozen_string_literal: true

module Ai
  module Messaging
    # Sole EventStore subscriber for messaging-lifecycle events (@GitLabDuo note
    # replies and Slack): resolves the adapter from the workflow's
    # messaging_callback_context and fires the matching lifecycle hook inline.
    # Marked as having external dependencies because some adapters (e.g. Slack)
    # call third-party APIs.
    #
    # rubocop:disable Scalability/IdempotentWorker -- EventStore::Subscriber includes idempotent
    class CallbackWorker
      include Gitlab::EventStore::Subscriber

      feature_category :duo_agent_platform

      # :sticky is the preferred consistency for jobs that should run as fast as possible: replicas
      # are guaranteed caught up to the enqueue point and the job falls back to the primary otherwise,
      # so there is no reschedule delay on replica lag.
      data_consistency :sticky
      worker_has_external_dependencies!

      def handle_event(event)
        case event
        when ::Ci::Workloads::WorkloadFinishedEvent
          handle_workload_finished(event)
        when ::Ai::DuoWorkflows::WorkflowStartedEvent
          handle_workflow_started(event)
        when ::Ai::DuoWorkflows::WorkflowFinishedEvent
          handle_workflow_finished(event)
        end
      end

      private

      def handle_workload_finished(event)
        workload = ::Ci::Workloads::Workload.find_by_id(event.data[:workload_id])
        unless workload
          log_skip('Workload not found', workload_id: event.data[:workload_id])
          return
        end

        workflow = workload.latest_workflow
        unless workflow
          log_skip('No workflow associated with workload', workload_id: event.data[:workload_id])
          return
        end

        with_adapter(workflow) do |adapter, callback_context|
          if event.data[:status] == 'finished' || workflow.finished?
            # Success normally rides the earlier WorkflowFinishedEvent; this is the last
            # event for the run, so it is the backstop when that delivery never landed.
            deliver_success(adapter, callback_context, workflow)
          else
            handle_error do
              adapter.on_flow_failed(callback_context: callback_context, error: :flow_failed, workflow: workflow)
            end
          end
        end
      end

      def handle_workflow_finished(event)
        workflow = ::Ai::DuoWorkflows::Workflow.find_by_id(event.data[:workflow_id])
        unless workflow
          log_skip('Workflow not found', workflow_id: event.data[:workflow_id])
          return
        end

        with_adapter(workflow) do |adapter, callback_context|
          deliver_success(adapter, callback_context, workflow)
        end
      end

      def handle_workflow_started(event)
        workflow = ::Ai::DuoWorkflows::Workflow.find_by_id(event.data[:workflow_id])
        unless workflow
          log_skip('Workflow not found', workflow_id: event.data[:workflow_id])
          return
        end

        with_adapter(workflow) do |adapter, callback_context|
          handle_error do
            adapter.on_flow_started(callback_context: callback_context, workflow: workflow)
          end
        end
      end

      def with_adapter(workflow)
        callback_context = workflow.messaging_callback_context
        return unless callback_context.present?

        klass = ::Ai::Messaging::AdapterRegistry[callback_context['adapter']]
        unless klass
          Gitlab::AppLogger.warn(
            message: 'Duo Messaging: unknown adapter in callback context',
            adapter: callback_context['adapter'],
            workflow_id: workflow.id
          )
          return
        end

        yield(klass.from_callback_context(callback_context), callback_context)
      end

      # Runs from both WorkflowFinishedEvent (the fast path) and WorkloadFinishedEvent (the
      # backstop, up to ~90s later), so it no-ops once an outcome is recorded: the reply is
      # never posted twice, and a job retry of either event is harmless.
      def deliver_success(adapter, callback_context, workflow)
        if already_delivered?(workflow)
          log_skip('Terminal outcome already delivered', workflow_id: workflow.id)
          return
        end

        message = extract_final_message(workflow.latest_ui_chat_log)

        unless message
          # The final checkpoint is persisted before the finish transition fires, so a
          # message missing now stays missing: marked before the attempt because the
          # outcome is terminal whether or not the error itself reaches the user.
          mark_delivered!(workflow)

          handle_error do
            adapter.on_flow_failed(callback_context: callback_context, error: :no_response, workflow: workflow)
          end

          return
        end

        delivered = handle_error do
          adapter.deliver_result(callback_context: callback_context, message: message, workflow: workflow)
        end

        unless delivered
          # Left unmarked so the WorkloadFinishedEvent re-attempts, and on_flow_completed is
          # held back so the surface isn't marked answered (Slack's white_check_mark) with
          # no answer on it.
          log_skip('Result delivery failed; leaving retry to WorkloadFinishedEvent', workflow_id: workflow.id)
          return
        end

        mark_delivered!(workflow)
        handle_error { adapter.on_flow_completed(callback_context: callback_context, workflow: workflow) }
      end

      def already_delivered?(workflow)
        workflow.messaging_callback_context['delivered_at'].present?
      end

      def mark_delivered!(workflow)
        workflow.merge_messaging_callback_context!('delivered_at' => Time.current.utc.iso8601)
      end

      # The ui_chat_log is cumulative: the latest checkpoint contains the full
      # log. Search from the end for the last agent message with non-blank
      # content and no tool calls, so that a trailing empty or tool-call-only
      # agent turn (e.g. after a final tool call like marking todos complete)
      # does not suppress the real response.
      def extract_final_message(chat_log)
        chat_log.reverse_each.detect do |m|
          m['message_type'] == 'agent' && m['content'].present? && m['tool_calls'].blank?
        end&.dig('content')
      end

      def log_skip(reason, **identifiers)
        Gitlab::AppLogger.info(
          message: "Duo Messaging: #{reason}",
          **identifiers
        )
      end

      # Returns nil once it swallows an error, so deliver_success reads a raised
      # delivery the same way it reads an adapter reporting one: not delivered.
      def handle_error
        yield
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e)
        nil
      end
    end
    # rubocop:enable Scalability/IdempotentWorker
  end
end

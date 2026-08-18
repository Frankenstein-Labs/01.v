# frozen_string_literal: true

module Cd
  module Rollouts
    # Dispatches a flow-graph event from the CD orchestrator to the
    # Cd::RolloutEnvironment and Cd::RolloutStep it names. Events are
    # at-least-once and fire-and-forget: unmatched/unhandled events are
    # logged as no-ops.
    #
    # `data.environment` (present on stage_started/stage_succeeded/step_failed,
    # and on step_started/step_succeeded now that they drive environment
    # transitions too) is the exact GitLab environment name to transition --
    # a stage can deploy to more than one environment, so `stage_name` alone
    # cannot resolve it.
    #
    # `data.position` addresses a Cd::RolloutStep by its `path` (dot-joined,
    # see Cd::ApplicationFlowDefinitions::Document#steps_with_paths). Every
    # step transition re-derives the rollout's own state via
    # Cd::Rollout#sync_state_from_steps!.
    #
    # A step_started event naming the approval step type also opens an
    # approval gate on the rollout (see #open_gate below), on top of the
    # environment/step transitions above.
    #
    # The engine also reports com.gitlab.cd.rollout_succeeded on success and
    # the endpoint accepts it, but this service deliberately ignores it: it
    # is redundant with Cd::Rollout#sync_state_from_steps!, which already
    # derives overall rollout completion from step state.
    #
    # Exact-duplicate retries (the reported state already matches the current
    # one) are treated as a no-op success rather than an error, since the
    # calling durable workflow engine retries actions on failure or restart.
    class ProcessWorkflowEventService
      def initialize(rollout, params:)
        @rollout = rollout
        @params = params
      end

      def execute
        dispatch

        ServiceResponse.success(payload: { rollout: rollout })
      rescue ActiveRecord::RecordInvalid => e
        Gitlab::ErrorTracking.track_exception(e, rollout_id: rollout.id)
        ServiceResponse.error(message: _('Unable to process rollout workflow event.'), payload: { rollout: rollout })
      end

      private

      attr_reader :rollout, :params

      def dispatch
        case params[:type]
        when 'com.gitlab.cd.stage_started', 'com.gitlab.cd.step_started'
          transition_environment('in_progress')
          open_gate if params[:type] == 'com.gitlab.cd.step_started' && approval_step?
        when 'com.gitlab.cd.stage_succeeded', 'com.gitlab.cd.step_succeeded'
          transition_environment('completed')
        when 'com.gitlab.cd.stage_failed', 'com.gitlab.cd.step_failed'
          transition_environment('failed')
        end

        transition_step
      end

      def approval_step?
        params.dig(:data, :step_type) == ::Cd::RolloutStep::APPROVAL_STEP_TYPE
      end

      # Opens an approval gate by journaling a request_approval transition,
      # journal-only per the CD Rails design (approval is a gate, not a
      # state): it does not touch rollout.state. Idempotent against
      # at-least-once retries: a gate already open is left as-is rather than
      # journaling a second request_approval. A rollout that already reached
      # a terminal state (for example, cancelled while the gate was still
      # open) ignores a stale/late-arriving event instead of reopening a gate
      # on a rollout that is already done -- mirroring the terminal-state
      # guard in transition_environment above.
      #
      # The check-then-create is wrapped in #with_lock (same pattern as
      # Cd::Application#next_rollout_iid!) so that two concurrent retries of
      # this event can't both observe an open_approval_gate? of false before
      # either INSERT commits, which would otherwise journal two
      # request_approval rows for the same gate.
      def open_gate
        rollout.with_lock do
          next if rollout.open_approval_gate? || rollout.state.in?(::Cd::Rollout::TERMINAL_STATES.map(&:to_s))

          rollout.rollout_transitions.create!(
            event: ::Cd::RolloutTransition::EVENT_REQUEST_APPROVAL,
            from_state: rollout.state,
            to_state: rollout.state,
            principal: 'system:autoflow'
          )
        end
      end

      def transition_environment(target_state)
        return unless environment_name

        rollout_environment = rollout.rollout_environments.with_environment_name(environment_name).first

        return log_unmatched_environment unless rollout_environment
        return if rollout_environment.state == target_state
        # A terminal environment ignores further events instead of being dragged back
        # to a non-terminal state by a stale/out-of-order retry.
        return if rollout_environment.state.in?(::Cd::RolloutEnvironment::TERMINAL_STATES)

        rollout_environment.update!(state: target_state)
      end

      def transition_step
        return unless step_path

        step = rollout.rollout_steps.with_path(step_path).first
        return log_unmatched_step unless step

        transitioned =
          case params[:type]
          when 'com.gitlab.cd.stage_started', 'com.gitlab.cd.step_started'
            step.start
          when 'com.gitlab.cd.stage_succeeded', 'com.gitlab.cd.step_succeeded'
            step.succeed
          when 'com.gitlab.cd.stage_failed', 'com.gitlab.cd.step_failed'
            step.error = params.dig(:data, :error)
            step.fail_step
          end

        rollout.sync_state_from_steps! if transitioned
      end

      def environment_name
        params.dig(:data, :environment)
      end

      def step_path
        params.dig(:data, :position)&.join('.')
      end

      def log_unmatched_environment
        Gitlab::Cd::Logger.info(
          message: 'Unmatched CD rollout workflow event environment',
          rollout_id: rollout.id,
          rollout_environment_name: environment_name
        )
      end

      def log_unmatched_step
        Gitlab::Cd::Logger.info(
          message: 'Unmatched CD rollout workflow event step',
          rollout_id: rollout.id,
          rollout_step_path: step_path
        )
      end
    end
  end
end

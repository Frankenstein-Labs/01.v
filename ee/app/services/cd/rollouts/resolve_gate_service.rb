# frozen_string_literal: true

module Cd
  module Rollouts
    # Resolves an open approval gate on a rollout by writing the operator's
    # decision (approve or reject) to the Cd::RolloutTransition journal.
    #
    # This is a journal-only write: it records the decision but does not drive
    # the Cd::Rollout state machine. Approval is a gate, not a state (see
    # Cd::Rollout#open_approval_gate?), so the workflow (AutoFlow/KAS) reads
    # the journal and resumes or stops the rollout.
    class ResolveGateService
      # Values reference Cd::RolloutTransition's canonical event constants so
      # the two can't drift out of sync on the literal event strings.
      EVENTS = {
        approved: Cd::RolloutTransition::EVENT_APPROVE,
        rejected: Cd::RolloutTransition::EVENT_REJECT
      }.freeze

      def initialize(rollout, current_user:, status:, reason: nil)
        @rollout = rollout
        @current_user = current_user
        @status = status.to_sym
        @reason = reason
      end

      def execute
        return error([_('Rollout has no open approval gate.')]) unless rollout.open_approval_gate?
        return error([_('Unknown gate status.')]) unless EVENTS.key?(status)

        transition = rollout.rollout_transitions.new(
          event: EVENTS.fetch(status),
          from_state: rollout.state,
          to_state: rollout.state,
          principal: principal,
          reason: reason
        )

        if transition.save
          ServiceResponse.success(payload: { rollout_transition: transition })
        else
          error(transition.errors.full_messages)
        end
      end

      private

      attr_reader :rollout, :current_user, :status, :reason

      def principal
        "user:#{current_user.id}"
      end

      def error(messages)
        ServiceResponse.error(message: Array(messages), payload: { rollout_transition: nil })
      end
    end
  end
end

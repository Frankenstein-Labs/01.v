# frozen_string_literal: true

module Cd
  class Rollout < ApplicationRecord
    include AfterCommitQueue

    self.table_name = 'cd_rollouts'

    ignore_column :environment_id, remove_with: '19.3', remove_after: '2026-08-15'
    ignore_column :group_id, remove_with: '19.2', remove_after: '2026-07-15'

    TERMINAL_STATES = %i[completed failed cancelled].freeze

    belongs_to :version_set, class_name: 'Cd::VersionSet', inverse_of: :rollouts, optional: false
    belongs_to :application, class_name: 'Cd::Application', inverse_of: :rollouts, optional: false
    belongs_to :application_flow_definition, class_name: 'Cd::ApplicationFlowDefinition', optional: true
    belongs_to :organization, class_name: '::Organizations::Organization', optional: false
    has_many :rollout_environments, -> { ordered },
      class_name: 'Cd::RolloutEnvironment', inverse_of: :rollout
    has_many :rollout_transitions, -> { ordered },
      class_name: 'Cd::RolloutTransition', inverse_of: :rollout
    has_many :rollout_steps, -> { ordered },
      class_name: 'Cd::RolloutStep', inverse_of: :rollout

    populate_sharding_key :organization_id, source: :version_set

    # In before_create (not before_validation) so the application row lock is held across the INSERT.
    before_create :ensure_iid

    scope :in_organization, ->(organization) { where(organization_id: organization) }

    scope :search_by_iid, ->(term) {
      normalized = term.to_s.delete_prefix('#').strip
      normalized.match?(/\A\d+\z/) ? where(iid: Integer(normalized, 10)) : none
    }

    # workflow_ref is set when the rollout is kicked off (see
    # Cd::Rollouts::StartService), which also transitions it out of the initial
    # pending state, so it is required in every non-pending state.
    #
    # `cancelled` is an exception: it is reachable directly from `pending` (see
    # the `cancel` event below), so a rollout that was cancelled before ever
    # starting is exempt too. `started_at` (only ever set on entry to
    # `in_progress`) is what distinguishes this case from a rollout that
    # started and was cancelled later, which must still carry a workflow_ref.
    validates :workflow_ref, length: { maximum: 255 }
    validates :workflow_ref, presence: true, unless: -> { pending? || (cancelled? && started_at.nil?) }

    # State machine defining the rollout lifecycle.
    # See https://gitlab.com/groups/gitlab-org/-/work_items/21247#rollout-states
    state_machine :state, initial: :pending do
      # -- Forward flow --
      event :start do
        transition pending: :in_progress
      end

      event :pause do
        transition in_progress: :paused
      end

      event :resume do
        transition paused: :in_progress
      end

      event :complete do
        transition in_progress: :completed
      end

      # Named `fail_rollout` to avoid conflict with Ruby's `Kernel#fail`.
      event :fail_rollout do
        transition in_progress: :failed
      end

      # -- Cancellation --
      # `failed` is intentionally excluded: it is a terminal state, so it has
      # no outgoing transitions.
      # See https://gitlab.com/gitlab-org/gitlab/-/work_items/601918#note_3424864477
      event :cancel do
        transition [:pending, :in_progress, :paused] => :cancelled
      end

      # -- Callbacks --
      before_transition any => :in_progress do |rollout|
        rollout.started_at ||= Time.current
      end

      before_transition any => TERMINAL_STATES do |rollout|
        rollout.finished_at = Time.current
      end

      # `reason: nil` since starting is a plain status update, not a Duo-engagement
      # event (see Types::Cd::RolloutUpdateReasonEnum).
      after_transition pending: :in_progress do |rollout|
        rollout.run_after_commit do
          GraphqlTriggers.cd_rollout_updated(rollout, nil)
        end
      end
    end

    enum :state, {
      pending: 0,
      in_progress: 1,
      paused: 2,
      completed: 3,
      failed: 4,
      cancelled: 5
    }

    # Maps the high-level statuses exposed via the GraphQL API to the
    # underlying state machine states they group together.
    STATES_BY_STATUS = {
      'active' => %w[pending in_progress paused],
      'succeeded' => %w[completed],
      'failed' => %w[failed cancelled]
    }.freeze

    scope :for_statuses, ->(statuses) { where(state: states_for(statuses)) }

    # Unknown statuses are silently ignored (contribute no states) rather than
    # raising or matching a null state, since STATES_BY_STATUS#values_at would
    # otherwise return nil for them.
    def self.states_for(statuses)
      statuses.flat_map { |status| STATES_BY_STATUS.fetch(status, []) }
    end

    def sync_state_from_steps!
      return unless in_progress?

      steps = rollout_steps.to_a
      return fail_rollout if steps.any? { |step| step.state.in?(RolloutStep::FAILURE_STATES) }

      top_level_states = steps.select { |step| step.parent_path.nil? }.map(&:state)
      return if top_level_states.empty?

      complete if top_level_states.all? { |state| state.in?(RolloutStep::TERMINAL_STATES) }
    end

    # Whether this rollout has an open approval gate: an unresolved
    # request_approval in its transition journal. Approval is a gate, not a
    # state, so this is derived rather than read off `state`.
    # See Cd::RolloutTransition::GATE_EVENTS.
    #
    # Ties on created_at are broken by id, matching
    # Cd::RolloutTransition.open_gate_rollout_ids. `reorder` (not `order`) is
    # required here: the rollout_transitions association applies its own
    # `ordered` (created_at ASC) scope, which `order` would only append to,
    # leaving that ascending clause dominant over this method's own ordering.
    def open_approval_gate?
      last_gate_event = rollout_transitions.gate_events.reorder(created_at: :desc, id: :desc).first&.event

      last_gate_event == Cd::RolloutTransition::EVENT_REQUEST_APPROVAL
    end

    private

    def ensure_iid
      self.iid = application.next_rollout_iid! if iid.blank?
    end
  end
end

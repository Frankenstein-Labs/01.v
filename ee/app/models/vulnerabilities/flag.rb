# frozen_string_literal: true

module Vulnerabilities
  class Flag < ::SecApplicationRecord
    self.table_name = 'vulnerability_flags'

    belongs_to :finding, class_name: 'Vulnerabilities::Finding', foreign_key: 'vulnerability_occurrence_id', inverse_of: :vulnerability_flags, optional: false
    FALSE_POSITIVE_DETECTION_STATUSES = {
      not_started: 0,
      dismissed: 1,
      detected_as_fp: 2,
      detected_as_not_fp: 3,
      failed: 4
    }.freeze

    DISMISSABLE_STATUSES = %i[detected_as_fp detected_as_not_fp].freeze

    WORKFLOW_TRIGGER_STATUSES = %i[failed detected_as_not_fp].freeze

    AI_SAST_FP_DETECTION_ORIGIN = 'ai_sast_fp_detection'
    AI_SECRET_DETECTION_FP_DETECTION_ORIGIN = 'ai_secret_detection_fp_detection'

    AI_MANAGED_ORIGINS = [
      AI_SAST_FP_DETECTION_ORIGIN,
      AI_SECRET_DETECTION_FP_DETECTION_ORIGIN
    ].freeze

    belongs_to :workflow, class_name: '::Ai::DuoWorkflows::Workflow', optional: true

    validates :origin, length: { maximum: 255 }
    validates :description, length: { maximum: 100000 }
    validates :flag_type, presence: true, uniqueness: { scope: [:vulnerability_occurrence_id, :origin] }
    validates :confidence_score, inclusion: { in: 0.0..1.0 }

    enum :flag_type, {
      false_positive: 0
    }

    enum :status, FALSE_POSITIVE_DETECTION_STATUSES
    scope :by_finding_id, ->(finding_ids) { where(finding: finding_ids) }
    scope :latest, -> { order(updated_at: :desc) }

    after_commit :trigger_resolution_workflow, on: [:create, :update], if: :should_trigger_resolution_workflow?

    scope :with_associations, -> do
      includes(
        finding: [
          :project,
          { vulnerability: [:group, :author, :project] }
        ]
      )
    end

    scope :with_status, ->(status) { where(status: statuses[status]) }
    scope :last_false_positive_per_finding, -> {
      joins(<<~SQL.squish)
        INNER JOIN (
          SELECT vulnerability_occurrence_id, MAX(id) AS max_id
          FROM vulnerability_flags AS lpf
          WHERE lpf.flag_type = #{flag_types[:false_positive]}
          GROUP BY vulnerability_occurrence_id
        ) AS last_flags
        ON last_flags.vulnerability_occurrence_id = vulnerability_flags.vulnerability_occurrence_id
        AND last_flags.max_id = vulnerability_flags.id
      SQL
    }

    def self.pluck_with_limit(size, *columns)
      limit(size).pluck(*columns)
    end

    def initialize(attributes)
      attributes = attributes.to_h if attributes.respond_to?(:to_h)
      super(attributes)
    end

    def dismissable?
      status.to_sym.in?(DISMISSABLE_STATUSES)
    end

    def triggers_resolution_workflow?
      status.to_sym.in?(WORKFLOW_TRIGGER_STATUSES)
    end

    def eligible_for_resolution_workflow?
      return false unless origin == AI_SAST_FP_DETECTION_ORIGIN
      return false unless triggers_resolution_workflow?
      return false unless finding.project.duo_sast_vr_workflow_enabled
      return false unless finding.eligible_for_resolution_workflow?

      duo_workflow_user_available?
    end

    private

    def trigger_resolution_workflow
      ::Vulnerabilities::TriggerResolutionWorkflowWorker.perform_async(id)
    end

    def should_trigger_resolution_workflow?
      return false unless saved_change_to_id? || saved_change_to_status?
      return false unless eligible_for_resolution_workflow?

      # Automatic SAST false positive detection runs for newly created eligible vulnerabilities.
      # Automatic resolution can be incorrectly skipped only if all of these happen:
      # - The automatic detection workflow is still running.
      # - The same finding is added to a bulk detection execution.
      # - The automatic result arrives after the bulk execution starts.
      # We currently accept this rare race since resolution can still be triggered manually,
      # and avoiding it would require a larger redesign.
      !part_of_bulk_sast_fp_execution?
    end

    def duo_workflow_user_available?
      author = finding.vulnerability&.author
      return false unless author

      Ability.allowed?(author, :duo_workflow, finding.project)
    end

    def part_of_bulk_sast_fp_execution?
      execution = ::Vulnerabilities::BulkDuoWorkflow::ExecutionState.latest(
        project_id: finding.project_id,
        workflow: ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION
      )

      return false unless execution

      execution.contains_item?(finding.uuid)
    end
  end
end

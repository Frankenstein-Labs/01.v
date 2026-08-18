# frozen_string_literal: true

module Vulnerabilities
  module BulkDuoWorkflowRegistry
    extend self

    UNKNOWN_WORKFLOW = 'Unknown workflow: %s'

    WORKFLOWS = {
      ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION => {
        worker: ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker,
        resolve_ids: ->(item_ids) do
          ::Vulnerabilities::Finding.by_uuid(item_ids).pluck_vulnerability_ids
        end
      },
      ::Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION => {
        worker: ::Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker,
        resolve_ids: ->(item_ids) do
          ::Vulnerabilities::Finding.by_uuid(item_ids).pluck_vulnerability_ids
        end
      },
      ::Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION => {
        worker: ::Vulnerabilities::TriggerResolutionWorkflowWorker,
        resolve_ids: ->(item_ids) do
          finding_ids = ::Vulnerabilities::Finding.by_uuid(item_ids).select(:id)
          ::Vulnerabilities::Flag.by_finding_id(finding_ids).false_positive.pluck_with_limit(item_ids.size, :id)
        end
      }
    }.freeze

    def fetch(workflow)
      WORKFLOWS.fetch(workflow) do
        raise ArgumentError, format(UNKNOWN_WORKFLOW, workflow)
      end
    end
  end
end

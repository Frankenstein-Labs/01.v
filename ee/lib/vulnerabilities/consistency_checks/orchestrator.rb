# frozen_string_literal: true

module Vulnerabilities
  module ConsistencyChecks
    class Orchestrator
      CONSISTENCY_CHECKS = [
        HasVulnerabilitiesIsCorrectCheck,
        BackfillIssueLinkOccurrenceIdCheck,
        BackfillMergeRequestLinkOccurrenceIdCheck,
        TriggerParityCheck
      ].freeze

      def initialize(project)
        @project = project
      end

      attr_reader :project

      def execute
        CONSISTENCY_CHECKS.each do |check|
          check.enqueue(project)
        end
      end
    end
  end
end

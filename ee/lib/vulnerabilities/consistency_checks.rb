# frozen_string_literal: true

module Vulnerabilities
  module ConsistencyChecks
    def self.ensure_consistency_on_project!(project)
      return unless Feature.enabled?(:vulnerability_consistency_checks, project)

      Orchestrator.new(project).execute
    end
  end
end

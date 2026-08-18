# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class UpdateArchivedService
      def self.execute(project)
        new(project).execute
      end

      def initialize(project)
        @project = project
      end

      def execute
        return unless project&.analyzer_statuses&.exists?

        update_analyzer_statuses
      end

      private

      attr_reader :project

      def update_analyzer_statuses
        archived = project.self_or_ancestors_archived?
        project.analyzer_statuses.update!(archived: archived)
        project.security_inventory_filters&.update!(archived: archived)
      end
    end
  end
end

# frozen_string_literal: true

module Ai
  module DuoWorkflow
    # Read-only view of how ready a project is to run Duo Agent Platform flows, backing
    # the readiness rows in Settings > General > GitLab Duo.
    class ProjectReadiness
      include ::Gitlab::Utils::StrongMemoize

      def initialize(project)
        @project = project
      end

      def platform_enabled?
        ::Ai::DuoWorkflow.duo_agent_platform_available?(project)
      end
      strong_memoize_attr :platform_enabled?

      # Applies the same gate as Ci::RegisterJobService, so a green row means a queued
      # flow would actually be picked up.
      def runner_available?
        usable_runner.present?
      end

      def usable_runner_type
        usable_runner&.runner_type
      end

      private

      def usable_runner
        candidate_runners.find { |runner| usable_runner?(runner) }
      end
      strong_memoize_attr :usable_runner

      attr_reader :project

      # rubocop:disable CodeReuse/ActiveRecord -- Scoping across Ci::Runner and Ci::RunnerManager
      def candidate_runners
        # RunnerValidator reads runner.groups per candidate; preloading avoids an N+1.
        project.all_available_runners
          .active
          .online
          .with_tag(::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG)
          .preload(:runner_managers, :groups)
      end

      def usable_runner?(runner)
        return false unless ::Ai::DuoWorkflow::RunnerValidator.new(runner, project).valid?

        runner.runner_managers.any? { |manager| RunnerExecutors.docker_compatible?(manager) }
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end

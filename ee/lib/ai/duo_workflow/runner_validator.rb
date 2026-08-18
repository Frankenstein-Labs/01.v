# frozen_string_literal: true

module Ai
  module DuoWorkflow
    class RunnerValidator
      def initialize(runner, project)
        @runner = runner
        @project = project
      end

      def valid?
        return true unless Feature.enabled?(:duo_runner_restrictions, @project)

        # We only allow instance and top level group runners for Duo Agent Platform
        @runner.instance_type? ||
          (@runner.group_type? && @runner.groups.one? && @runner.groups.first.root?)
      end
    end
  end
end

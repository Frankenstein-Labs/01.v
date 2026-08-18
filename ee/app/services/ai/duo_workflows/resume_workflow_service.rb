# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class ResumeWorkflowService < StartWorkflowService
      private

      def variables
        # Preserve job variables from initial workload; refresh only token variables
        previous_vars = previous_workload_variables
        return super if previous_vars.empty?

        previous_vars.merge(token_variables)
      end

      def executor_cli_command
        cmd = super + %( --approval #{@params[:human_approval]})
        if @params[:human_message].present?
          cmd += %( --rejection-reason #{Shellwords.shellescape(@params[:human_message])})
        end

        cmd
      end

      def previous_workload_variables
        build = @workflow.last_workload&.pipeline&.builds&.first
        return {} unless build

        build.yaml_variables.to_h { |v| [v[:key].to_sym, v[:value]] }
      end
    end
  end
end

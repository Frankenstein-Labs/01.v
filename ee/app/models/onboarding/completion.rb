# frozen_string_literal: true

module Onboarding
  class Completion
    include Gitlab::Utils::StrongMemoize

    ACTION_PATHS = [
      :created, # represents "create a repository" item and always checked
      :duo_seat_assigned,
      :pipeline_created,
      :trial_started,
      :required_mr_approvals_enabled,
      :code_owners_enabled,
      :issue_created,
      :code_added,
      :merge_request_created,
      :user_added,
      :license_scanning_run,
      :secure_dependency_scanning_run,
      :secure_dast_run
    ].freeze

    def initialize(project, current_user = nil, onboarding_progress: nil)
      @project = project
      @namespace = project.namespace
      @current_user = current_user
      @onboarding_progress = onboarding_progress
    end

    def percentage
      calculate_percentage(action_columns)
    end

    def get_started_percentage
      calculate_percentage(get_started_action_columns)
    end

    def completed?(column)
      attributes[column].present?
    end

    private

    def calculate_percentage(columns)
      return 0 unless onboarding_progress

      total_actions = columns.count
      completed_actions = columns.count { |column| completed?(column) }

      (completed_actions.to_f / total_actions * 100).round
    end

    def attributes
      onboarding_progress.attributes.symbolize_keys
    end
    strong_memoize_attr :attributes

    def onboarding_progress
      @onboarding_progress ||= ::Onboarding::Progress.find_by(namespace: namespace)
    end

    def action_columns
      ACTION_PATHS.map { |action_key| ::Onboarding::Progress.column_name(action_key) }
    end
    strong_memoize_attr :action_columns

    def get_started_action_columns
      ACTION_PATHS.filter_map do |action_key|
        next if action_key == :created

        ::Onboarding::Progress.column_name(action_key)
      end
    end

    attr_reader :project, :namespace, :current_user
  end
end

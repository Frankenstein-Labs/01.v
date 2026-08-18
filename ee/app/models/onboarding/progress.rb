# frozen_string_literal: true

module Onboarding
  class Progress < ApplicationRecord
    self.table_name = 'onboarding_progresses'

    belongs_to :namespace, optional: false

    validate :namespace_is_root_namespace

    ACTIONS = [
      :created,
      :duo_seat_assigned,
      :merge_request_created,
      :pipeline_created,
      :user_added,
      :trial_started,
      :required_mr_approvals_enabled,
      :code_owners_enabled,
      :issue_created,
      :secure_dependency_scanning_run,
      :secure_dast_run,
      :license_scanning_run,
      :code_added
    ].freeze

    class << self
      def onboard(namespace)
        return unless root_namespace?(namespace)

        create(namespace: namespace)
      end

      def onboarding?(namespace)
        where(namespace: namespace, ended_at: nil).any?
      end

      def register(namespace, actions)
        actions = Array(actions)
        return unless root_namespace?(namespace) && actions.difference(ACTIONS).empty?

        onboarding_progress = find_by(namespace: namespace)
        return unless onboarding_progress

        now = Time.current
        nil_actions = actions.select { |action| onboarding_progress[column_name(action)].nil? }
        return if nil_actions.empty?

        updates = nil_actions.inject({}) { |sum, action| sum.merge!({ column_name(action) => now }) }
        onboarding_progress.update(updates)
      end

      def completed?(namespace, action)
        return false unless root_namespace?(namespace) && ACTIONS.include?(action)

        action_column = column_name(action)
        where(namespace: namespace).where.not(action_column => nil).exists?
      end

      def column_name(action)
        :"#{action}_at"
      end

      private

      def root_namespace?(namespace)
        namespace&.root?
      end
    end

    private

    def namespace_is_root_namespace
      return unless namespace

      errors.add(:namespace, _('must be a root namespace')) if namespace.has_parent?
    end
  end
end

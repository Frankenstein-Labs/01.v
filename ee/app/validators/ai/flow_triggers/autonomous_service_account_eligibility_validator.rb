# frozen_string_literal: true

module Ai
  module FlowTriggers
    class AutonomousServiceAccountEligibilityValidator
      include ActiveModel::Validations

      attr_reader :service_account, :project

      validate :must_be_service_account
      validate :must_be_scoped
      validate :must_be_active
      validate :must_be_project_member

      def initialize(service_account, project)
        @service_account = service_account
        @project = project
      end

      private

      def must_be_service_account
        return if service_account&.service_account?

        errors.add(:base, _('User must be a service account'))
      end

      def must_be_scoped
        return unless service_account&.service_account?
        return if service_account.provisioned_by_group_id.present? || service_account.provisioned_by_project_id.present?

        errors.add(:base, _('Service account must be group or project scoped, not instance-wide'))
      end

      def must_be_active
        return unless service_account
        return if service_account.active?

        errors.add(:base, _('Service account must be active'))
      end

      def must_be_project_member
        return unless service_account && project
        return if project.member?(service_account)

        errors.add(:base, _('Service account must be a member of the target project'))
      end
    end
  end
end

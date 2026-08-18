# frozen_string_literal: true

module ComplianceManagement
  module Frameworks
    class AssignProjectService < BaseService
      def initialize(project, current_user, params)
        @project = project
        @current_user = current_user
        @params = params
      end

      def execute
        return error unless permitted?

        return multiple_frameworks_error if project.compliance_management_frameworks.count > 1

        if removing_framework?
          unassign_compliance_framework
        else
          assign_compliance_framework
        end
      end

      private

      attr_reader :project, :current_user, :params

      def permitted?
        can?(current_user, :admin_compliance_framework, project)
      end

      def assign_compliance_framework
        framework = ComplianceManagement::Framework.find_by_id(params[:framework])

        return error unless framework

        # rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- The only API using this service is deprecated
        # and going to be removed in 18.5 https://gitlab.com/gitlab-org/gitlab/-/issues/534217.
        # We need to temporarily enable the feature for self managed only and hence not using
        # Gitlab::Saas.feature_available?.
        if Gitlab.com? && project_framework_different_namespace?(framework)
          return project_framework_mismatch_error(framework)
        end
        # rubocop: enable Gitlab/AvoidGitlabInstanceChecks

        framework_setting = ComplianceManagement::ComplianceFramework::ProjectSettings
          .find_or_create_by_project(project, framework)

        ComplianceManagement::ProjectComplianceEvaluatorWorker.schedule_compliance_evaluation(
          framework.id, [project.id]
        )

        publish_event(::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added])
        ::ComplianceManagement::ComplianceFrameworkChangesAuditor.new(current_user, framework_setting, project).execute

        success
      end

      def unassign_compliance_framework
        deleted_framework_settings = project.compliance_framework_settings.each(&:destroy!)

        publish_event(::Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed])
        deleted_framework_settings.each do |framework_setting|
          ::ComplianceManagement::ComplianceFrameworkChangesAuditor.new(current_user, framework_setting,
            project).execute

          enqueue_project_compliance_status_removal(framework_setting.framework_id)
        end

        success
      end

      def enqueue_project_compliance_status_removal(framework_id)
        ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker.perform_in(
          ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
          project.id, framework_id
        )
      end

      def publish_event(event_type)
        return unless project.compliance_framework_settings.present?

        event = ::Projects::ComplianceFrameworkChangedEvent.new(data: {
          project_id: project.id,
          compliance_framework_id: project.compliance_framework_settings.first.framework_id,
          event_type: event_type
        })

        ::Gitlab::EventStore.publish(event)
      end

      def removing_framework?
        params[:framework].blank?
      end

      def success
        ServiceResponse.success
      end

      def error
        ServiceResponse.error(message: _('Failed to assign the framework to the project'))
      end

      def multiple_frameworks_error
        ServiceResponse.error(message: _('You cannot assign or unassign frameworks to a project that has more than ' \
          'one associated framework.'))
      end

      def project_framework_different_namespace?(framework)
        project.root_ancestor&.id != framework.namespace_id
      end

      def project_framework_mismatch_error(framework)
        ServiceResponse.error(
          message: format(_('Project %{project_name} and framework %{framework_name} are not from same namespace.'),
            project_name: project.name, framework_name: framework.name
          )
        )
      end
    end
  end
end

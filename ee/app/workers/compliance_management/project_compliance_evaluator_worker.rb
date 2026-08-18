# frozen_string_literal: true

module ComplianceManagement
  class ProjectComplianceEvaluatorWorker
    include ApplicationWorker

    version 1
    data_consistency :sticky
    feature_category :compliance_management
    deduplicate :until_executed, including_scheduled: true
    idempotent!
    urgency :low

    def self.schedule_compliance_evaluation(framework_id, project_ids)
      perform_in(
        ComplianceManagement::ComplianceFramework::ProjectSettings::PROJECT_EVALUATOR_WORKER_DELAY,
        framework_id, project_ids
      )
    end

    def perform(framework_id, project_ids)
      framework = ::ComplianceManagement::Framework.find_by_id(framework_id)
      return unless framework

      # Intersection with framework.project_ids makes sure that the framework is still associated with the projects
      # to be processed
      projects = ::Project.id_in(project_ids & framework.project_ids).to_a
      return if projects.empty?

      requirements = framework.requirements_with_controls.to_a

      projects.each do |project|
        approval_settings = framework.approval_settings_from_security_policies(project)

        requirements.each do |requirement|
          requirement.compliance_requirements_controls.each do |control|
            if control.external?
              # Only trigger external control service for ping-enabled controls
              if control.ping_enabled?
                ::ComplianceManagement::ComplianceFramework::ComplianceRequirements::TriggerExternalControlService
                  .new(project, control).execute
              end
            else
              status = ::ComplianceManagement::ComplianceRequirements::ExpressionEvaluator.new(control,
                project, approval_settings).evaluate

              update_control_status(project, control, status_value(status))
            end
          rescue StandardError => e
            Gitlab::ErrorTracking.log_exception(
              e,
              framework_id: control.compliance_requirement.framework_id,
              control_id: control.id,
              project_id: project.id
            )
          end

          update_requirement_status(project, requirement)
        end
      end
    end

    private

    def status_value(status)
      status ? 'pass' : 'fail'
    end

    def update_control_status(project, control, status)
      ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateStatusService.new(
        current_user: ::Gitlab::Audit::UnauthenticatedAuthor.new,
        control: control,
        project: project,
        status_value: status
      ).execute
    rescue StandardError => e
      Gitlab::ErrorTracking.log_exception(
        e,
        framework_id: control.compliance_requirement.framework_id,
        control_id: control.id,
        project_id: project.id,
        status_value: status
      )
    end

    def update_requirement_status(project, requirement)
      requirement_status = ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus
        .find_or_create_project_and_requirement(project, requirement)

      ComplianceManagement::ComplianceFramework::ComplianceRequirements::RefreshStatusService.new(requirement_status)
        .execute
    end
  end
end

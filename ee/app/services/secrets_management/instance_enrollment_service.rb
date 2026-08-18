# frozen_string_literal: true

module SecretsManagement
  class InstanceEnrollmentService
    def initialize(current_user:)
      @current_user = current_user
    end

    # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- instance enrollment is self-managed only
    def enroll
      return not_self_managed_error if ::Gitlab.com?
      return already_enrolled_response if InstanceEnrollment.enrolled?

      update_setting(true)
      audit_event(name: 'secrets_manager_instance_enroll', message: 'Enrolled instance in Secrets Manager')

      ServiceResponse.success
    end

    def unenroll
      return not_self_managed_error if ::Gitlab.com?
      return not_enrolled_response unless InstanceEnrollment.enrolled?

      update_setting(false)
      audit_event(name: 'secrets_manager_instance_unenroll', message: 'Unenrolled instance from Secrets Manager')

      ServiceResponse.success
    end
    # rubocop:enable Gitlab/AvoidGitlabInstanceChecks

    private

    attr_reader :current_user

    def update_setting(value)
      ::Gitlab::CurrentSettings.update!(secrets_manager_instance_enrolled: value)
      ::Gitlab::CurrentSettings.expire_current_application_settings
    rescue StandardError => e
      ::Gitlab::ErrorTracking.track_exception(e)
      raise
    end

    def audit_event(name:, message:)
      scope = ::Gitlab::Audit::InstanceScope.new

      ::Gitlab::Audit::Auditor.audit({
        name: name,
        author: current_user,
        scope: scope,
        target: scope,
        message: message
      })
    end

    def not_self_managed_error
      ServiceResponse.error(message: 'Instance enrollment is only available on self-managed instances.')
    end

    def already_enrolled_response
      ServiceResponse.error(message: 'Instance is already enrolled.')
    end

    def not_enrolled_response
      ServiceResponse.error(message: 'Instance is not enrolled.', reason: :not_found)
    end
  end
end

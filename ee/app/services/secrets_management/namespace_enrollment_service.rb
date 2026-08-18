# frozen_string_literal: true

module SecretsManagement
  class NamespaceEnrollmentService
    def initialize(namespace, current_user:)
      @namespace = namespace
      @current_user = current_user
    end

    def enroll
      return enrollment_not_allowed_error unless NamespaceEnrollment.enrollment_allowed?(namespace)
      return already_enrolled_response if NamespaceEnrollment.enrolled?(namespace)

      enrollment = NamespaceEnrollment.create!(namespace: namespace, beta: beta_enrollment?)
      audit_event(name: 'secrets_manager_namespace_enroll', message: 'Enrolled namespace in Secrets Manager')

      ServiceResponse.success(payload: { enrollment: enrollment })
    rescue ActiveRecord::RecordNotUnique
      already_enrolled_response
    end

    def unenroll
      return enrollment_not_allowed_error unless NamespaceEnrollment.enrollment_allowed?(namespace)

      enrollment = NamespaceEnrollment.find_by_namespace_id(namespace.id)
      return not_found_response unless enrollment

      enrollment.destroy!
      audit_event(name: 'secrets_manager_namespace_unenroll', message: 'Unenrolled namespace from Secrets Manager')

      ServiceResponse.success
    end

    private

    attr_reader :namespace, :current_user

    # Namespaces that enroll before the paid experience reaches them are part of the free beta cohort.
    def beta_enrollment?
      !::Feature.enabled?(:secrets_manager_paid_experience, namespace)
    end

    def audit_event(name:, message:)
      ::Gitlab::Audit::Auditor.audit({
        name: name,
        author: current_user,
        scope: namespace,
        target: namespace,
        message: message
      })
    end

    def enrollment_not_allowed_error
      ServiceResponse.error(message: 'Namespace enrollment is not allowed.', reason: :forbidden)
    end

    def already_enrolled_response
      ServiceResponse.error(message: 'Namespace is already enrolled.')
    end

    def not_found_response
      ServiceResponse.error(message: 'Enrollment not found.', reason: :not_found)
    end
  end
end

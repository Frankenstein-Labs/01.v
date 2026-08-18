# frozen_string_literal: true

module SecretsManagement
  class NamespaceEnrollment < ApplicationRecord
    self.table_name = 'secrets_manager_namespace_enrollments'

    belongs_to :namespace, optional: false

    scope :for_namespace, ->(namespace) { where(namespace_id: namespace.id) }

    def self.enrolled?(namespace)
      for_namespace(namespace.root_ancestor).exists?
    end

    def self.beta_enrolled?(namespace)
      for_namespace(namespace.root_ancestor).where(beta: true).exists?
    end

    def self.enrollment_allowed?(namespace)
      return false unless namespace.is_a?(Group)
      return false unless namespace.root?

      ::Gitlab.com? && # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- namespace enrollment is SaaS only
        namespace.licensed_feature_available?(:native_secrets_management) &&
        ::Feature.enabled?(:secrets_manager_namespace_enrollment, namespace.root_ancestor)
    end

    def self.find_by_namespace_id(namespace_id)
      find_by(namespace_id: namespace_id)
    end
  end
end

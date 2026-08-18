# frozen_string_literal: true

module SecretsManagement
  class Availability
    LICENSED_FEATURE = :native_secrets_management

    class << self
      def for_project?(project)
        licensed?(project) && enabled_for_project?(project)
      end

      def for_group?(group)
        licensed?(group) && enabled_for_group?(group)
      end

      def for_instance?
        ::License.feature_available?(LICENSED_FEATURE) && InstanceEnrollment.enrolled?
      end

      def enabled_for_project?(project)
        ::Feature.enabled?(:secrets_manager, project) && enrolled?(project)
      end

      def enabled_for_group?(group)
        return false unless ::Feature.enabled?(:group_secrets_manager, group)

        paid_experience_root_group?(group) || enrolled?(group)
      end

      private

      def licensed?(resource)
        resource.licensed_feature_available?(LICENSED_FEATURE)
      end

      def paid_experience_root_group?(group)
        group.root? && ::Feature.enabled?(:secrets_manager_paid_experience, group)
      end

      # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- routing between SaaS and self-managed enrollment
      def enrolled?(resource)
        if ::Gitlab.com?
          NamespaceEnrollment.enrolled?(resource)
        else
          InstanceEnrollment.enrolled?
        end
      end
      # rubocop:enable Gitlab/AvoidGitlabInstanceChecks
    end
  end
end

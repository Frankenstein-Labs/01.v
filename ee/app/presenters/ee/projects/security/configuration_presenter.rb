# frozen_string_literal: true

module EE
  module Projects
    module Security
      module ConfigurationPresenter
        extend ::Gitlab::Utils::Override

        override :to_h
        def to_h
          super.merge(vulnerability_archive_export_path: vulnerability_archive_export_path)
        end

        private

        def vulnerability_archive_export_path
          api_v4_security_projects_vulnerability_archive_exports_path(id: project.id)
        end

        override :container_scanning_for_registry_enabled
        def container_scanning_for_registry_enabled
          project_settings&.container_scanning_for_registry_enabled
        end

        override :secret_push_protection_enforced
        def secret_push_protection_enforced
          ::Gitlab::CurrentSettings.current_application_settings.secret_push_protection_enforced
        end

        override :cvs_for_container_scanning_enabled
        def cvs_for_container_scanning_enabled
          project_settings&.cvs_for_container_scanning_enabled
        end

        override :cvs_for_dependency_scanning_enabled
        def cvs_for_dependency_scanning_enabled
          project_settings&.cvs_for_dependency_scanning_enabled
        end

        override :license_scanning_for_cyclonedx_enabled
        def license_scanning_for_cyclonedx_enabled
          project_settings&.license_scanning_for_cyclonedx_enabled
        end

        override :secret_push_protection_enabled
        def secret_push_protection_enabled
          project_settings&.secret_push_protection_enabled
        end

        override :validity_checks_available
        def validity_checks_available
          project.licensed_feature_available?(:secret_detection_validity_checks)
        end

        override :validity_checks_enabled
        def validity_checks_enabled
          project_settings&.validity_checks_enabled
        end

        override :license_scanning_for_cyclonedx_available
        def license_scanning_for_cyclonedx_available
          project.licensed_feature_available?(:license_scanning)
        end

        override :features
        def features
          result = super
          result << scan(:container_scanning_for_registry, configured: container_scanning_for_registry_enabled)

          if license_scanning_for_cyclonedx_available
            result << scan(:license_scanning_for_cyclonedx, configured: license_scanning_for_cyclonedx_enabled)
          end

          if cvs_for_container_scanning_available
            result << scan(:cvs_for_container_scanning, configured: cvs_for_container_scanning_enabled)
          end

          if cvs_for_dependency_scanning_available
            result << scan(:cvs_for_dependency_scanning, configured: cvs_for_dependency_scanning_enabled)
          end

          result
        end

        override :cvs_for_container_scanning_available
        def cvs_for_container_scanning_available
          project.licensed_feature_available?(:container_scanning)
        end

        override :cvs_for_dependency_scanning_available
        def cvs_for_dependency_scanning_available
          project.licensed_feature_available?(:dependency_scanning)
        end

        override :secret_detection_configuration_path
        def secret_detection_configuration_path
          project_security_configuration_secret_detection_path(project)
        end

        override :license_configuration_source
        def license_configuration_source
          project_settings&.license_configuration_source&.upcase ||
            ::Enums::Security::DEFAULT_CONFIGURATION_SOURCE.to_s.upcase
        end

        override :upgrade_path
        def upgrade_path
          return super unless show_discover_project_security?

          project_security_discover_path(project)
        end

        override :group_manage_attributes_path
        def group_manage_attributes_path
          return unless root_group

          group_security_configuration_path(root_group, tab: 'attributes')
        end

        override :max_tracked_refs
        def max_tracked_refs
          ::Security::ProjectTrackedContext.max_tracked_refs_for_project(project)
        end

        def show_discover_project_security?
          current_user &&
            ::Gitlab.com? && # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- Matching legacy code for consistency
            !project.licensed_feature_available?(:security_dashboard) &&
            can?(current_user, :admin_namespace, project.root_ancestor)
        end
      end
    end
  end
end

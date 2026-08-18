# frozen_string_literal: true

module EE
  module Organizations
    module Organization
      extend ActiveSupport::Concern

      prepended do
        include ::Ai::FoundationalAgentsStatusable
        include ::ArtifactRegistry::CachesClient

        has_many :active_projects,
          -> { non_archived },
          class_name: 'Project',
          inverse_of: :organization
        has_many :add_on_purchases,
          class_name: 'GitlabSubscriptions::AddOnPurchase',
          inverse_of: :organization
        has_many :seat_assignments,
          class_name: 'GitlabSubscriptions::SeatAssignment',
          inverse_of: :organization
        has_many :user_add_on_assignments,
          class_name: 'GitlabSubscriptions::UserAddOnAssignment',
          inverse_of: :organization
        has_many :vulnerability_exports, class_name: 'Vulnerabilities::Export'
        has_many :sbom_sources, class_name: 'Sbom::Source'
        has_many :sbom_source_packages, class_name: 'Sbom::SourcePackage'
        has_many :sbom_components, class_name: 'Sbom::Component'
        has_many :sbom_component_versions, class_name: 'Sbom::ComponentVersion'
        has_many :organization_cluster_agent_mappings,
          class_name: 'RemoteDevelopment::OrganizationClusterAgentMapping',
          inverse_of: :organization
        has_many :mapped_agents, through: :organization_cluster_agent_mappings, source: :agent

        has_many :custom_dashboards,
          class_name: 'Analytics::CustomDashboards::Dashboard',
          foreign_key: :organization_id,
          inverse_of: :organization

        has_many :foundational_agents_status_records,
          class_name: 'Ai::OrganizationFoundationalAgentStatus',
          inverse_of: :organization

        has_one :artifact_registry_namespace_mapping,
          class_name: 'ArtifactRegistry::NamespaceMapping',
          inverse_of: :organization

        def foundational_agents_default_enabled
          ::Ai::Setting.for_organization_read_only(self).foundational_agents_default_enabled
        end

        # Slug discovery against the organization's namespaces replaces the placeholder;
        # see https://gitlab.com/gitlab-org/gitlab/-/work_items/602638.
        def artifact_registry_slug
          ::Organizations::ArtifactRegistry::STUB_SLUG
        end

        def policy_store_experiment_active?
          ::Feature.enabled?(:security_policies_v2, :instance) &&
            ::Gitlab::CurrentSettings.policy_store_experiment_enabled? &&
            ::License.feature_available?(:security_orchestration_policies)
        end
      end
    end
  end
end

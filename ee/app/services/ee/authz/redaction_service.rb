# frozen_string_literal: true

module EE
  module Authz
    module RedactionService
      extend ::Gitlab::Utils::Override

      EE_RESOURCE_CLASSES = {
        epic: ::Epic,
        vulnerability: ::Vulnerability,
        ci_pipeline: ::Ci::Pipeline,
        ci_stage: ::Ci::Stage,
        ci_build: ::Ci::Build,
        ci_runner: ::Ci::Runner,
        label: ::Label,
        note: ::Note,
        security_scan: ::Security::Scan,
        security_finding: ::Security::Finding,
        vulnerability_scanner: ::Vulnerabilities::Scanner,
        vulnerability_occurrence: ::Vulnerabilities::Finding,
        vulnerability_identifier: ::Vulnerabilities::Identifier,
        group: ::Group,
        deployment: ::Deployment,
        environment: ::Environment,
        package: ::Packages::Package,
        package_file: ::Packages::PackageFile,
        dependency: ::Packages::Dependency,
        container_repository: ::ContainerRepository
      }.freeze

      EE_PRELOAD_ASSOCIATIONS = {
        epic: [{ group: [:organization, :saml_provider] }, :work_item],
        vulnerability: [{ project: [:namespace, :project_feature, :group, :organization] }],
        ci_pipeline: [{ project: [:namespace, :project_feature, :group, :organization] }],
        ci_stage: [{ pipeline: { project: [:namespace, :project_feature, :group, :organization] } }],
        ci_build: [{ project: [:namespace, :project_feature, :group, :organization] }],
        ci_runner: [{ groups: [:parent, :organization] }, { projects: [:namespace, :group, :organization] }],
        label: [{ project: [:namespace, :project_feature, :group, :organization] }, :group],
        note: [{ noteable: [:namespace, :author, { project: [:namespace, :project_feature, :group, :organization] }] },
          :system_note_metadata, :author, { project: [:namespace, :project_feature, :group, :organization] }],
        security_scan: [:project, { build: { project: [:namespace, :project_feature, :group, :organization] } }],
        security_finding: [{ scan: { build: { project: [:namespace, :project_feature, :group, :organization] } } }],
        vulnerability_scanner: [{ project: [:namespace, :project_feature, :group, :organization] }],
        vulnerability_occurrence: [{ project: [:namespace, :project_feature, :group, :organization] }],
        vulnerability_identifier: [{ project: [:namespace, :project_feature, :group, :organization] }],
        group: [:parent, :organization, :saml_provider],
        deployment: [{ project: [:namespace, :project_feature, :group, :organization] }],
        environment: [{ project: [:namespace, :project_feature, :group, :organization] }],
        package: [{ project: [:namespace, :project_feature, :group, :organization] }],
        package_file: [
          { project: [:namespace, :project_feature, :group, :organization] },
          { package: { project: [:namespace, :project_feature, :group, :organization] } }
        ],
        dependency: [{ project: [:namespace, :project_feature, :group, :organization] }],
        container_repository: [{ project: [:namespace, :project_feature, :group, :organization] }]
      }.freeze

      module ClassMethods
        extend ::Gitlab::Utils::Override

        override :supported_types
        def supported_types
          (super + EE::Authz::RedactionService::EE_RESOURCE_CLASSES.keys.map(&:to_s)).uniq
        end
      end

      def self.prepended(base)
        base.singleton_class.prepend ClassMethods
      end

      private

      override :load_resources_for_type
      # rubocop:disable CodeReuse/ActiveRecord -- Batch loading with preloads for authorization checks
      def load_resources_for_type(type, ids)
        return super unless EE_RESOURCE_CLASSES.key?(type)
        return {} if ids.blank?

        klass = EE_RESOURCE_CLASSES[type]
        preloads = EE_PRELOAD_ASSOCIATIONS[type]
        relation = klass.where(id: ids)
        relation = relation.includes(*preloads) if preloads.present?
        relation.index_by(&:id)
      end
      # rubocop:enable CodeReuse/ActiveRecord

      override :authorize_resources_of_type
      def authorize_resources_of_type(type, ids, ability, loaded_resources)
        return super unless EE_RESOURCE_CLASSES.key?(type)
        return {} if ids.blank?

        ids.index_with do |id|
          resource = loaded_resources[id]

          next false if resource.nil?

          check_ability(resource, ability)
        end
      end
    end
  end
end

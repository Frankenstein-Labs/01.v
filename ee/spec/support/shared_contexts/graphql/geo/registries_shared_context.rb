# frozen_string_literal: true

RSpec.shared_context 'with geo registries shared context' do
  using RSpec::Parameterized::TableSyntax

  where(:registry_class, :registry_type, :registry_factory) do
    # rubocop:disable Layout/LineLength
    Geo::AbuseReportUploadRegistry            | Types::Geo::AbuseReportUploadRegistryType            | :geo_abuse_report_upload_registry
    Geo::AchievementUploadRegistry            | Types::Geo::AchievementUploadRegistryType            | :geo_achievement_upload_registry
    Geo::AiVectorizableFileUploadRegistry     | Types::Geo::AiVectorizableFileUploadRegistryType     | :geo_ai_vectorizable_file_upload_registry
    Geo::AlertManagementMetricImageUploadRegistry | Types::Geo::AlertManagementMetricImageUploadRegistryType | :geo_alert_management_metric_image_upload_registry
    Geo::AppearanceUploadRegistry | Types::Geo::AppearanceUploadRegistryType | :geo_appearance_upload_registry
    Geo::BulkImportExportUploadUploadRegistry | Types::Geo::BulkImportExportUploadUploadRegistryType | :geo_bulk_import_export_upload_upload_registry
    Geo::CiSecureFileRegistry                 | Types::Geo::CiSecureFileRegistryType                 | :geo_ci_secure_file_registry
    Geo::ContainerRepositoryRegistry          | Types::Geo::ContainerRepositoryRegistryType          | :geo_container_repository_registry
    Geo::DependencyListExportPartUploadRegistry | Types::Geo::DependencyListExportPartUploadRegistryType | :geo_dependency_list_export_part_upload_registry
    Geo::DependencyListExportUploadRegistry   | Types::Geo::DependencyListExportUploadRegistryType   | :geo_dependency_list_export_upload_registry
    Geo::DependencyProxyBlobRegistry          | Types::Geo::DependencyProxyBlobRegistryType          | :geo_dependency_proxy_blob_registry
    Geo::DependencyProxyManifestRegistry      | Types::Geo::DependencyProxyManifestRegistryType      | :geo_dependency_proxy_manifest_registry
    Geo::DesignManagementActionUploadRegistry | Types::Geo::DesignManagementActionUploadRegistryType | :geo_design_management_action_upload_registry
    Geo::DesignManagementRepositoryRegistry   | Types::Geo::DesignManagementRepositoryRegistryType   | :geo_design_management_repository_registry
    Geo::GroupUploadRegistry                  | Types::Geo::GroupUploadRegistryType                  | :geo_group_upload_registry
    Geo::GroupWikiRepositoryRegistry          | Types::Geo::GroupWikiRepositoryRegistryType          | :geo_group_wiki_repository_registry
    Geo::ImportExportUploadUploadRegistry     | Types::Geo::ImportExportUploadUploadRegistryType     | :geo_import_export_upload_upload_registry
    Geo::IssuableMetricImageUploadRegistry    | Types::Geo::IssuableMetricImageUploadRegistryType    | :geo_issuable_metric_image_upload_registry
    Geo::JobArtifactRegistry                  | Types::Geo::JobArtifactRegistryType                  | :geo_job_artifact_registry
    Geo::LfsObjectRegistry                    | Types::Geo::LfsObjectRegistryType                    | :geo_lfs_object_registry
    Geo::MergeRequestDiffRegistry             | Types::Geo::MergeRequestDiffRegistryType             | :geo_merge_request_diff_registry
    Geo::OrganizationDetailUploadRegistry | Types::Geo::OrganizationDetailUploadRegistryType | :geo_organization_detail_upload_registry
    Geo::PackageFileRegistry | Types::Geo::PackageFileRegistryType | :geo_package_file_registry
    Geo::PackagesDebianProjectComponentFileRegistry | Types::Geo::PackagesDebianProjectComponentFileRegistryType | :geo_packages_debian_project_component_file_registry
    Geo::PackagesHelmMetadataCacheRegistry    | Types::Geo::PackagesHelmMetadataCacheRegistryType    | :geo_packages_helm_metadata_cache_registry
    Geo::PackagesNugetSymbolRegistry          | Types::Geo::PackagesNugetSymbolRegistryType          | :geo_packages_nuget_symbol_registry
    Geo::PagesDeploymentRegistry              | Types::Geo::PagesDeploymentRegistryType              | :geo_pages_deployment_registry
    Geo::PersonalSnippetUploadRegistry        | Types::Geo::PersonalSnippetUploadRegistryType        | :geo_personal_snippet_upload_registry
    Geo::PipelineArtifactRegistry             | Types::Geo::PipelineArtifactRegistryType             | :geo_pipeline_artifact_registry
    Geo::ProjectImportExportRelationExportUploadUploadRegistry | Types::Geo::ProjectImportExportRelationExportUploadUploadRegistryType | :geo_project_import_export_relation_export_upload_upload_registry
    Geo::ProjectRepositoryRegistry | Types::Geo::ProjectRepositoryRegistryType | :geo_project_repository_registry
    Geo::ProjectTopicUploadRegistry | Types::Geo::ProjectTopicUploadRegistryType | :geo_project_topic_upload_registry
    Geo::ProjectUploadRegistry                | Types::Geo::ProjectUploadRegistryType                | :geo_project_upload_registry
    Geo::ProjectWikiRepositoryRegistry        | Types::Geo::ProjectWikiRepositoryRegistryType        | :geo_project_wiki_repository_registry
    Geo::SnippetRepositoryRegistry            | Types::Geo::SnippetRepositoryRegistryType            | :geo_snippet_repository_registry
    Geo::TerraformStateVersionRegistry        | Types::Geo::TerraformStateVersionRegistryType        | :geo_terraform_state_version_registry
    Geo::UploadRegistry                       | Types::Geo::UploadRegistryType                       | :geo_upload_registry
    Geo::UserPermissionExportUploadUploadRegistry | Types::Geo::UserPermissionExportUploadUploadRegistryType | :geo_user_permission_export_upload_upload_registry
    Geo::UserUploadRegistry | Types::Geo::UserUploadRegistryType | :geo_user_upload_registry
    Geo::VulnerabilityArchiveExportUploadRegistry | Types::Geo::VulnerabilityArchiveExportUploadRegistryType | :geo_vulnerability_archive_export_upload_registry
    Geo::VulnerabilityExportPartUploadRegistry | Types::Geo::VulnerabilityExportPartUploadRegistryType | :geo_vulnerability_export_part_upload_registry
    Geo::VulnerabilityExportUploadRegistry | Types::Geo::VulnerabilityExportUploadRegistryType | :geo_vulnerability_export_upload_registry
    Geo::VulnerabilityRemediationUploadRegistry | Types::Geo::VulnerabilityRemediationUploadRegistryType | :geo_vulnerability_remediation_upload_registry
    # rubocop:enable Layout/LineLength
  end
end

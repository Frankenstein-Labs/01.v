# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GeoNode'], feature_category: :geo_replication do
  it { expect(described_class).to require_graphql_authorizations(:read_geo_node) }

  it 'has the expected fields' do
    expected_fields = %i[
      abuse_report_upload_registries
      achievement_upload_registries
      ai_vectorizable_file_upload_registries
      alert_management_metric_image_upload_registries
      appearance_upload_registries
      bulk_import_export_upload_upload_registries
      ci_secure_file_registries
      checksum_mismatch_report_threshold
      checksum_mismatch_self_heal_cooldown_minutes
      container_repositories_max_capacity
      container_repository_registries
      dependency_list_export_part_upload_registries
      dependency_list_export_upload_registries
      dependency_proxy_blob_registries
      dependency_proxy_manifest_registries
      design_management_action_upload_registries
      design_management_repository_registries
      enabled
      files_max_capacity
      group_upload_registries
      group_wiki_repository_registries
      id
      import_export_upload_upload_registries
      internal_url
      issuable_metric_image_upload_registries
      job_artifact_registries
      lfs_object_registries
      merge_request_diff_registries
      minimum_reverification_interval
      name
      organization_detail_upload_registries
      package_file_registries
      packages_debian_project_component_file_registries
      packages_helm_metadata_cache_registries
      packages_nuget_symbol_registries
      pages_deployment_registries
      personal_snippet_upload_registries
      pipeline_artifact_registries
      primary
      project_import_export_relation_export_upload_upload_registries
      project_repository_registries
      project_topic_upload_registries
      project_upload_registries
      project_wiki_repository_registries
      repos_max_capacity
      selective_sync_namespaces
      selective_sync_shards
      selective_sync_type
      snippet_repository_registries
      sync_object_storage
      terraform_state_version_registries
      upload_registries
      url
      user_permission_export_upload_upload_registries
      user_upload_registries
      verification_max_capacity
      vulnerability_archive_export_upload_registries
      vulnerability_export_part_upload_registries
      vulnerability_export_upload_registries
      vulnerability_remediation_upload_registries
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end

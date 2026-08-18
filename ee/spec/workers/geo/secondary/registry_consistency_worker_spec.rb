# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Secondary::RegistryConsistencyWorker, :geo, feature_category: :geo_replication do
  include EE::GeoHelpers
  include ExclusiveLeaseHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }

  let(:batch_size) { described_class::BATCH_SIZE }

  subject(:job) { described_class.new }

  before do
    stub_current_geo_node(secondary)
    stub_registry_replication_config(enabled: true)
  end

  it_behaves_like 'reenqueuer'

  it 'uses a cronjob queue' do
    expect(subject.sidekiq_options_hash).to include(
                                              'queue_namespace' => :cronjob
                                            )
    expect(subject.class.generated_queue_name).to include('cronjob:geo_secondary_registry_consistency')
  end

  describe '#perform' do
    before do
      allow(subject).to receive(:sleep) # faster tests
    end

    context 'when container registry is enabled' do
      before do
        stub_container_registry_config(enabled: true)
      end

      # Somewhat of an integration test
      it 'creates missing registries for each registry class' do
        project = create(:project)
        container_repository = create(:container_repository, project: project)
        create(:design, project: project)
        job_artifact = create(:ci_job_artifact)
        lfs_object = create(:lfs_object)
        merge_request_diff = create(:merge_request_diff, :external)
        package_file = create(:conan_package_file, :conan_package)
        terraform_state_version = create(:terraform_state_version)
        pipeline_artifact = create(:ci_pipeline_artifact)
        upload = create(:upload)
        pages_deployment = create(:pages_deployment)
        ci_secure_file = create(:ci_secure_file)
        dependency_proxy_blob = create(:dependency_proxy_blob)
        dependency_proxy_manifest = create(:dependency_proxy_manifest)
        project_wiki_repository = create(:project_wiki_repository, project: project)
        design_management_repository = create(:design_management_repository, project: project)
        nuget_symbol = create(:nuget_symbol)
        supply_chain_attestation = create(:supply_chain_attestation)
        helm_metadata_cache = create(:helm_metadata_cache)
        packages_debian_project_component_file = create(:debian_project_component_file)

        expect(Geo::ContainerRepositoryRegistry.where(container_repository_id: container_repository.id).count).to eq(0)
        expect(Geo::DesignManagementRepositoryRegistry.where(design_management_repository_id: design_management_repository.id).count).to eq(0)
        expect(Geo::JobArtifactRegistry.where(artifact_id: job_artifact.id).count).to eq(0)
        expect(Geo::LfsObjectRegistry.where(lfs_object_id: lfs_object.id).count).to eq(0)
        expect(Geo::MergeRequestDiffRegistry.where(merge_request_diff_id: merge_request_diff.id).count).to eq(0)
        expect(Geo::PackageFileRegistry.where(package_file_id: package_file.id).count).to eq(0)
        expect(Geo::PipelineArtifactRegistry.where(pipeline_artifact_id: pipeline_artifact.id).count).to eq(0)
        expect(Geo::TerraformStateVersionRegistry.where(terraform_state_version_id: terraform_state_version.id).count).to eq(0)
        expect(Geo::UploadRegistry.where(file_id: upload.id).count).to eq(0)
        expect(Geo::PagesDeploymentRegistry.where(pages_deployment: pages_deployment.id).count).to eq(0)
        expect(Geo::JobArtifactRegistry.where(job_artifact: job_artifact.id).count).to eq(0)
        expect(Geo::CiSecureFileRegistry.where(ci_secure_file: ci_secure_file.id).count).to eq(0)
        expect(Geo::DependencyProxyBlobRegistry.where(dependency_proxy_blob: dependency_proxy_blob.id).count).to eq(0)
        expect(Geo::DependencyProxyManifestRegistry.where(dependency_proxy_manifest: dependency_proxy_manifest.id).count).to eq(0)
        expect(Geo::ProjectWikiRepositoryRegistry.where(project_wiki_repository: project_wiki_repository.id).count).to eq(0)
        expect(Geo::ProjectRepositoryRegistry.where(project_id: project.id).count).to eq(0)
        expect(Geo::PackagesNugetSymbolRegistry.where(packages_nuget_symbol_id: nuget_symbol.id).count).to eq(0)
        expect(Geo::SupplyChainAttestationRegistry.where(supply_chain_attestation_id: supply_chain_attestation.id).count).to eq(0)
        expect(Geo::PackagesHelmMetadataCacheRegistry.where(packages_helm_metadata_cache_id: helm_metadata_cache.id).count).to eq(0)
        expect(Geo::PackagesDebianProjectComponentFileRegistry.where(packages_debian_project_component_file_id: packages_debian_project_component_file.id).count).to eq(0)

        subject.perform

        expect(Geo::ContainerRepositoryRegistry.where(container_repository_id: container_repository.id).count).to eq(1)
        expect(Geo::JobArtifactRegistry.where(artifact_id: job_artifact.id).count).to eq(1)
        expect(Geo::LfsObjectRegistry.where(lfs_object_id: lfs_object.id).count).to eq(1)
        expect(Geo::MergeRequestDiffRegistry.where(merge_request_diff_id: merge_request_diff.id).count).to eq(1)
        expect(Geo::PackageFileRegistry.where(package_file_id: package_file.id).count).to eq(1)
        expect(Geo::PipelineArtifactRegistry.where(pipeline_artifact_id: pipeline_artifact.id).count).to eq(1)
        expect(Geo::TerraformStateVersionRegistry.where(terraform_state_version_id: terraform_state_version.id).count).to eq(1)
        expect(Geo::UploadRegistry.where(file_id: upload.id).count).to eq(1)
        expect(Geo::PagesDeploymentRegistry.where(pages_deployment: pages_deployment.id).count).to eq(1)
        expect(Geo::JobArtifactRegistry.where(job_artifact: job_artifact.id).count).to eq(1)
        expect(Geo::CiSecureFileRegistry.where(ci_secure_file: ci_secure_file.id).count).to eq(1)
        expect(Geo::DependencyProxyBlobRegistry.where(dependency_proxy_blob: dependency_proxy_blob.id).count).to eq(1)
        expect(Geo::DependencyProxyManifestRegistry.where(dependency_proxy_manifest: dependency_proxy_manifest.id).count).to eq(1)
        expect(Geo::ProjectWikiRepositoryRegistry.where(project_wiki_repository: project_wiki_repository.id).count).to eq(1)
        expect(Geo::ProjectRepositoryRegistry.where(project_id: project.id).count).to eq(1)
        expect(Geo::PackagesNugetSymbolRegistry.where(packages_nuget_symbol_id: nuget_symbol.id).count).to eq(1)
        expect(Geo::SupplyChainAttestationRegistry.where(supply_chain_attestation_id: supply_chain_attestation.id).count).to eq(1)
        expect(Geo::PackagesHelmMetadataCacheRegistry.where(packages_helm_metadata_cache_id: helm_metadata_cache.id).count).to eq(1)
        expect(Geo::PackagesDebianProjectComponentFileRegistry.where(packages_debian_project_component_file_id: packages_debian_project_component_file.id).count).to eq(1)
      end
    end

    context 'when container registry is disabled' do
      before do
        stub_container_registry_config(enabled: false)
      end

      it 'does not create a ContainerRepositoryRegistry' do
        container_repository = create(:container_repository)

        subject.perform

        expect(
          Geo::ContainerRepositoryRegistry.where(container_repository_id: container_repository.id)
        ).to be_empty
      end
    end

    it_behaves_like '#perform is rate limited to 1 call per', 5.seconds

    # Use subject.send(:registry_classes) instead of REGISTRY_CLASSES so that
    # expectations are set only for the classes the worker will actually process.
    # Partition upload registries (e.g. GroupUploadRegistry) are filtered out
    # by registry_consistency_worker_enabled? when the legacy Upload replicator
    # is active, so iterating the constant would set up expectations that are
    # never fulfilled and cause spurious failures.
    context 'when RegistryConsistencyService#execute returns true at least once' do
      before do
        subject.send(:registry_classes).each_with_index do |registry_class, index|
          first_one = index == 0
          service = double
          expect(Geo::RegistryConsistencyService).to receive(:new).with(registry_class, batch_size: batch_size).and_return(service)
          expect(service).to receive(:execute).and_return(first_one)
        end
      end

      it 'returns true' do
        expect(subject.perform).to be_truthy
      end

      it 'RegistryConsistencyWorker gets reenqueued' do
        expect(described_class).to receive(:perform_async)

        subject.perform
      end
    end

    context 'when RegistryConsistencyService#execute returns false for all registry classes' do
      before do
        subject.send(:registry_classes).each do |registry_class|
          service = double
          expect(Geo::RegistryConsistencyService).to receive(:new).with(registry_class, batch_size: batch_size).and_return(service)
          expect(service).to receive(:execute).and_return(false)
        end
      end

      it 'returns false' do
        expect(subject.perform).to be_falsey
      end

      it 'RegistryConsistencyWorker does not get reenqueued (we will wait until next cronjob)' do
        expect(described_class).not_to receive(:perform_async)

        subject.perform
      end
    end

    context 'when the legacy Upload replicator is disabled' do
      before do
        allow(Geo::UploadReplicator).to receive(:replication_enabled?).and_return(false)
      end

      it 'creates missing registries for partition upload registry classes' do
        user_upload = create(:geo_user_upload)
        group_upload = create(:geo_group_upload)
        project_upload = create(:geo_project_upload)
        abuse_report_upload = create(:geo_abuse_report_upload)
        appearance_upload = create(:geo_appearance_upload)
        dependency_list_export_part_upload = create(:geo_dependency_list_export_part_upload)
        vulnerability_remediation_upload = create(:geo_vulnerability_remediation_upload)
        dependency_list_export_upload = create(:geo_dependency_list_export_upload)
        organization_detail_upload = create(:geo_organization_detail_upload)
        project_topic_upload = create(:geo_project_topic_upload)
        issuable_metric_image_upload = create(:geo_issuable_metric_image_upload)
        vulnerability_export_part_upload = create(:geo_vulnerability_export_part_upload)
        alert_management_metric_image_upload = create(:geo_alert_management_metric_image_upload)
        personal_snippet_upload = create(:geo_personal_snippet_upload)
        vulnerability_archive_export_upload = create(:geo_vulnerability_archive_export_upload)
        project_import_export_relation_export_upload_upload = create(:geo_project_import_export_relation_export_upload_upload)
        vulnerability_export_upload = create(:geo_vulnerability_export_upload)
        user_permission_export_upload_upload = create(:geo_user_permission_export_upload_upload)
        achievement_upload = create(:geo_achievement_upload)
        bulk_import_export_upload_upload = create(:geo_bulk_import_export_upload_upload)
        design_management_action_upload = create(:geo_design_management_action_upload)
        ai_vectorizable_file_upload = create(:geo_ai_vectorizable_file_upload)
        import_export_upload_upload = create(:geo_import_export_upload_upload)

        expect(Geo::AbuseReportUploadRegistry.where(abuse_report_upload_id: abuse_report_upload.id).count).to eq(0)
        expect(Geo::AppearanceUploadRegistry.where(appearance_upload_id: appearance_upload.id).count).to eq(0)
        expect(Geo::DependencyListExportPartUploadRegistry.where(dependency_list_export_part_upload_id: dependency_list_export_part_upload.id).count).to eq(0)
        expect(Geo::VulnerabilityRemediationUploadRegistry.where(vulnerability_remediation_upload_id: vulnerability_remediation_upload.id).count).to eq(0)
        expect(Geo::DependencyListExportUploadRegistry.where(dependency_list_export_upload_id: dependency_list_export_upload.id).count).to eq(0)
        expect(Geo::OrganizationDetailUploadRegistry.where(organization_detail_upload_id: organization_detail_upload.id).count).to eq(0)
        expect(Geo::ProjectTopicUploadRegistry.where(project_topic_upload_id: project_topic_upload.id).count).to eq(0)
        expect(Geo::IssuableMetricImageUploadRegistry.where(issuable_metric_image_upload_id: issuable_metric_image_upload.id).count).to eq(0)
        expect(Geo::VulnerabilityExportPartUploadRegistry.where(vulnerability_export_part_upload_id: vulnerability_export_part_upload.id).count).to eq(0)
        expect(Geo::AlertManagementMetricImageUploadRegistry.where(alert_management_metric_image_upload_id: alert_management_metric_image_upload.id).count).to eq(0)
        expect(Geo::PersonalSnippetUploadRegistry.where(personal_snippet_upload_id: personal_snippet_upload.id).count).to eq(0)
        expect(Geo::VulnerabilityArchiveExportUploadRegistry.where(vulnerability_archive_export_upload_id: vulnerability_archive_export_upload.id).count).to eq(0)
        expect(Geo::ProjectImportExportRelationExportUploadUploadRegistry.where(project_import_export_relation_export_upload_upload_id: project_import_export_relation_export_upload_upload.id).count).to eq(0)
        expect(Geo::VulnerabilityExportUploadRegistry.where(vulnerability_export_upload_id: vulnerability_export_upload.id).count).to eq(0)
        expect(Geo::UserPermissionExportUploadUploadRegistry.where(user_permission_export_upload_upload_id: user_permission_export_upload_upload.id).count).to eq(0)
        expect(Geo::AchievementUploadRegistry.where(achievement_upload_id: achievement_upload.id).count).to eq(0)
        expect(Geo::AiVectorizableFileUploadRegistry.where(ai_vectorizable_file_upload_id: ai_vectorizable_file_upload.id).count).to eq(0)
        expect(Geo::ImportExportUploadUploadRegistry.where(import_export_upload_upload_id: import_export_upload_upload.id).count).to eq(0)
        expect(Geo::BulkImportExportUploadUploadRegistry.where(bulk_import_export_upload_upload_id: bulk_import_export_upload_upload.id).count).to eq(0)
        expect(Geo::DesignManagementActionUploadRegistry.where(design_management_action_upload_id: design_management_action_upload.id).count).to eq(0)
        expect(Geo::GroupUploadRegistry.where(group_upload_id: group_upload.id).count).to eq(0)
        expect(Geo::ProjectUploadRegistry.where(project_upload_id: project_upload.id).count).to eq(0)
        expect(Geo::UserUploadRegistry.where(user_upload_id: user_upload.id).count).to eq(0)

        subject.perform

        expect(Geo::AbuseReportUploadRegistry.where(abuse_report_upload_id: abuse_report_upload.id).count).to eq(1)
        expect(Geo::AppearanceUploadRegistry.where(appearance_upload_id: appearance_upload.id).count).to eq(1)
        expect(Geo::DependencyListExportPartUploadRegistry.where(dependency_list_export_part_upload_id: dependency_list_export_part_upload.id).count).to eq(1)
        expect(Geo::VulnerabilityRemediationUploadRegistry.where(vulnerability_remediation_upload_id: vulnerability_remediation_upload.id).count).to eq(1)
        expect(Geo::DependencyListExportUploadRegistry.where(dependency_list_export_upload_id: dependency_list_export_upload.id).count).to eq(1)
        expect(Geo::OrganizationDetailUploadRegistry.where(organization_detail_upload_id: organization_detail_upload.id).count).to eq(1)
        expect(Geo::ProjectTopicUploadRegistry.where(project_topic_upload_id: project_topic_upload.id).count).to eq(1)
        expect(Geo::IssuableMetricImageUploadRegistry.where(issuable_metric_image_upload_id: issuable_metric_image_upload.id).count).to eq(1)
        expect(Geo::VulnerabilityExportPartUploadRegistry.where(vulnerability_export_part_upload_id: vulnerability_export_part_upload.id).count).to eq(1)
        expect(Geo::AlertManagementMetricImageUploadRegistry.where(alert_management_metric_image_upload_id: alert_management_metric_image_upload.id).count).to eq(1)
        expect(Geo::PersonalSnippetUploadRegistry.where(personal_snippet_upload_id: personal_snippet_upload.id).count).to eq(1)
        expect(Geo::VulnerabilityArchiveExportUploadRegistry.where(vulnerability_archive_export_upload_id: vulnerability_archive_export_upload.id).count).to eq(1)
        expect(Geo::VulnerabilityExportUploadRegistry.where(vulnerability_export_upload_id: vulnerability_export_upload.id).count).to eq(1)
        expect(Geo::UserPermissionExportUploadUploadRegistry.where(user_permission_export_upload_upload_id: user_permission_export_upload_upload.id).count).to eq(1)
        expect(Geo::BulkImportExportUploadUploadRegistry.where(bulk_import_export_upload_upload_id: bulk_import_export_upload_upload.id).count).to eq(1)
        expect(Geo::ProjectImportExportRelationExportUploadUploadRegistry.where(project_import_export_relation_export_upload_upload_id: project_import_export_relation_export_upload_upload.id).count).to eq(1)
        expect(Geo::AchievementUploadRegistry.where(achievement_upload_id: achievement_upload.id).count).to eq(1)
        expect(Geo::AiVectorizableFileUploadRegistry.where(ai_vectorizable_file_upload_id: ai_vectorizable_file_upload.id).count).to eq(1)
        expect(Geo::ImportExportUploadUploadRegistry.where(import_export_upload_upload_id: import_export_upload_upload.id).count).to eq(1)
        expect(Geo::DesignManagementActionUploadRegistry.where(design_management_action_upload_id: design_management_action_upload.id).count).to eq(1)
        expect(Geo::GroupUploadRegistry.where(group_upload_id: group_upload.id).count).to eq(1)
        expect(Geo::ProjectUploadRegistry.where(project_upload_id: project_upload.id).count).to eq(1)
        expect(Geo::UserUploadRegistry.where(user_upload_id: user_upload.id).count).to eq(1)
      end
    end

    context 'when the current Geo node is disabled or primary' do
      before do
        stub_primary_node
      end

      it 'returns false' do
        expect(subject.perform).to be_falsey
      end

      it 'does not execute RegistryConsistencyService' do
        expect(Geo::RegistryConsistencyService).not_to receive(:new)

        subject.perform
      end
    end

    context 'when on an org migration target cell' do
      before do
        stub_org_migration_target_cell
      end

      it 'calls backfill' do
        subject.send(:registry_classes).each do |registry_class|
          service = double
          allow(Geo::RegistryConsistencyService).to receive(:new)
                                                      .with(registry_class, batch_size: anything).and_return(service)
          expect(service).to receive(:execute).and_return(true)
        end

        expect(subject.perform).to be_truthy
      end
    end
  end
end

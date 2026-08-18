# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillAnalyzerProjectStatusesFromProjectSecuritySettings, feature_category: :security_asset_inventories do
  let(:migration_instance) do
    described_class.new(
      start_id: project_security_settings_table.minimum(:project_id),
      end_id: project_security_settings_table.maximum(:project_id),
      batch_table: :project_security_settings,
      batch_column: :project_id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }
  let(:project_security_settings_table) { table(:project_security_settings) }
  let(:analyzer_project_statuses_table) { table(:analyzer_project_statuses, database: :sec) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let(:root_group) do
    namespaces_table.create!(name: 'root-group', path: 'root-group', type: 'Group', organization_id: organization.id)
  end

  let(:group) do
    namespaces_table.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

  let(:project_namespace) do
    namespaces_table.create!(name: 'project-namespace', path: 'project-namespace', type: 'Project',
      organization_id: organization.id)
  end

  let(:project) do
    projects_table.create!(
      id: 1,
      name: 'project',
      path: 'project',
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id
    )
  end

  let(:analyzer_types) do
    {
      container_scanning: 5,
      secret_detection: 6,
      secret_detection_secret_push_protection: 10,
      container_scanning_for_registry: 11,
      secret_detection_pipeline_based: 12,
      container_scanning_pipeline_based: 13
    }
  end

  before do
    root_group.update!(traversal_ids: [root_group.id])
    group.update!(traversal_ids: [root_group.id, group.id])
  end

  subject(:perform_migration) { migration_instance.perform }

  describe '#perform' do
    context 'when both security settings are disabled' do
      let!(:security_setting) do
        create_project_security_setting(project.id,
          secret_push_protection_enabled: false,
          container_scanning_for_registry_enabled: false
        )
      end

      it 'creates no analyzer statuses' do
        expect { perform_migration }.not_to change { analyzer_project_statuses_table.count }
      end
    end

    context 'when only secret_push_protection is enabled' do
      let!(:security_setting) do
        create_project_security_setting(project.id,
          secret_push_protection_enabled: true,
          container_scanning_for_registry_enabled: false
        )
      end

      it 'creates setting-based and aggregated secret detection analyzer statuses' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(0).to(2)

        expect(find_status(project.id, :secret_detection_secret_push_protection)).to be_present
        expect(find_status(project.id, :secret_detection)).to be_present
        expect(find_status(project.id, :container_scanning_for_registry)).to be_nil
        expect(find_status(project.id, :container_scanning)).to be_nil
      end
    end

    context 'when only container_scanning_for_registry is enabled' do
      let!(:security_setting) do
        create_project_security_setting(project.id,
          secret_push_protection_enabled: false,
          container_scanning_for_registry_enabled: true
        )
      end

      it 'creates setting-based and aggregated container scanning analyzer statuses' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(0).to(2)

        expect(find_status(project.id, :container_scanning_for_registry)).to be_present
        expect(find_status(project.id, :container_scanning)).to be_present
        expect(find_status(project.id, :secret_detection_secret_push_protection)).to be_nil
        expect(find_status(project.id, :secret_detection)).to be_nil
      end
    end

    context 'when both security settings are enabled' do
      let!(:security_setting) do
        create_project_security_setting(project.id,
          secret_push_protection_enabled: true,
          container_scanning_for_registry_enabled: true
        )
      end

      it 'creates analyzer project statuses for enabled settings and their aggregated types' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(0).to(4)
      end

      it 'creates both setting-based and aggregated statuses with success status' do
        perform_migration

        statuses = analyzer_project_statuses_table.where(project_id: project.id)
        expect(statuses).to all(have_attributes(status: described_class::STATUS_SUCCESS))
      end

      it 'sets traversal_ids correctly' do
        perform_migration

        statuses = analyzer_project_statuses_table.where(project_id: project.id)
        expect(statuses).to all(have_attributes(traversal_ids: group.traversal_ids))
      end
    end

    context 'with multiple projects' do
      let(:project_2_namespace) do
        namespaces_table.create!(name: 'project_2-namespace', path: 'project_2-namespace', type: 'Project',
          organization_id: organization.id)
      end

      let(:project_2) do
        projects_table.create!(
          id: 2, name: 'project-2', path: 'project-2', namespace_id: group.id,
          project_namespace_id: project_2_namespace.id, organization_id: organization.id
        )
      end

      let!(:security_setting_1) do
        create_project_security_setting(project.id,
          secret_push_protection_enabled: true,
          container_scanning_for_registry_enabled: false
        )
      end

      let!(:security_setting_2) do
        create_project_security_setting(project_2.id,
          secret_push_protection_enabled: false,
          container_scanning_for_registry_enabled: true
        )
      end

      it 'processes all projects in the batch' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(0).to(4)

        # Project 1: secret_push_protection enabled -> setting + aggregated statuses
        expect(find_status(project.id, :secret_detection_secret_push_protection)).to be_present
        expect(find_status(project.id, :secret_detection)).to be_present
        expect(find_status(project.id, :container_scanning_for_registry)).to be_nil
        expect(find_status(project.id, :container_scanning)).to be_nil

        # Project 2: container_scanning enabled -> setting + aggregated statuses
        expect(find_status(project_2.id, :secret_detection_secret_push_protection)).to be_nil
        expect(find_status(project_2.id, :secret_detection)).to be_nil
        expect(find_status(project_2.id, :container_scanning_for_registry)).to be_present
        expect(find_status(project_2.id, :container_scanning)).to be_present
      end
    end

    context 'with existing analyzer statuses' do
      let!(:security_setting) do
        create_project_security_setting(project.id,
          secret_push_protection_enabled: true,
          container_scanning_for_registry_enabled: true
        )
      end

      let!(:existing_secret_detection_status) do
        analyzer_project_statuses_table.create!(
          project_id: project.id,
          traversal_ids: group.traversal_ids,
          analyzer_type: analyzer_types[:secret_detection_secret_push_protection],
          status: described_class::STATUS_FAILED,
          last_call: 1.day.ago
        )
      end

      it 'updates existing records' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(1).to(4)

        expect(existing_secret_detection_status.reload).to have_attributes(status: described_class::STATUS_SUCCESS)

        expect(find_status(project.id, :container_scanning_for_registry)).to be_present
        expect(find_status(project.id, :secret_detection)).to be_present
        expect(find_status(project.id, :container_scanning)).to be_present
      end
    end

    context 'with aggregated type priority calculation' do
      let!(:security_setting) do
        create_project_security_setting(project.id,
          secret_push_protection_enabled: true,
          container_scanning_for_registry_enabled: true
        )
      end

      context 'when existing pipeline-based statuses exist' do
        let!(:existing_secret_detection_pipeline_status) do
          analyzer_project_statuses_table.create!(
            project_id: project.id,
            traversal_ids: group.traversal_ids,
            analyzer_type: analyzer_types[:secret_detection_pipeline_based],
            status: described_class::STATUS_FAILED,
            last_call: 1.day.ago,
            created_at: 1.day.ago,
            updated_at: 1.day.ago
          )
        end

        let!(:existing_container_scanning_pipeline_status) do
          analyzer_project_statuses_table.create!(
            project_id: project.id,
            traversal_ids: group.traversal_ids,
            analyzer_type: analyzer_types[:container_scanning_pipeline_based],
            status: described_class::STATUS_NOT_CONFIGURED,
            last_call: 1.day.ago,
            created_at: 1.day.ago,
            updated_at: 1.day.ago
          )
        end

        it 'creates setting-based statuses and updates existing aggregated statuses' do
          expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(2).to(6)
        end

        it 'calculates aggregated status based on higher priority between setting and existing pipeline statuses' do
          perform_migration

          # Secret detection: setting (success=1) vs existing pipeline (failed=2) -> higher is failed (2)
          secret_detection_aggregated = find_status(project.id, :secret_detection)
          expect(secret_detection_aggregated.status).to eq(described_class::STATUS_FAILED)

          # Container scanning: setting (success=1) vs existing pipeline (not_configured=0) -> higher is success (1)
          container_scanning_aggregated = find_status(project.id, :container_scanning)
          expect(container_scanning_aggregated.status).to eq(described_class::STATUS_SUCCESS)
        end
      end
    end
  end

  def create_project_security_setting(
    project_id, secret_push_protection_enabled: false, container_scanning_for_registry_enabled: false)
    project_security_settings_table.create!(
      project_id: project_id,
      secret_push_protection_enabled: secret_push_protection_enabled,
      container_scanning_for_registry_enabled: container_scanning_for_registry_enabled,
      created_at: Time.current,
      updated_at: Time.current
    )
  end

  def find_status(project_id, analyzer_type)
    analyzer_project_statuses_table.find_by(
      project_id: project_id,
      analyzer_type: analyzer_types[analyzer_type]
    )
  end
end

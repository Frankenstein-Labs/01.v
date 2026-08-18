# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillAnalyzerStatusesInSecurityInventoryFilters,
  feature_category: :security_asset_inventories do
  let(:security_inventory_filters_table) { table(:security_inventory_filters, database: :sec) }
  let(:analyzer_project_statuses_table) { table(:analyzer_project_statuses, database: :sec) }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let(:group) do
    namespaces_table.create!(
      name: 'group', path: 'group', type: 'Group',
      organization_id: organization.id, traversal_ids: []
    ).tap { |g| g.update!(traversal_ids: [g.id]) }
  end

  let(:not_configured) { 0 }
  let(:success) { 1 }
  let(:failed) { 2 }
  let(:stale) { 3 }

  # analyzer_type enum values from Enums::Security.extended_analyzer_types
  let(:sast_type) { 0 }
  let(:dast_type) { 3 }
  let(:secret_detection_type) { 6 }
  let(:spp_type) { 10 }
  let(:container_scanning_for_registry_type) { 11 }

  let(:migration_instance) do
    described_class.new(
      start_id: security_inventory_filters_table.minimum(:id),
      end_id: security_inventory_filters_table.maximum(:id),
      batch_table: :security_inventory_filters,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: SecApplicationRecord.connection
    )
  end

  def create_project(name:)
    project_namespace = namespaces_table.create!(
      name: "#{name}-ns", path: "#{name}-ns", type: 'Project',
      parent_id: group.id, organization_id: organization.id,
      traversal_ids: group.traversal_ids + [0]
    )
    project_namespace.update!(traversal_ids: group.traversal_ids + [project_namespace.id])

    projects_table.create!(
      name: name, path: name, namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id
    )
  end

  def create_inventory_filter(project:, **overrides)
    security_inventory_filters_table.create!(
      project_id: project.id,
      project_name: project.name,
      traversal_ids: [group.id],
      archived: false,
      **overrides
    )
  end

  def create_analyzer_status(project:, analyzer_type:, status:)
    analyzer_project_statuses_table.create!(
      project_id: project.id,
      analyzer_type: analyzer_type,
      status: status,
      last_call: Time.current,
      traversal_ids: [group.id],
      archived: false
    )
  end

  describe '#perform' do
    context 'when inventory filter has stale not_configured but analyzer_project_statuses has success' do
      let!(:project) { create_project(name: 'stale-spp') }
      let!(:sif) do
        create_inventory_filter(
          project: project,
          sast: success,
          secret_detection_secret_push_protection: not_configured
        )
      end

      before do
        create_analyzer_status(project: project, analyzer_type: sast_type, status: success)
        create_analyzer_status(project: project, analyzer_type: spp_type, status: success)
      end

      it 'reconciles the SPP column from analyzer_project_statuses' do
        migration_instance.perform

        sif.reload
        expect(sif).to have_attributes(
          sast: success,
          secret_detection_secret_push_protection: success
        )
      end
    end

    context 'when inventory filter has no matching analyzer_project_statuses rows' do
      let!(:project) { create_project(name: 'no-statuses') }
      let!(:sif) do
        create_inventory_filter(project: project, sast: not_configured)
      end

      it 'leaves the row unchanged' do
        migration_instance.perform

        sif.reload
        expect(sif.sast).to eq(not_configured)
      end
    end

    context 'with multiple projects and mixed statuses' do
      let!(:project1) { create_project(name: 'proj1') }
      let!(:project2) { create_project(name: 'proj2') }
      let!(:project3) { create_project(name: 'proj3') }

      let!(:sif1) do
        create_inventory_filter(
          project: project1,
          secret_detection_secret_push_protection: not_configured,
          dast: failed
        )
      end

      let!(:sif2) do
        create_inventory_filter(
          project: project2,
          container_scanning_for_registry: not_configured,
          sast: success
        )
      end

      let!(:sif3) do
        create_inventory_filter(
          project: project3,
          sast: stale
        )
      end

      before do
        # project1: SPP should become success, dast should become success (overriding failed)
        create_analyzer_status(project: project1, analyzer_type: spp_type, status: success)
        create_analyzer_status(project: project1, analyzer_type: dast_type, status: success)

        # project2: container_scanning_for_registry should become failed
        create_analyzer_status(project: project2, analyzer_type: container_scanning_for_registry_type, status: failed)

        # project3: no analyzer_project_statuses rows, should stay unchanged
      end

      it 'updates each project correctly' do
        migration_instance.perform

        expect(sif1.reload).to have_attributes(
          secret_detection_secret_push_protection: success,
          dast: success
        )

        expect(sif2.reload).to have_attributes(
          container_scanning_for_registry: failed,
          sast: success # unchanged
        )

        expect(sif3.reload).to have_attributes(
          sast: stale # unchanged, no analyzer_project_statuses
        )
      end
    end

    context 'when analyzer_project_statuses has only a subset of analyzer types' do
      let!(:project) { create_project(name: 'partial') }
      let!(:sif) do
        create_inventory_filter(
          project: project,
          sast: failed,
          dast: stale,
          secret_detection_secret_push_protection: not_configured
        )
      end

      before do
        # Only SPP has an analyzer_project_status record
        create_analyzer_status(project: project, analyzer_type: spp_type, status: success)
      end

      it 'updates only columns with matching analyzer_project_statuses, preserves others' do
        migration_instance.perform

        sif.reload
        expect(sif).to have_attributes(
          sast: failed,  # preserved
          dast: stale,   # preserved
          secret_detection_secret_push_protection: success # updated
        )
      end
    end

    context 'when rows already match analyzer_project_statuses' do
      let!(:project) { create_project(name: 'already-correct') }
      let!(:sif) do
        create_inventory_filter(project: project, sast: success, has_scanners: true)
      end

      before do
        create_analyzer_status(project: project, analyzer_type: sast_type, status: success)
      end

      it 'preserves existing correct values' do
        migration_instance.perform

        sif.reload
        expect(sif).to have_attributes(
          sast: success,
          has_scanners: true
        )
      end
    end

    describe 'aggregate booleans recomputation' do
      let!(:project) { create_project(name: 'booleans') }

      context 'when analyzer status changes from not_configured to success' do
        let!(:sif) do
          create_inventory_filter(
            project: project,
            secret_detection_secret_push_protection: not_configured,
            has_scanners: false,
            has_failed_or_warning: false,
            has_stale: false
          )
        end

        before do
          create_analyzer_status(project: project, analyzer_type: spp_type, status: success)
        end

        it 'sets has_scanners to true' do
          migration_instance.perform

          sif.reload
          expect(sif).to have_attributes(
            has_scanners: true,
            has_failed_or_warning: false,
            has_stale: false
          )
        end
      end

      context 'when analyzer status changes to failed' do
        let!(:sif) do
          create_inventory_filter(
            project: project,
            dast: not_configured,
            has_scanners: false,
            has_failed_or_warning: false,
            has_stale: false
          )
        end

        before do
          create_analyzer_status(project: project, analyzer_type: dast_type, status: failed)
        end

        it 'sets has_scanners and has_failed_or_warning to true' do
          migration_instance.perform

          sif.reload
          expect(sif).to have_attributes(
            has_scanners: true,
            has_failed_or_warning: true,
            has_stale: false
          )
        end
      end

      context 'when analyzer status changes to stale' do
        let!(:sif) do
          create_inventory_filter(
            project: project,
            sast: not_configured,
            has_scanners: false,
            has_failed_or_warning: false,
            has_stale: false
          )
        end

        before do
          create_analyzer_status(project: project, analyzer_type: sast_type, status: stale)
        end

        it 'sets has_scanners and has_stale to true' do
          migration_instance.perform

          sif.reload
          expect(sif).to have_attributes(
            has_scanners: true,
            has_failed_or_warning: false,
            has_stale: true
          )
        end
      end

      context 'when no analyzer columns change' do
        let!(:sif) do
          create_inventory_filter(
            project: project,
            sast: success,
            has_scanners: false,
            has_failed_or_warning: false,
            has_stale: false
          )
        end

        before do
          # analyzer_project_statuses matches the inventory filter, so no change
          create_analyzer_status(project: project, analyzer_type: sast_type, status: success)
        end

        it 'skips recomputation leaving stale booleans unchanged' do
          # has_scanners is false even though sast=success. If recompute ran,
          # it would flip has_scanners to true. The fact it stays false proves
          # recomputation was skipped for this unchanged row.
          migration_instance.perform

          sif.reload
          expect(sif).to have_attributes(
            has_scanners: false
          )
        end
      end
    end
  end
end

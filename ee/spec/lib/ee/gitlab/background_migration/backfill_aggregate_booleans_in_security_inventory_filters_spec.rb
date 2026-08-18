# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillAggregateBooleansInSecurityInventoryFilters,
  feature_category: :security_asset_inventories do
  let(:security_inventory_filters_table) { table(:security_inventory_filters, database: :sec) }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let(:group) do
    namespaces_table.create!(name: 'group', path: 'group', type: 'Group', organization_id: organization.id)
  end

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

  let(:not_configured) { 0 }
  let(:success) { 1 }
  let(:failed) { 2 }
  let(:stale) { 3 }

  def create_project(name:)
    project_namespace = namespaces_table.create!(
      name: name, path: name, type: 'Project', organization_id: organization.id
    )

    projects_table.create!(name: name, path: name, namespace_id: group.id,
      project_namespace_id: project_namespace.id, organization_id: organization.id
    )
  end

  def create_inventory_filter(project:, **analyzer_overrides)
    attrs = {
      project_id: project.id,
      project_name: project.name,
      traversal_ids: [group.id],
      archived: false
    }

    security_inventory_filters_table.create!(attrs.merge(analyzer_overrides))
  end

  describe '#perform' do
    let!(:project_all_not_configured) { create_project(name: 'proj-none') }
    let!(:project_with_success) { create_project(name: 'proj-success') }
    let!(:project_with_failed) { create_project(name: 'proj-failed') }
    let!(:project_with_stale) { create_project(name: 'proj-stale') }
    let!(:project_mixed) { create_project(name: 'proj-mixed') }

    let!(:sif_none) { create_inventory_filter(project: project_all_not_configured) }
    let!(:sif_success) { create_inventory_filter(project: project_with_success, sast: success) }
    let!(:sif_failed) { create_inventory_filter(project: project_with_failed, sast: failed) }
    let!(:sif_stale) { create_inventory_filter(project: project_with_stale, sast: stale) }
    let!(:sif_mixed) do
      create_inventory_filter(project: project_mixed, sast: success, dast: failed, secret_detection: stale)
    end

    it 'correctly fills aggregate booleans for all rows' do
      migration_instance.perform

      expect(sif_none.reload).to have_attributes(
        has_scanners: false, has_failed_or_warning: false, has_stale: false
      )

      expect(sif_success.reload).to have_attributes(
        has_scanners: true, has_failed_or_warning: false, has_stale: false
      )

      expect(sif_failed.reload).to have_attributes(
        has_scanners: true, has_failed_or_warning: true, has_stale: false
      )

      expect(sif_stale.reload).to have_attributes(
        has_scanners: true, has_failed_or_warning: false, has_stale: true
      )

      expect(sif_mixed.reload).to have_attributes(
        has_scanners: true, has_failed_or_warning: true, has_stale: true
      )
    end
  end
end

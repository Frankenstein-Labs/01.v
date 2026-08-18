# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillArchivedInSecurityInventoryFilters,
  feature_category: :security_asset_inventories do
  let(:security_inventory_filters_table) { table(:security_inventory_filters, database: :sec) }
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }
  let(:namespace_settings_table) { table(:namespace_settings) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }

  let(:migration_instance) do
    described_class.new(
      start_cursor: [security_inventory_filters_table.minimum(:id)],
      end_cursor: [security_inventory_filters_table.maximum(:id)],
      batch_table: :security_inventory_filters,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: SecApplicationRecord.connection
    )
  end

  subject(:perform_migration) { migration_instance.perform }

  def create_group(name:, parent_id: nil, archived: false)
    group = namespaces_table.create!(
      name: name, path: name, type: 'Group',
      parent_id: parent_id, organization_id: organization.id,
      traversal_ids: []
    )
    traversal_ids = parent_id ? namespaces_table.find(parent_id).traversal_ids + [group.id] : [group.id]
    group.update!(traversal_ids: traversal_ids)
    namespace_settings_table.create!(
      namespace_id: group.id, archived: archived,
      created_at: Time.current, updated_at: Time.current
    )
    group
  end

  def create_project(name:, namespace:, archived: false)
    project_namespace = namespaces_table.create!(
      name: "#{name}-ns", path: "#{name}-ns", type: 'Project',
      parent_id: namespace.id, organization_id: organization.id,
      traversal_ids: namespace.traversal_ids + [0]
    )
    project_namespace.update!(traversal_ids: namespace.traversal_ids + [project_namespace.id])

    projects_table.create!(
      name: name, path: name, namespace_id: namespace.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id, archived: archived
    )
  end

  def create_inventory_filter(project_id:, archived:)
    security_inventory_filters_table.create!(
      project_id: project_id,
      project_name: "project-#{project_id}",
      traversal_ids: [],
      archived: archived
    )
  end

  describe '#perform' do
    let(:group) { create_group(name: 'group') }
    let(:parent_group) { create_group(name: 'parent', archived: true) }
    let(:child_group) { create_group(name: 'child', parent_id: parent_group.id, archived: false) }

    let(:self_archived_project) { create_project(name: 'self-archived', namespace: group, archived: true) }
    let(:ancestor_archived_project) { create_project(name: 'ancestor-archived', namespace: child_group) }
    let(:drifted_project) { create_project(name: 'drifted', namespace: group) }
    let(:correct_project) { create_project(name: 'already-correct', namespace: group) }

    context 'with filters that drifted from the project state' do
      let!(:self_archived_sif) { create_inventory_filter(project_id: self_archived_project.id, archived: false) }
      let!(:ancestor_sif) { create_inventory_filter(project_id: ancestor_archived_project.id, archived: false) }
      let!(:drifted_sif) { create_inventory_filter(project_id: drifted_project.id, archived: true) }
      let!(:correct_sif) { create_inventory_filter(project_id: correct_project.id, archived: false) }
      let!(:orphan_sif) { create_inventory_filter(project_id: non_existing_record_id, archived: true) }

      it 'reconciles every filter with the project archived state', :aggregate_failures do
        perform_migration

        expect(self_archived_sif.reload.archived).to be(true)  # own flag set
        expect(ancestor_sif.reload.archived).to be(true)       # ancestor group archived (traversal EXISTS)
        expect(drifted_sif.reload.archived).to be(false)       # drift corrected
        expect(correct_sif.reload.archived).to be(false)       # already correct
        expect(orphan_sif.reload.archived).to be(true)         # orphan left untouched
      end
    end

    context 'when every filter already matches the project state' do
      let!(:self_archived_sif) { create_inventory_filter(project_id: self_archived_project.id, archived: true) }
      let!(:correct_sif) { create_inventory_filter(project_id: correct_project.id, archived: false) }

      it 'leaves all filters unchanged', :aggregate_failures do
        perform_migration

        expect(self_archived_sif.reload.archived).to be(true)
        expect(correct_sif.reload.archived).to be(false)
      end
    end
  end
end

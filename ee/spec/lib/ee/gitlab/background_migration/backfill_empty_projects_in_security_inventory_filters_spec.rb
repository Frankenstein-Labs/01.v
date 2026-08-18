# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillEmptyProjectsInSecurityInventoryFilters,
  feature_category: :security_asset_inventories do
  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }
  let(:security_inventory_filters_table) { table(:security_inventory_filters, database: :sec) }
  let(:analyzer_namespace_statuses_table) { table(:analyzer_namespace_statuses, database: :sec) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let(:root_group) do
    namespaces_table.create!(
      name: 'root-group',
      path: 'root-group',
      type: 'Group',
      organization_id: organization.id,
      traversal_ids: []
    ).tap { |g| g.update!(traversal_ids: [g.id]) }
  end

  let(:migration_instance) do
    described_class.new(
      start_id: projects_table.minimum(:id),
      end_id: projects_table.maximum(:id),
      batch_table: :projects,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  def create_project(name:, parent_namespace:, archived: false, has_name: true)
    traversal_ids = parent_namespace.traversal_ids + []

    project_namespace = namespaces_table.create!(
      name: "#{name}-namespace",
      path: "#{name}-namespace",
      type: 'Project',
      parent_id: parent_namespace.id,
      organization_id: organization.id,
      traversal_ids: traversal_ids + [0] # placeholder, will update after creation
    )

    project_namespace.update!(traversal_ids: traversal_ids + [project_namespace.id])

    projects_table.create!(
      name: has_name ? name : nil,
      path: name,
      namespace_id: parent_namespace.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id,
      archived: archived
    )
  end

  def create_subgroup(name:, parent:)
    namespaces_table.create!(
      name: name,
      path: name,
      type: 'Group',
      parent_id: parent.id,
      organization_id: organization.id,
      traversal_ids: []
    ).tap { |sg| sg.update!(traversal_ids: parent.traversal_ids + [sg.id]) }
  end

  subject(:perform_migration) { migration_instance.perform }

  describe '#perform' do
    before do
      analyzer_namespace_statuses_table.create!(
        namespace_id: root_group.id,
        traversal_ids: [root_group.id],
        analyzer_type: 0
      )
    end

    context 'with a root group hierarchy' do
      let!(:project_1) { create_project(name: 'project-1', parent_namespace: root_group) }
      let!(:subgroup_1) { create_subgroup(name: 'subgroup-1', parent: root_group) }
      let!(:project_2) { create_project(name: 'project-2', parent_namespace: subgroup_1) }
      let!(:subgroup_2) { create_subgroup(name: 'subgroup-2', parent: subgroup_1) }
      let!(:project_3) { create_project(name: 'project-3', parent_namespace: subgroup_2, archived: true) }

      it 'creates security inventory filters with correct attributes for all projects' do
        perform_migration

        expect(security_inventory_filters_table.count).to eq(3)
        expect(security_inventory_filters_table.all).to contain_exactly(
          have_attributes(
            project_id: project_1.id,
            project_name: project_1.name,
            traversal_ids: [root_group.id],
            archived: false
          ),
          have_attributes(
            project_id: project_2.id,
            project_name: project_2.name,
            traversal_ids: [root_group.id, subgroup_1.id],
            archived: false
          ),
          have_attributes(
            project_id: project_3.id,
            project_name: project_3.name,
            traversal_ids: [root_group.id, subgroup_1.id, subgroup_2.id],
            archived: true
          )
        )
      end
    end

    context 'with existing security inventory filters' do
      let!(:project_1) { create_project(name: 'project-1', parent_namespace: root_group) }
      let!(:subgroup_1) { create_subgroup(name: 'subgroup-1', parent: root_group) }
      let!(:project_2) { create_project(name: 'project-2', parent_namespace: subgroup_1) }

      let!(:existing_filter) do
        security_inventory_filters_table.create!(
          project_id: project_1.id,
          project_name: 'old-name',
          traversal_ids: [999],
          archived: true
        )
      end

      it 'does not create duplicate records' do
        expect { perform_migration }.to change { security_inventory_filters_table.count }.from(1).to(2)
      end

      it 'does not modify existing record' do
        perform_migration
        existing_filter.reload

        expect(existing_filter.project_name).to eq('old-name')
        expect(existing_filter.traversal_ids).to eq([999])
        expect(existing_filter.archived).to be_truthy
      end

      it 'creates records for missing projects only' do
        perform_migration

        new_filter = security_inventory_filters_table.find_by(project_id: project_2.id)
        expect(new_filter).to be_present
        expect(new_filter.project_name).to eq(project_2.name)
      end
    end

    context 'with deeply nested subgroups' do
      let!(:subgroup_1) { create_subgroup(name: 'subgroup-1', parent: root_group) }
      let!(:subgroup_2) { create_subgroup(name: 'subgroup-2', parent: subgroup_1) }
      let!(:subgroup_3) { create_subgroup(name: 'subgroup-3', parent: subgroup_2) }
      let!(:subgroup_4) { create_subgroup(name: 'subgroup-4', parent: subgroup_3) }
      let!(:project_4) { create_project(name: 'project-4', parent_namespace: subgroup_4) }

      it 'finds and processes projects in deeply nested subgroups' do
        expect { perform_migration }.to change { security_inventory_filters_table.count }.from(0).to(1)
      end

      it 'sets correct traversal_ids for deeply nested project' do
        perform_migration

        filter = security_inventory_filters_table.find_by(project_id: project_4.id)
        expect(filter.traversal_ids).to eq([
          root_group.id,
          subgroup_1.id,
          subgroup_2.id,
          subgroup_3.id,
          subgroup_4.id
        ])
      end
    end

    context 'with multiple root groups' do
      let(:root_group_2) do
        namespaces_table.create!(
          name: 'root-group-2',
          path: 'root-group-2',
          type: 'Group',
          organization_id: organization.id,
          traversal_ids: []
        ).tap { |g| g.update!(traversal_ids: [g.id]) }
      end

      let!(:project_1) { create_project(name: 'project-1', parent_namespace: root_group) }
      let!(:project_5) { create_project(name: 'project-5', parent_namespace: root_group_2) }

      before do
        analyzer_namespace_statuses_table.create!(
          namespace_id: root_group_2.id,
          traversal_ids: [root_group_2.id],
          analyzer_type: 0
        )
      end

      it 'processes projects from all root groups' do
        expect { perform_migration }.to change { security_inventory_filters_table.count }.from(0).to(2)
      end

      it 'creates records with correct traversal_ids for each root group' do
        perform_migration

        filter_1 = security_inventory_filters_table.find_by(project_id: project_1.id)
        filter_5 = security_inventory_filters_table.find_by(project_id: project_5.id)

        expect(filter_1.traversal_ids).to eq([root_group.id])
        expect(filter_5.traversal_ids).to eq([root_group_2.id])
      end
    end

    context 'when projects belong to root groups without analyzer_namespace_statuses' do
      let(:root_group_3) do
        namespaces_table.create!(
          name: 'root-group-3',
          path: 'root-group-3',
          type: 'Group',
          organization_id: organization.id,
          traversal_ids: []
        ).tap { |g| g.update!(traversal_ids: [g.id]) }
      end

      let!(:project_1) { create_project(name: 'project-1', parent_namespace: root_group) }
      let!(:project_6) { create_project(name: 'project-6', parent_namespace: root_group_3) }

      it 'only processes projects from root groups with analyzer_namespace_statuses' do
        perform_migration

        expect(security_inventory_filters_table.count).to eq(1)
        expect(security_inventory_filters_table.find_by(project_id: project_6.id)).to be_nil
      end
    end

    context 'with projects that have no name' do
      let!(:project_with_name) { create_project(name: 'project-1', parent_namespace: root_group) }
      let!(:project_no_name) { create_project(name: 'project-no-name', parent_namespace: root_group, has_name: false) }

      it 'skips projects without names' do
        perform_migration

        expect(security_inventory_filters_table.count).to eq(1)
        expect(security_inventory_filters_table.find_by(project_id: project_no_name.id)).to be_nil
      end
    end
  end
end

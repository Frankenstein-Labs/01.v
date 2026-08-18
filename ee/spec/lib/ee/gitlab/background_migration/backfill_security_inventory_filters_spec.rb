# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSecurityInventoryFilters,
  feature_category: :vulnerability_management do
  let(:migration_instance) do
    described_class.new(
      start_id: vulnerability_statistics_table.minimum(:project_id),
      end_id: vulnerability_statistics_table.maximum(:project_id),
      batch_table: :vulnerability_statistics,
      batch_column: :project_id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: SecApplicationRecord.connection
    )
  end

  let(:organizations_table) { table(:organizations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }
  let(:vulnerability_statistics_table) { table(:vulnerability_statistics, database: :sec) }
  let(:analyzer_project_statuses_table) { table(:analyzer_project_statuses, database: :sec) }
  let(:security_inventory_filters_table) { table(:security_inventory_filters, database: :sec) }

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
      name: 'test-project',
      path: 'test-project',
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id
    )
  end

  let(:analyzer_types) { described_class::ANALYZER_TYPES }
  let(:severity_columns) { described_class::SEVERITY_COLUMNS }
  let(:analyzer_statuses) { described_class::STATUS_VALUES }

  before do
    root_group.update!(traversal_ids: [root_group.id])
    group.update!(traversal_ids: [root_group.id, group.id])
  end

  subject(:perform_migration) { migration_instance.perform }

  describe '#perform' do
    context 'with vulnerability statistics' do
      let!(:vulnerability_statistic) do
        vulnerability_statistics_table.create!(
          project_id: project.id,
          traversal_ids: group.traversal_ids,
          archived: false,
          total: 50,
          critical: 5,
          high: 10,
          medium: 15,
          low: 12,
          unknown: 3,
          info: 5,
          letter_grade: 2
        )
      end

      context 'with analyzer project statuses' do
        before do
          analyzer_project_statuses_table.create!(
            project_id: project.id,
            traversal_ids: group.traversal_ids,
            analyzer_type: analyzer_types[:sast],
            status: analyzer_statuses[:success],
            last_call: Time.current,
            archived: false
          )

          analyzer_project_statuses_table.create!(
            project_id: project.id,
            traversal_ids: group.traversal_ids,
            analyzer_type: analyzer_types[:dast],
            status: analyzer_statuses[:failed],
            last_call: Time.current,
            archived: false
          )

          analyzer_project_statuses_table.create!(
            project_id: project.id,
            traversal_ids: group.traversal_ids,
            analyzer_type: analyzer_types[:secret_detection],
            status: analyzer_statuses[:success],
            last_call: Time.current,
            archived: false
          )
        end

        it 'creates security inventory filter record' do
          expect { perform_migration }.to change { security_inventory_filters_table.count }.from(0).to(1)
        end

        it 'populates all fields correctly' do
          perform_migration

          filter = security_inventory_filters_table.first

          expect(filter.project_id).to eq(project.id)
          expect(filter.project_name).to eq('test-project')
          expect(filter.traversal_ids).to eq(group.traversal_ids)
          expect(filter.archived).to be(false)

          expect(filter.total).to eq(50)
          expect(filter.critical).to eq(5)
          expect(filter.high).to eq(10)
          expect(filter.medium).to eq(15)
          expect(filter.low).to eq(12)
          expect(filter.unknown).to eq(3)
          expect(filter.info).to eq(5)

          expect(filter.sast).to eq(analyzer_statuses[:success])
          expect(filter.dast).to eq(analyzer_statuses[:failed])
          expect(filter.secret_detection).to eq(analyzer_statuses[:success])
          expect(filter.dependency_scanning).to eq(analyzer_statuses[:not_configured])
          expect(filter.container_scanning).to eq(analyzer_statuses[:not_configured])
          expect(filter.coverage_fuzzing).to eq(analyzer_statuses[:not_configured])
          expect(filter.api_fuzzing).to eq(analyzer_statuses[:not_configured])
        end
      end

      context 'without analyzer project statuses' do
        it 'creates record with all analyzers set to default status' do
          expect { perform_migration }.to change { security_inventory_filters_table.count }.from(0).to(1)

          filter = security_inventory_filters_table.first

          analyzer_types.each_key do |analyzer|
            expect(filter[analyzer]).to eq(analyzer_statuses[:not_configured])
          end
        end
      end

      context 'with archived project' do
        before do
          vulnerability_statistic.update!(archived: true)
        end

        it 'sets archived flag correctly' do
          perform_migration

          filter = security_inventory_filters_table.first
          expect(filter.archived).to be(true)
        end
      end

      context 'when project does not exist' do
        before do
          project.destroy!
        end

        it 'does not create security inventory filter' do
          expect { perform_migration }.not_to change { security_inventory_filters_table.count }
        end
      end

      context 'with existing security inventory filter' do
        before do
          existing_record = {
            project_id: project.id,
            project_name: 'old-name',
            traversal_ids: [999],
            archived: true,
            critical: 999,
            high: 999,
            medium: 999,
            low: 999,
            info: 999,
            unknown: 999,
            total: 999
          }

          analyzer_types.each_key do |analyzer|
            existing_record[analyzer] = analyzer_statuses[:not_configured]
          end

          security_inventory_filters_table.create!(existing_record)
        end

        it 'updates the existing record' do
          expect { perform_migration }.not_to change { security_inventory_filters_table.count }

          filter = security_inventory_filters_table.first

          expect(filter.project_name).to eq('test-project')
          expect(filter.traversal_ids).to eq(group.traversal_ids)
          expect(filter.archived).to be(false)
          expect(filter.total).to eq(50)
          expect(filter.critical).to eq(5)
          expect(filter.high).to eq(10)
          expect(filter.medium).to eq(15)
          expect(filter.low).to eq(12)
          expect(filter.unknown).to eq(3)
          expect(filter.info).to eq(5)
        end
      end

      context 'with multiple projects' do
        let(:project2_namespace) do
          namespaces_table.create!(name: 'project2-namespace', path: 'project2-namespace', type: 'Project',
            organization_id: organization.id)
        end

        let(:project2) do
          projects_table.create!(
            id: 2,
            name: 'another-project',
            path: 'another-project',
            namespace_id: group.id,
            project_namespace_id: project2_namespace.id,
            organization_id: organization.id
          )
        end

        let!(:vulnerability_statistic2) do
          vulnerability_statistics_table.create!(
            project_id: project2.id,
            traversal_ids: group.traversal_ids,
            archived: false,
            total: 30,
            critical: 2,
            high: 5,
            medium: 10,
            low: 8,
            unknown: 2,
            info: 3,
            letter_grade: 1
          )
        end

        before do
          analyzer_project_statuses_table.create!(
            project_id: project2.id,
            traversal_ids: group.traversal_ids,
            analyzer_type: analyzer_types[:container_scanning],
            status: analyzer_statuses[:success],
            last_call: Time.current,
            archived: false
          )

          analyzer_project_statuses_table.create!(
            project_id: project.id,
            traversal_ids: group.traversal_ids,
            analyzer_type: analyzer_types[:sast],
            status: analyzer_statuses[:failed],
            last_call: Time.current,
            archived: false
          )
        end

        it 'processes all projects in the batch' do
          expect { perform_migration }.to change { security_inventory_filters_table.count }.from(0).to(2)

          filter1 = security_inventory_filters_table.find_by(project_id: project.id)
          filter2 = security_inventory_filters_table.find_by(project_id: project2.id)

          expect(filter1.project_name).to eq('test-project')
          expect(filter1.total).to eq(50)
          expect(filter1.sast).to eq(analyzer_statuses[:failed])

          expect(filter2.project_name).to eq('another-project')
          expect(filter2.total).to eq(30)
          expect(filter2.container_scanning).to eq(analyzer_statuses[:success])
        end
      end
    end

    context 'when vulnerability_statistics table is empty' do
      it 'does not create any records' do
        expect { perform_migration }.not_to change { security_inventory_filters_table.count }
      end
    end
  end
end

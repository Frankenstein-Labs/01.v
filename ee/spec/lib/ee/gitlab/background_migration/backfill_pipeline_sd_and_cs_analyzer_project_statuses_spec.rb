# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillPipelineSdAndCsAnalyzerProjectStatuses, feature_category: :security_asset_inventories do
  let(:migration_instance) do
    described_class.new(
      start_id: analyzer_project_statuses_table.minimum(:id),
      end_id: analyzer_project_statuses_table.maximum(:id),
      batch_table: :analyzer_project_statuses,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: SecApplicationRecord.connection
    )
  end

  let(:analyzer_project_statuses_table) { table(:analyzer_project_statuses, database: :sec) }

  let(:group_id) { 100 }
  let(:project_1_id) { 200 }
  let(:project_2_id) { 201 }

  let(:analyzer_types) do
    {
      sast: 0,
      sast_advanced: 1,
      sast_iac: 2,
      dast: 3,
      dependency_scanning: 4,
      container_scanning: 5,
      secret_detection: 6,
      coverage_fuzzing: 7,
      api_fuzzing: 8,
      cluster_image_scanning: 9,
      secret_detection_secret_push_protection: 10,
      container_scanning_for_registry: 11,
      secret_detection_pipeline_based: 12,
      container_scanning_pipeline_based: 13
    }
  end

  subject(:perform_migration) { migration_instance.perform }

  describe '#perform' do
    context 'when batch contains no matching analyzer types' do
      let!(:sast_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:sast],
          status: 1,
          archived: false,
          last_call: Time.current,
          build_id: 12345
        )
      end

      let!(:dast_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:dast],
          status: 2,
          archived: true,
          last_call: Time.current,
          build_id: 67890
        )
      end

      it 'does not create any new records' do
        expect { perform_migration }.not_to change { analyzer_project_statuses_table.count }
      end
    end

    context 'when batch contains only container_scanning statuses' do
      let!(:container_scanning_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:container_scanning],
          status: 3,
          archived: true,
          last_call: 3.hours.ago,
          build_id: 11111
        )
      end

      it 'creates only container_scanning_pipeline_based record' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(1).to(2)

        pipeline_record = analyzer_project_statuses_table.find_by(
          analyzer_type: analyzer_types[:container_scanning_pipeline_based]
        )

        expect(pipeline_record).to be_present
        expect(pipeline_record.project_id).to eq(project_1_id)
        expect(pipeline_record.status).to eq(3)
        expect(pipeline_record.archived).to be(true)
        expect(pipeline_record.build_id).to eq(11111)
      end
    end

    context 'when batch contains only secret_detection' do
      let!(:secret_detection_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:secret_detection],
          status: 0,
          archived: false,
          last_call: 1.week.ago,
          build_id: 22222
        )
      end

      it 'creates only secret_detection_pipeline_based record' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(1).to(2)

        pipeline_record = analyzer_project_statuses_table.find_by(
          analyzer_type: analyzer_types[:secret_detection_pipeline_based]
        )

        expect(pipeline_record).to be_present
        expect(pipeline_record.project_id).to eq(project_1_id)
        expect(pipeline_record.status).to eq(0)
        expect(pipeline_record.archived).to be(false)
        expect(pipeline_record.build_id).to eq(22222)
      end
    end

    context 'when batch contains both container_scanning and secret_detection' do
      let!(:container_scanning_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:container_scanning],
          status: 2,
          archived: false,
          last_call: 2.days.ago,
          build_id: 33333
        )
      end

      let!(:secret_detection_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:secret_detection],
          status: 1,
          archived: true,
          last_call: 1.day.ago,
          build_id: 44444
        )
      end

      it 'creates pipeline-based records for both types' do
        expect { perform_migration }.to change { analyzer_project_statuses_table.count }.from(2).to(4)
      end

      it 'creates correct pipeline-based analyzer types' do
        perform_migration

        pipeline_based_records = analyzer_project_statuses_table.where(
          analyzer_type: [analyzer_types[:container_scanning_pipeline_based],
            analyzer_types[:secret_detection_pipeline_based]]
        )

        expect(pipeline_based_records.count).to eq(2)
        expect(pipeline_based_records.pluck(:analyzer_type)).to contain_exactly(12, 13)
      end

      it 'preserves all attributes except id, timestamps, and analyzer_type' do
        perform_migration

        cs_pipeline_record = analyzer_project_statuses_table.find_by(
          project_id: project_1_id,
          analyzer_type: analyzer_types[:container_scanning_pipeline_based]
        )

        sd_pipeline_record = analyzer_project_statuses_table.find_by(
          project_id: project_1_id,
          analyzer_type: analyzer_types[:secret_detection_pipeline_based]
        )

        expect(cs_pipeline_record.project_id).to eq(container_scanning_status.project_id)
        expect(cs_pipeline_record.traversal_ids).to eq(container_scanning_status.traversal_ids)
        expect(cs_pipeline_record.status).to eq(2)
        expect(cs_pipeline_record.archived).to be(false)
        expect(cs_pipeline_record.last_call.to_i).to eq(container_scanning_status.last_call.to_i)
        expect(cs_pipeline_record.build_id).to eq(33333)

        expect(sd_pipeline_record.project_id).to eq(secret_detection_status.project_id)
        expect(sd_pipeline_record.traversal_ids).to eq(secret_detection_status.traversal_ids)
        expect(sd_pipeline_record.status).to eq(1)
        expect(sd_pipeline_record.archived).to be(true)
        expect(sd_pipeline_record.last_call.to_i).to eq(secret_detection_status.last_call.to_i)
        expect(sd_pipeline_record.build_id).to eq(44444)
      end

      it 'does not modify original records' do
        expect { perform_migration }
          .to not_change { container_scanning_status.reload }
          .and not_change { secret_detection_status.reload }
      end
    end

    context 'when pipeline-based records already exist' do
      let!(:container_scanning_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:container_scanning],
          status: 1,
          archived: false,
          last_call: Time.current,
          build_id: 55555
        )
      end

      let!(:existing_pipeline_status) do
        analyzer_project_statuses_table.create!(
          project_id: project_1_id,
          traversal_ids: [group_id],
          analyzer_type: analyzer_types[:container_scanning_pipeline_based],
          status: 2,
          archived: true,
          last_call: 1.hour.ago,
          build_id: 66666
        )
      end

      it 'does not modify existing pipeline-based record' do
        expect { perform_migration }
          .to not_change { existing_pipeline_status.reload }
      end
    end

    context 'when batch is empty' do
      it 'does not raise errors and creates no records' do
        expect { perform_migration }.not_to change { analyzer_project_statuses_table.count }
      end
    end
  end
end

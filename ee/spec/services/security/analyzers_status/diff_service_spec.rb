# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::DiffService, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }
  let_it_be(:diff_metadata) do
    {
      namespace_id: group.id,
      traversal_ids: group.traversal_ids
    }
  end

  describe '.calculate_diff' do
    let(:new_analyzer_statuses) { {} }

    subject(:calculate_diff) { described_class.new(project, new_analyzer_statuses).execute }

    context 'when no new analyzer statuses are provided and project has no existing statuses' do
      it 'returns an empty diff' do
        expect(calculate_diff).to eq({})
      end
    end

    context 'when there are no existing statuses' do
      let(:new_analyzer_statuses) do
        {
          sast: { project_id: project.id, analyzer_type: :sast, status: :success },
          dast: { project_id: project.id, analyzer_type: :dast, status: :failed }
        }
      end

      it 'calculates the diff for new statuses' do
        expected_diff = diff_metadata.merge({ diff: {
          sast: { 'success' => 1 },
          dast: { 'failed' => 1 }
        } })

        expect(calculate_diff).to eq(expected_diff)
      end
    end

    context 'when there are existing statuses' do
      let!(:existing_sast_status) do
        create(:analyzer_project_status, project: project, analyzer_type: :sast, status: :success)
      end

      let!(:existing_dast_status) do
        create(:analyzer_project_status, project: project, analyzer_type: :dast, status: :failed)
      end

      let!(:existing_container_scanning_status) do
        create(:analyzer_project_status, project: project, analyzer_type: :container_scanning_pipeline_based,
          status: :stale, consecutive_absence_count: 3)
      end

      context 'when new statuses match existing statuses' do
        let(:new_analyzer_statuses) do
          {
            sast: { project_id: project.id, analyzer_type: :sast, status: :success },
            dast: { project_id: project.id, analyzer_type: :dast, status: :failed },
            container_scanning_pipeline_based: {
              project_id: project.id, analyzer_type: :container_scanning_pipeline_based, status: :stale
            }
          }
        end

        it 'returns an empty diff' do
          expect(calculate_diff).to eq({})
        end
      end

      context 'when new statuses differ from existing statuses' do
        let(:new_analyzer_statuses) do
          {
            sast: { project_id: project.id, analyzer_type: :sast, status: :failed },
            dast: { project_id: project.id, analyzer_type: :dast, status: :not_configured },
            dependency_scanning: { project_id: project.id, analyzer_type: :dependency_scanning, status: :success },
            container_scanning_pipeline_based: {
              project_id: project.id, analyzer_type: :container_scanning_pipeline_based, status: :success
            }
          }
        end

        it 'calculates the correct diff' do
          expected_diff = diff_metadata.merge({ diff: {
            sast: { 'success' => -1, 'failed' => 1 },
            dast: { 'failed' => -1, 'not_configured' => 1 },
            dependency_scanning: { 'success' => 1 },
            container_scanning_pipeline_based: { 'stale' => -1, 'success' => 1 }
          } })

          expect(calculate_diff).to eq(expected_diff)
        end
      end
    end
  end
end

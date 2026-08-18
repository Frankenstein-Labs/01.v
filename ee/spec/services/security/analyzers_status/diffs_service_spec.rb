# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::DiffsService, feature_category: :security_asset_inventories do
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be_with_reload(:project1) { create(:project, namespace: group) }
  let_it_be_with_reload(:project2) { create(:project, namespace: group) }
  let_it_be_with_reload(:project3) { create(:project, namespace: other_group) }

  describe '#execute' do
    let(:projects_analyzer_statuses) { {} }

    subject(:execute_diffs) { described_class.new(projects_analyzer_statuses).execute }

    context 'when projects_analyzer_statuses is nil' do
      let(:projects_analyzer_statuses) { nil }

      it 'returns nil' do
        expect(execute_diffs).to be_nil
      end
    end

    context 'with a single project' do
      context 'when project has no existing statuses' do
        let(:projects_analyzer_statuses) do
          {
            project1 => {
              sast: { project_id: project1.id, analyzer_type: :sast, status: :success },
              dast: { project_id: project1.id, analyzer_type: :dast, status: :failed }
            }
          }
        end

        it 'calculates the diff for new statuses' do
          expected_result = [{
            namespace_id: group.id,
            traversal_ids: group.traversal_ids,
            diff: {
              sast: { 'success' => 1 },
              dast: { 'failed' => 1 }
            }
          }]

          expect(execute_diffs).to eq(expected_result)
        end
      end

      context 'when project has existing statuses' do
        let!(:existing_sast_status) do
          create(:analyzer_project_status, project: project1, analyzer_type: :sast, status: :success)
        end

        context 'when project has empty analyzer statuses' do
          let(:projects_analyzer_statuses) do
            {
              project1 => {}
            }
          end

          it 'returns nil' do
            expect(execute_diffs).to be_nil
          end
        end

        context 'when new statuses match existing statuses' do
          let(:projects_analyzer_statuses) do
            {
              project1 => {
                sast: { project_id: project1.id, analyzer_type: :sast, status: :success }
              }
            }
          end

          it 'returns nil when no changes' do
            expect(execute_diffs).to be_nil
          end
        end

        context 'when new statuses differ from existing statuses' do
          let(:projects_analyzer_statuses) do
            {
              project1 => {
                dependency_scanning: { project_id: project1.id, analyzer_type: :dependency_scanning, status: :failed },
                dependency_scanning_pipeline_based: {
                  project_id: project1.id,
                  analyzer_type: :dependency_scanning_pipeline_based, status: :failed
                }
              }
            }
          end

          it 'calculates the correct diff' do
            expected_result = [{
              namespace_id: group.id,
              traversal_ids: group.traversal_ids,
              diff: {
                dependency_scanning_pipeline_based: { 'failed' => 1 },
                dependency_scanning: { 'failed' => 1 }
              }
            }]

            expect(execute_diffs).to eq(expected_result)
          end
        end
      end
    end

    context 'with multiple projects in same namespace' do
      context 'when both projects have changes' do
        let!(:existing_sast_status_p1) do
          create(:analyzer_project_status, project: project1, analyzer_type: :sast, status: :success)
        end

        let!(:existing_dast_status_p2) do
          create(:analyzer_project_status, project: project2, analyzer_type: :dast, status: :not_configured)
        end

        let(:projects_analyzer_statuses) do
          {
            project1 => {
              sast: { project_id: project1.id, analyzer_type: :sast, status: :failed },
              dast: { project_id: project1.id, analyzer_type: :dast, status: :success }
            },
            project2 => {
              sast: { project_id: project2.id, analyzer_type: :sast, status: :success },
              dast: { project_id: project2.id, analyzer_type: :dast, status: :success }
            }
          }
        end

        it 'aggregates diffs at namespace level' do
          expected_result = [{
            namespace_id: group.id,
            traversal_ids: group.traversal_ids,
            diff: {
              sast: { 'success' => 0, 'failed' => 1 },         # (-1, +1) from p1, (+1, 0) from p2
              dast: { 'success' => 2, 'not_configured' => -1 } # (+1, 0) from p1, (+1, -1) from p2
            }
          }]

          expect(execute_diffs).to eq(expected_result)
        end
      end

      context 'when only one project has changes' do
        let(:projects_analyzer_statuses) do
          {
            project1 => {
              sast: { project_id: project1.id, analyzer_type: :sast, status: :success }
            },
            project2 => {}
          }
        end

        it 'includes only the project with changes' do
          expected_result = [{
            namespace_id: group.id,
            traversal_ids: group.traversal_ids,
            diff: {
              sast: { 'success' => 1 }
            }
          }]

          expect(execute_diffs).to eq(expected_result)
        end
      end

      context 'when projects have offsetting changes' do
        let!(:existing_sast_status_p1) do
          create(:analyzer_project_status, project: project1, analyzer_type: :sast, status: :success)
        end

        let!(:existing_sast_status_p2) do
          create(:analyzer_project_status, project: project2, analyzer_type: :sast, status: :failed)
        end

        let(:projects_analyzer_statuses) do
          {
            project1 => {
              sast: { project_id: project1.id, analyzer_type: :sast, status: :failed }
            },
            project2 => {
              sast: { project_id: project2.id, analyzer_type: :sast, status: :success }
            }
          }
        end

        it 'shows net zero changes' do
          expected_result = [{
            namespace_id: group.id,
            traversal_ids: group.traversal_ids,
            diff: {
              sast: { 'success' => 0, 'failed' => 0 }
            }
          }]

          expect(execute_diffs).to eq(expected_result)
        end
      end
    end

    context 'with multiple projects in different namespaces' do
      let(:projects_analyzer_statuses) do
        {
          project1 => {
            sast: { project_id: project1.id, analyzer_type: :sast, status: :success }
          },
          project3 => {
            dast: { project_id: project3.id, analyzer_type: :dast, status: :failed }
          }
        }
      end

      it 'returns separate namespace diffs' do
        result = execute_diffs

        expect(result).to be_an(Array)
        expect(result.size).to eq(2)

        group_diff = result.find { |r| r[:namespace_id] == group.id }
        other_group_diff = result.find { |r| r[:namespace_id] == other_group.id }

        expect(group_diff).to eq({
          namespace_id: group.id,
          traversal_ids: group.traversal_ids,
          diff: {
            sast: { 'success' => 1 }
          }
        })

        expect(other_group_diff).to eq({
          namespace_id: other_group.id,
          traversal_ids: other_group.traversal_ids,
          diff: {
            dast: { 'failed' => 1 }
          }
        })
      end
    end

    context 'when projects have existing statuses that are not in new_analyzer_statuses' do
      let!(:existing_sast_status_p1) do
        create(:analyzer_project_status, project: project1, analyzer_type: :sast, status: :success)
      end

      let!(:existing_dast_status_p2) do
        create(:analyzer_project_status, project: project2, analyzer_type: :dast, status: :failed)
      end

      let(:projects_analyzer_statuses) do
        {
          project1 => {
            dependency_scanning: { project_id: project1.id, analyzer_type: :dependency_scanning, status: :success }
          },
          project2 => {
            secret_push_protection_pipeline_based: {
              project_id: project2.id, analyzer_type: :secret_push_protection_pipeline_based, status: :success
            }
          }
        }
      end

      it 'adds the new statuses only' do
        expected_result = [{
          namespace_id: group.id,
          traversal_ids: group.traversal_ids,
          diff: {
            dependency_scanning: { 'success' => 1 },                   # from project1
            secret_push_protection_pipeline_based: { 'success' => 1 }  # from project2
          }
        }]

        expect(execute_diffs).to eq(expected_result)
      end
    end
  end
end

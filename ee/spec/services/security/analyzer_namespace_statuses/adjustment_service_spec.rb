# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatuses::AdjustmentService, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be_with_reload(:group_project) { create(:project, namespace: group) }
  let_it_be_with_reload(:sub_group_project) { create(:project, namespace: sub_group) }

  def group_statuses(group)
    statuses = Security::AnalyzerNamespaceStatus
      .where(namespace_id: group.id)
    return unless statuses.exists? && statuses.any?

    statuses.reload.as_json(except: [:id, :created_at, :updated_at])
  end

  def merge_statuses_with_group_info(statuses, group)
    statuses.map do |single_status|
      single_status.merge({
        'namespace_id' => group.id,
        'traversal_ids' => group.traversal_ids
      })
    end
  end

  describe '.execute' do
    let(:namespace_ids) { [1, 2, 3] }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_for_namespace_ids) { described_class.execute(namespace_ids) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object for given namespace ids and calls `execute` on them', :aggregate_failures do
      execute_for_namespace_ids

      expect(described_class).to have_received(:new).with([1, 2, 3])
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:namespace_ids) { [sub_group.id, root_group.id, group.id] }

    subject(:adjust_statuses) { described_class.new(namespace_ids).execute }

    context 'when more than 1000 namespaces ids are provided' do
      let(:namespace_ids) { (1..1001).to_a }

      it 'raises error' do
        expect { adjust_statuses }.to raise_error do |error|
          expect(error.class).to eql(described_class::TooManyNamespacesError)
          expect(error.message).to eql("Cannot adjust analyzer namespace statuses for more than 1000 namespaces")
        end
      end
    end

    context 'with empty namespace_ids array' do
      let(:namespace_ids) { [] }

      it 'does not create new analyzer_namespace_statuses records' do
        expect { adjust_statuses }.not_to change { Security::AnalyzerNamespaceStatus.count }
      end
    end

    context 'when a namespace has no projects' do
      let(:empty_group) { create(:group) }
      let(:namespace_ids) { [empty_group.id] }

      it 'does not create new analyzer_namespace_statuses records' do
        expect { adjust_statuses }.not_to change { Security::AnalyzerNamespaceStatus.count }
      end
    end

    context 'when there are no analyzer_project_status record for the groups projects' do
      it 'does not create a new record in database' do
        expect { adjust_statuses }.not_to change { Security::AnalyzerNamespaceStatus.count }
      end
    end

    context 'when there are analyzer_project_status records for the groups projects' do
      let_it_be_with_reload(:group_project_status) do
        create(:analyzer_project_status, project: group_project, analyzer_type: "sast_iac", status: 1)
      end

      let_it_be_with_reload(:sub_group_project_status_1) do
        create(:analyzer_project_status, project: sub_group_project, analyzer_type: "dast", status: 1)
      end

      let_it_be_with_reload(:sub_group_project_status_2) do
        create(:analyzer_project_status, project: sub_group_project, analyzer_type: "sast_iac", status: 1)
      end

      let(:expected_subgroup_statuses) do
        [
          {
            'analyzer_type' => "sast_iac",
            'success' => 1,
            'failure' => 0,
            'stale' => 0
          },
          {
            'analyzer_type' => "dast",
            'success' => 1,
            'failure' => 0,
            'stale' => 0
          }
        ]
      end

      let(:expected_ancestor_statuses) do
        [
          {
            'analyzer_type' => "sast_iac",
            'success' => 2,
            'failure' => 0,
            'stale' => 0
          },
          {
            'analyzer_type' => "dast",
            'success' => 1,
            'failure' => 0,
            'stale' => 0
          }
        ]
      end

      let(:expected_group_without_subgroup_statuses) do
        [
          {
            'analyzer_type' => "sast_iac",
            'success' => 1,
            'failure' => 0,
            'stale' => 0
          }
        ]
      end

      context 'when there is no analyzer_namespace_status record for a group' do
        it 'creates a new record for each namespace for each analyzer_type' do
          expect { adjust_statuses }.to change { Security::AnalyzerNamespaceStatus.count }.by(6)
        end

        it 'sets the correct values for the parent group' do
          adjust_statuses

          expect(group_statuses(sub_group)).to match_array(
            merge_statuses_with_group_info(expected_subgroup_statuses, sub_group))
        end

        it 'sets the correct values for the ancestor groups' do
          adjust_statuses

          expect(group_statuses(group)).to match_array(
            merge_statuses_with_group_info(expected_ancestor_statuses, group))

          expect(group_statuses(root_group)).to match_array(
            merge_statuses_with_group_info(expected_ancestor_statuses, root_group))
        end
      end

      context 'when there is already a analyzer_namespace_status record for a group' do
        let!(:root_group_statuses) do
          create(:analyzer_namespace_status, namespace: root_group, analyzer_type: "sast_iac", success: 2, failure: 0)

          # This will be updated by the adjustment service to success: 1
          create(:analyzer_namespace_status, namespace: root_group, analyzer_type: "dast", success: 2, failure: 0)
        end

        it 'sets the correct values for the group' do
          adjust_statuses

          expect(group_statuses(root_group)).to match_array(
            merge_statuses_with_group_info(expected_ancestor_statuses, root_group))
        end

        context 'when a group traversal_ids is outdated' do
          before do
            root_group_statuses.update!(traversal_ids: [22, 22, 22])
          end

          it 'sets the correct namespace_ids for the group' do
            adjust_statuses

            expect(group_statuses(root_group)).to match_array(
              merge_statuses_with_group_info(expected_ancestor_statuses, root_group))
          end

          it 'returns correct number of diff rows' do
            expect(adjust_statuses.length).to eq(5)
          end
        end
      end

      context 'when there are stale analyzer_project_status records' do
        let_it_be(:stale_project) { create(:project, namespace: sub_group) }
        let!(:existing_sub_group_status) do
          create(:analyzer_namespace_status, namespace: sub_group,
            analyzer_type: "sast_iac", success: 1, failure: 0, stale: 2)
        end

        let!(:stale_project_status) do
          create(:analyzer_project_status, project: stale_project, analyzer_type: "sast_iac", status: :stale)
        end

        it 'counts stale projects in namespace statistics' do
          adjust_statuses

          expect(group_statuses(sub_group)).to match_array(
            merge_statuses_with_group_info([
              { 'analyzer_type' => "sast_iac", 'success' => 1, 'failure' => 0, 'stale' => 1 },
              { 'analyzer_type' => "dast",     'success' => 1, 'failure' => 0, 'stale' => 0 }
            ], sub_group)
          )
        end

        it 'returns stale change in the diff' do
          diffs = adjust_statuses

          sub_group_diff = diffs.find { |d| d['namespace_id'] == sub_group.id }
          expect(sub_group_diff).to include(
            'analyzer_type' => Security::AnalyzerNamespaceStatus.analyzer_types["sast_iac"],
            'success' => 0,
            'failure' => 0,
            'stale' => -1
          )
        end
      end

      context 'when there are analyzer_project_status for an archived project' do
        before do
          sub_group_project.update!(archived: true)
          sub_group_project_status_1.update!(archived: true)
          sub_group_project_status_2.update!(archived: true)
        end

        it 'excludes the statuses from archived projects' do
          adjust_statuses

          expect(group_statuses(sub_group)).to be_nil

          expect(group_statuses(group)).to match_array(
            merge_statuses_with_group_info(expected_group_without_subgroup_statuses, group))

          expect(group_statuses(root_group)).to match_array(
            merge_statuses_with_group_info(expected_group_without_subgroup_statuses, root_group))
        end
      end

      context 'when all projects in a namespace are archived' do
        before do
          group_project.update!(archived: true)
          sub_group_project.update!(archived: true)
          group_project_status.update!(archived: true)
          sub_group_project_status_1.update!(archived: true)
          sub_group_project_status_2.update!(archived: true)
        end

        context 'and there are existing analyzer_namespace_status records' do
          let!(:existing_group_status) do
            create(:analyzer_namespace_status, namespace: group, analyzer_type: "sast_iac", success: 1, failure: 0)
          end

          let!(:existing_subgroup_status) do
            create(:analyzer_namespace_status, namespace: sub_group, analyzer_type: "sast_iac", success: 1, failure: 0)
          end

          it 'updates existing records to show 0 counts using the UNION clause' do
            expect { adjust_statuses }.not_to change { Security::AnalyzerNamespaceStatus.count }

            # Verify that existing records are updated to 0
            expect(group_statuses(group)).to match_array([
              {
                'analyzer_type' => "sast_iac",
                'success' => 0,
                'failure' => 0,
                'stale' => 0,
                'namespace_id' => group.id,
                'traversal_ids' => group.traversal_ids
              }
            ])

            expect(group_statuses(sub_group)).to match_array([
              {
                'analyzer_type' => "sast_iac",
                'success' => 0,
                'failure' => 0,
                'stale' => 0,
                'namespace_id' => sub_group.id,
                'traversal_ids' => sub_group.traversal_ids
              }
            ])
          end

          it 'returns correct diff values showing the change to 0' do
            diffs = adjust_statuses

            # Should return diffs showing the change from existing values to 0
            group_diff = diffs.find { |d| d['namespace_id'] == group.id }
            subgroup_diff = diffs.find { |d| d['namespace_id'] == sub_group.id }

            expect(group_diff).to include(
              'analyzer_type' => Security::AnalyzerNamespaceStatus.analyzer_types["sast_iac"],
              'success' => -1, # Change from 1 to 0
              'failure' => 0   # No change (was already 0)
            )

            expect(subgroup_diff).to include(
              'analyzer_type' => Security::AnalyzerNamespaceStatus.analyzer_types["sast_iac"],
              'success' => -1, # Change from 1 to 0
              'failure' => 0   # No change (was already 0)
            )
          end
        end
      end
    end
  end
end

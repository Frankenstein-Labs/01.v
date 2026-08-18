# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatuses::FindNamespacesWithAnalyzerStatusesService, feature_category: :security_asset_inventories do
  let_it_be(:user_namespace) { create(:user_namespace) }
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:group_without_analyzer_statuses) { create(:group) }
  let_it_be(:deleted_group) { create(:group, state: :deletion_in_progress) }
  let_it_be(:nested_group) { create(:group, parent: group) }

  let_it_be(:user_project) { create(:project, namespace: user_namespace) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:another_project) { create(:project, group: another_group) }
  let_it_be(:nested_group_project) { create(:project, group: nested_group) }
  let_it_be(:deleted_group_project) { create(:project, group: deleted_group) }

  describe '.execute' do
    let(:namespace_ids) { described_class.execute(namespace_values) }

    context 'when namespace_values is empty' do
      let(:namespace_values) { [] }

      it 'returns an empty array' do
        expect(namespace_ids).to eq([])
      end
    end

    context 'when namespace_values contains namespaces without analyzer statuses' do
      let(:namespace_values) do
        [
          [group_without_analyzer_statuses.id, group_without_analyzer_statuses.traversal_ids]
        ]
      end

      it 'returns an empty array' do
        expect(namespace_ids).to eq([])
      end
    end

    context 'when namespace_values contains namespaces with matching analyzer_project_status record' do
      let_it_be(:analyzer_project_status_1) { create(:analyzer_project_status, project: project) }
      let_it_be(:analyzer_project_status_2) { create(:analyzer_project_status, project: another_project) }

      let(:namespace_values) do
        [
          [group.id, group.traversal_ids],
          [another_group.id, another_group.traversal_ids],
          [group_without_analyzer_statuses.id, group_without_analyzer_statuses.traversal_ids]
        ]
      end

      it 'returns an array with ids of namespaces with analyzer statuses' do
        expect(namespace_ids).to contain_exactly(group.id, another_group.id)
      end
    end

    context 'when namespace_values contains deleted namespaces with matching record' do
      let_it_be(:analyzer_project_status) { create(:analyzer_project_status, project: deleted_group_project) }

      let(:namespace_values) do
        [
          [deleted_group.id, deleted_group.traversal_ids]
        ]
      end

      it 'still returns the deleted namespace id' do
        expect(namespace_ids).to contain_exactly(deleted_group.id)
      end
    end

    context 'when namespace_values contains a nested group with matching analyzer_project_status record' do
      let_it_be(:analyzer_project_status) { create(:analyzer_project_status, project: nested_group_project) }

      let(:namespace_values) do
        [
          [group.id, group.traversal_ids],
          [nested_group.id, nested_group.traversal_ids]
        ]
      end

      it 'returns both the parent and child namespace ids' do
        expect(namespace_ids).to contain_exactly(group.id, nested_group.id)
      end
    end

    context 'when namespace_values contains a user namespace with matching analyzer_project_status record' do
      let_it_be(:analyzer_project_status) { create(:analyzer_project_status, project: user_project) }

      let(:namespace_values) do
        [
          [user_namespace.id, user_namespace.traversal_ids]
        ]
      end

      it 'returns the user namespace id' do
        expect(namespace_ids).to contain_exactly(user_namespace.id)
      end
    end

    context 'when namespace_values contains a namespace with matching archived analyzer_project_status record' do
      before do
        analyzer_project_status_record = create(:analyzer_project_status, project: project)
        analyzer_project_status_record.update!(archived: true)
      end

      let(:namespace_values) do
        [
          [group.id, group.traversal_ids]
        ]
      end

      it 'does not include the namespace in the results' do
        expect(namespace_ids).to be_empty
      end
    end
  end
end

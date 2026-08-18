# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Delete::ProjectWorkItemsService, :elastic_helpers, feature_category: :global_search do
  describe '#index_name' do
    it 'returns the work item index name' do
      service = described_class.new({})

      expect(service.send(:index_name)).to eq(::Search::Elastic::Types::WorkItem.index_name)
    end
  end

  describe 'integration', :elastic_delete_by_query do
    let_it_be(:old_group) { create(:group) }
    let_it_be(:new_group) { create(:group) }
    let_it_be(:project) { create(:project, group: old_group) }
    let_it_be(:work_items) { create_list(:work_item, 3, project: project) }
    let(:work_item_index) { ::Search::Elastic::Types::WorkItem.index_name }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      Elastic::ProcessInitialBookkeepingService.track!(*work_items)
      ensure_elasticsearch_index!
    end

    context 'when project_id is provided' do
      it 'deletes all work items' do
        expect(items_in_index(work_item_index)).to match_array(work_items.map(&:id))

        described_class.execute({
          project_id: project.id
        })

        es_helper.refresh_index(index_name: work_item_index)
        expect(items_in_index(work_item_index)).to be_empty
      end
    end

    context 'when project_id and traversal_id are provided' do
      it 'does not remove work items that match the provided traversal_ids' do
        expect(items_in_index(work_item_index)).to match_array(work_items.map(&:id))

        described_class.execute({
          project_id: project.id,
          traversal_id: project.namespace.elastic_namespace_ancestry
        })

        es_helper.refresh_index(index_name: work_item_index)
        expect(items_in_index(work_item_index)).to match_array(work_items.map(&:id))
      end
    end
  end
end

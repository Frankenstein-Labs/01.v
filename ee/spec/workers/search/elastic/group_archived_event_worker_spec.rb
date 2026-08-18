# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::GroupArchivedEventWorker, feature_category: :global_search do
  let(:event) { ::Namespaces::Groups::GroupArchivedEvent.new(data: data) }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  it_behaves_like 'subscribes to event' do
    let(:data) do
      { group_id: 1, root_namespace_id: 1 }
    end
  end

  it 'has until_executed deduplication strategy and if_deduplicated: :reschedule_once as options' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    expect(described_class.get_deduplication_options).to include({ if_deduplicated: :reschedule_once })
  end

  it_behaves_like 'an idempotent worker' do
    let_it_be(:group) { create(:group, :with_hierarchy) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: group.children[0]) }
    let_it_be(:project3) { create(:project, group: group.children[0].children[1]) }
    let_it_be(:project4) { create(:project, group: group.children[1].children[2]) }
    let(:data) do
      { group_id: group.id, root_namespace_id: group.root_ancestor.id }
    end

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    context 'when group is not found' do
      let(:data) do
        { group_id: non_existing_record_id, root_namespace_id: group.root_ancestor.id }
      end

      it 'does not call by_project_namespace on Project' do
        expect(Project).not_to receive(:by_project_namespace)
        consume_event(subscriber: described_class, event: event)
      end
    end

    it 'does not have N+1 queries' do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        consume_event(subscriber: described_class, event: event)
      end

      create(:project, group: group.children[0].children[3])

      expect { consume_event(subscriber: described_class, event: event) }.not_to exceed_all_query_limit(control)
    end

    it 'calls maintain_elasticsearch_update on each project' do
      expect_next_found_instances_of(Project, 4) do |project|
        expect(project).to receive(:maintain_elasticsearch_update).with(updated_attributes: ['archived'])
      end
      consume_event(subscriber: described_class, event: event)
    end

    context 'when elasticsearch indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does not call by_project_namespace on Project' do
        expect(Project).not_to receive(:by_project_namespace)
        consume_event(subscriber: described_class, event: event)
      end
    end
  end
end

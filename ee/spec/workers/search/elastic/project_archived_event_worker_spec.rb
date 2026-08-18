# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::ProjectArchivedEventWorker, feature_category: :global_search do
  let(:event) { ::Projects::ProjectArchivedEvent.new(data: data) }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  it_behaves_like 'subscribes to event' do
    let(:data) do
      { project_id: 1, namespace_id: 1, root_namespace_id: 1 }
    end
  end

  it 'has until_executed deduplication strategy and if_deduplicated: :reschedule_once as options' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    expect(described_class.get_deduplication_options).to include({ if_deduplicated: :reschedule_once })
  end

  it_behaves_like 'an idempotent worker' do
    let_it_be(:project) { create(:project) }
    let(:data) do
      {
        project_id: project.id,
        namespace_id: project.namespace_id,
        root_namespace_id: project.root_namespace.id
      }
    end

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    context 'when project is not found' do
      let(:data) do
        {
          project_id: non_existing_record_id,
          namespace_id: project.namespace_id,
          root_namespace_id: project.root_namespace.id
        }
      end

      it 'does not call maintain_elasticsearch_update' do
        expect_any_instance_of(Project).not_to receive(:maintain_elasticsearch_update) # rubocop:disable RSpec/AnyInstanceOf -- no instance to stub
        consume_event(subscriber: described_class, event: event)
      end
    end

    it 'calls maintain_elasticsearch_update on the project' do
      expect_next_found_instance_of(Project) do |found_project|
        expect(found_project).to receive(:maintain_elasticsearch_update).with(updated_attributes: ['archived'])
      end

      consume_event(subscriber: described_class, event: event)
    end

    context 'when elasticsearch indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does not call maintain_elasticsearch_update' do
        expect(Project).not_to receive(:find_by_id)
        consume_event(subscriber: described_class, event: event)
      end
    end
  end
end

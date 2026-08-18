# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::DefaultBranchChangedWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace) }
  let_it_be(:project) { create(:project, namespace: zoekt_enabled_namespace.namespace) }
  let_it_be(:index) do
    create(:zoekt_index, :ready, zoekt_enabled_namespace: zoekt_enabled_namespace, node: create(:zoekt_node))
  end

  let(:default_branch_changed_event) { ::Repositories::DefaultBranchChangedEvent.new(data: data) }
  let(:container) { project }
  let(:data) { { container_id: container.id, container_type: container.class.name } }

  before do
    allow(::Search::Zoekt).to receive(:index_async).and_return(true)
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { default_branch_changed_event }
  end

  context 'when project uses zoekt' do
    it 'schedules indexing operation' do
      expect(::Search::Zoekt).to receive(:index_async).with(project.id)
      consume_event(subscriber: described_class, event: default_branch_changed_event)
    end
  end

  context 'when project does not exist' do
    let(:data) { { container_id: non_existing_record_id, container_type: container.class.name } }

    it 'does not schedule indexing and does not raise an exception' do
      expect(::Search::Zoekt).not_to receive(:index_async)

      expect { consume_event(subscriber: described_class, event: default_branch_changed_event) }
        .not_to raise_exception
    end
  end

  context 'when project does not use zoekt' do
    let(:project_double) { instance_double(Project, use_zoekt?: false) }

    before do
      allow(Project).to receive(:find_by_id).and_return(project_double)
    end

    it 'does not schedule indexing' do
      expect(::Search::Zoekt).not_to receive(:index_async)

      consume_event(subscriber: described_class, event: default_branch_changed_event)
    end
  end

  context 'when application_setting zoekt_indexing_enabled is disabled' do
    before do
      stub_ee_application_setting(zoekt_indexing_enabled: false)
    end

    it 'does not schedule indexing' do
      expect(::Search::Zoekt).not_to receive(:index_async)

      consume_event(subscriber: described_class, event: default_branch_changed_event)
    end
  end

  context 'when zoekt_code_search license feature is not available' do
    before do
      stub_licensed_features(zoekt_code_search: false)
    end

    it 'does not schedule indexing' do
      expect(::Search::Zoekt).not_to receive(:index_async)

      consume_event(subscriber: described_class, event: default_branch_changed_event)
    end
  end

  context 'when passed a non-Project class' do
    let(:container) { instance_double(Group, id: 1) }

    it 'does not schedule indexing' do
      expect(::Search::Zoekt).not_to receive(:index_async)

      consume_event(subscriber: described_class, event: default_branch_changed_event)
    end
  end
end

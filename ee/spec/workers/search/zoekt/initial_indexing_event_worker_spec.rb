# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::InitialIndexingEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be(:namespace) { create(:group, :with_hierarchy, children: 1, depth: 3) }
  let(:event) { Search::Zoekt::InitialIndexingEvent.new(data: data) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be_with_reload(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, namespace_id: namespace.id)
  end

  let(:data) do
    { index_id: zoekt_index.id }
  end

  before do
    [namespace, namespace.children.first, namespace.children.first.children.first].each do |n|
      create(:project, namespace: n)
      create(:project_namespace)
    end
  end

  it_behaves_like 'subscribes to event'

  context 'when Zoekt is not licensed or indexing is disabled' do
    before do
      allow(::Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return(false)
    end

    it 'does not creates zoekt_repositories' do
      consume_event(subscriber: described_class, event: event)
      expect(zoekt_repositories_for_index(zoekt_index).count).to eq 0
    end
  end

  it_behaves_like 'an idempotent worker' do
    context 'when metadata does not have project_namespace_id_from and project_namespace_id_to' do
      it 'creates pending zoekt_repositories for each project move the index to initializing' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq namespace.all_project_ids.count
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when metadata has project_namespace_id_from and project_namespace_id_to' do
      let(:pn_id_from) { project_namespace_ids_for_namespace(namespace).first }
      let(:pn_id_to) { project_namespace_ids_for_namespace(namespace).second }
      let(:expected_project_ids) do
        Namespaces::ProjectNamespace.where(id: pn_id_from..pn_id_to).filter_map do |p_ns|
          p_ns.project.id if p_ns.project.root_ancestor == namespace
        end
      end

      before do
        zoekt_index.update!(metadata: { project_namespace_id_from: pn_id_from, project_namespace_id_to: pn_id_to })
      end

      it 'creates pending zoekt_repositories for projects whose project_namespace is in range (pn_id_from..pn_id_to)' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end

      context 'when number of projects is larger than the batch size' do
        let(:first_project_id) { Namespaces::ProjectNamespace.find(pn_id_from).project.id }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)
          stub_const("#{described_class}::INSERT_LIMIT", 1)
        end

        it 'creates one zoekt repository and does not change index state when batch size is 1' do
          expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
          expect { consume_event(subscriber: described_class, event: event) }
            .not_to change { zoekt_index.reload.state }.from('pending')
          expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to contain_exactly(first_project_id)
          expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
        end

        it 're-emits the event when not all repositories are created' do
          # Since we limited BATCH_SIZE and INSERT_LIMIT to 1, and we have more than one project,
          # create_repositories should return false, triggering a reemission
          expect(Gitlab::EventStore).to receive(:publish) do |event|
            expect(event).to be_a(Search::Zoekt::InitialIndexingEvent)
            expect(event.data[:index_id]).to eq(zoekt_index.id)
          end

          consume_event(subscriber: described_class, event: event)
        end

        it 'calls create_repositories with correct parameters and re-emits when false is returned' do
          # We want to verify the actual call to create_repositories without mocking it
          worker = described_class.new
          allow(worker).to receive_messages(find_index: zoekt_index, find_namespace: namespace)

          # Spy on create_repositories to verify parameters
          expect(worker).to receive(:create_repositories)
            .with(namespace: namespace, index: zoekt_index)
            .and_call_original

          # The test environment will use our stubbed constants, returning false
          # from create_repositories, which should trigger reemit_event
          expect(worker).to receive(:reemit_event).with(index_id: zoekt_index.id)

          worker.handle_event(event)
        end
      end
    end

    context 'when metadata has only project_namespace_id_from' do
      let(:pn_id_from) { project_namespace_ids_for_namespace(namespace).first }
      let(:expected_project_ids) do
        Namespaces::ProjectNamespace.where(id: pn_id_from..).filter_map do |p_ns|
          p_ns.project.id if p_ns.project.root_ancestor == namespace
        end
      end

      before do
        zoekt_index.update!(metadata: { project_namespace_id_from: pn_id_from })
      end

      it 'creates pending zoekt_repositories for projects whose project_namespace is in range (pn_id_from..)' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when metadata has only project_namespace_id_to' do
      let(:pn_id_to) { project_namespace_ids_for_namespace(namespace).last }
      let(:expected_project_ids) do
        Namespaces::ProjectNamespace.where(id: ..pn_id_to).filter_map do |p_ns|
          p_ns.project.id if p_ns.project.root_ancestor == namespace
        end
      end

      before do
        zoekt_index.update!(metadata: { project_namespace_id_to: pn_id_to })
      end

      it 'creates pending zoekt_repositories for projects whose project_namespace is in range (..pn_id_to)' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when metadata has project_namespace_id_from explicitly set to nil' do
      let(:pn_id_to) { project_namespace_ids_for_namespace(namespace).last }
      let(:expected_project_ids) do
        Namespaces::ProjectNamespace.where(id: ..pn_id_to).filter_map do |p_ns|
          p_ns.project.id if p_ns.project.root_ancestor == namespace
        end
      end

      before do
        zoekt_index.update!(metadata: { project_namespace_id_from: nil, project_namespace_id_to: pn_id_to })
      end

      it 'creates pending zoekt_repositories for projects whose project_namespace is in range (..pn_id_to)' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when index is not in pending' do
      let(:data) do
        { index_id: zoekt_index.id }
      end

      before do
        zoekt_index.initializing!
      end

      it 'does not creates zoekt_repositories' do
        consume_event(subscriber: described_class, event: event)
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq 0
      end
    end

    context 'when index can not be found' do
      let(:data) do
        { index_id: non_existing_record_id }
      end

      it 'does not creates zoekt_repositories' do
        consume_event(subscriber: described_class, event: event)
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq 0
      end
    end
  end

  describe 'event reemission' do
    context 'when create_repositories returns false' do
      before do
        # Mock create_repositories to return false, simulating not all repos being created
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:create_repositories).and_return(false)
        end
      end

      it 'reemits the event and does not set the index to initializing' do
        expect(Gitlab::EventStore).to receive(:publish) do |event|
          expect(event).to be_a(Search::Zoekt::InitialIndexingEvent)
          expect(event.data[:index_id]).to eq(zoekt_index.id)
        end

        # The index should remain in pending state
        expect { consume_event(subscriber: described_class, event: event) }
          .not_to change { zoekt_index.reload.state }.from('pending')
      end
    end

    context 'with a low INSERT_LIMIT and multiple projects' do
      before do
        # Create more projects than our INSERT_LIMIT to trigger reemission
        5.times { create(:project, namespace: namespace) }
        stub_const("#{described_class}::INSERT_LIMIT", 2)
      end

      it 'creates some repositories and reemits the event' do
        # Expect the event to be published
        expect(Gitlab::EventStore).to receive(:publish) do |event|
          expect(event).to be_a(Search::Zoekt::InitialIndexingEvent)
          expect(event.data[:index_id]).to eq(zoekt_index.id)
        end

        # The index should remain in pending state
        expect { consume_event(subscriber: described_class, event: event) }
          .not_to change { zoekt_index.reload.state }.from('pending')

        # Some repositories should be created - the exact count depends on implementation
        # but they should be created up to the INSERT_LIMIT
        created_repos = zoekt_repositories_for_index(zoekt_index)
        expect(created_repos.count).to be > 0
      end
    end

    it 'reemits the event when create_repositories returns false' do
      worker = described_class.new
      allow(worker).to receive_messages(find_index: zoekt_index, find_namespace: namespace, create_repositories: false)

      expect(worker).to receive(:reemit_event).with(index_id: zoekt_index.id)

      worker.handle_event(event)
    end

    it 'does not reemit the event when create_repositories returns true' do
      worker = described_class.new
      allow(worker).to receive_messages(find_index: zoekt_index, find_namespace: namespace, create_repositories: true)

      expect(worker).not_to receive(:reemit_event)
      expect(zoekt_index).to receive(:initializing!)

      worker.handle_event(event)
    end

    it 'publishes the initial indexing event with the same index_id' do
      worker = described_class.new

      expect(Gitlab::EventStore).to receive(:publish) do |published_event|
        expect(published_event).to be_a(Search::Zoekt::InitialIndexingEvent)
        expect(published_event.data[:index_id]).to eq(zoekt_index.id)
      end

      worker.send(:reemit_event, index_id: zoekt_index.id)
    end
  end

  def zoekt_repositories_for_index(index)
    Search::Zoekt::Repository.where(zoekt_index_id: index.id)
  end

  def project_namespace_ids_for_namespace(namespace)
    Namespaces::ProjectNamespace.select { |pn| pn.root_ancestor == namespace }.map(&:id).sort
  end
end

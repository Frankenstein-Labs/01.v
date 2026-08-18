# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Weights::UpdateRolledUpWeightsEventHandler, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:parent_work_item) { create(:work_item, :issue, project: project) }
  let_it_be(:child_work_item) { create(:work_item, :task, project: project, weight: 5) }
  let_it_be(:parent_link) { create(:parent_link, work_item: child_work_item, work_item_parent: parent_work_item) }

  subject(:handler) { described_class.new }

  describe '.can_handle?' do
    context 'with update events' do
      context 'when weight widget is updated' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemUpdatedEvent,
            data: { updated_widgets: ['weight_widget'] }
          )
        end

        it 'returns true' do
          expect(described_class.can_handle?(event)).to be true
        end
      end

      context 'when hierarchy widget is updated' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemUpdatedEvent,
            data: { updated_widgets: ['hierarchy_widget'] }
          )
        end

        it 'returns true' do
          expect(described_class.can_handle?(event)).to be true
        end
      end

      context 'when weight attribute is updated' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemUpdatedEvent,
            data: { updated_attributes: ['weight'] }
          )
        end

        it 'returns true' do
          expect(described_class.can_handle?(event)).to be true
        end
      end

      context 'when state_id attribute is updated' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemUpdatedEvent,
            data: { updated_attributes: ['state_id'] }
          )
        end

        it 'returns true' do
          expect(described_class.can_handle?(event)).to be true
        end
      end

      context 'when irrelevant attributes are updated' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemUpdatedEvent,
            data: { updated_attributes: %w[title description] }
          )
        end

        it 'returns false' do
          expect(described_class.can_handle?(event)).to be false
        end
      end

      context 'when no relevant data is present' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemUpdatedEvent,
            data: {}
          )
        end

        it 'returns false' do
          expect(described_class.can_handle?(event)).to be false
        end
      end
    end

    context 'with non-update events' do
      context 'when work item has weight' do
        let(:weighted_work_item) { create(:work_item, :task, project: project, weight: 5) }
        let(:event) do
          instance_double(
            WorkItems::WorkItemCreatedEvent,
            data: { id: weighted_work_item.id }
          )
        end

        it 'returns true' do
          expect(described_class.can_handle?(event)).to be true
        end
      end

      context 'when work item has no weight' do
        let(:unweighted_work_item) { create(:work_item, :task, project: project, weight: nil) }
        let(:event) do
          instance_double(
            WorkItems::WorkItemCreatedEvent,
            data: { id: unweighted_work_item.id }
          )
        end

        it 'returns false' do
          expect(described_class.can_handle?(event)).to be false
        end
      end

      context 'when work item does not exist' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemCreatedEvent,
            data: { id: 999999 }
          )
        end

        it 'returns false' do
          expect(described_class.can_handle?(event)).to be false
        end
      end

      context 'when work item id is missing' do
        let(:event) do
          instance_double(
            WorkItems::WorkItemCreatedEvent,
            data: {}
          )
        end

        it 'returns false' do
          expect(described_class.can_handle?(event)).to be false
        end
      end
    end
  end

  describe '#handle_event' do
    before do
      allow(WorkItems::Weights::UpdateWeightsWorker).to receive(:perform_async)
    end

    context 'when handling WorkItemUpdatedEvent' do
      let(:event_data) do
        {
          id: child_work_item.id,
          namespace_id: project.namespace.id
        }
      end

      let(:event) { WorkItems::WorkItemUpdatedEvent.new(data: event_data) }

      it 'calls UpdateWeightsWorker with correct work item ids' do
        handler.handle_event(event)

        expect(WorkItems::Weights::UpdateWeightsWorker).to have_received(:perform_async).with([
          child_work_item.id
        ])
      end

      context 'when previous_work_item_parent_id is present' do
        let(:previous_parent) { create(:work_item, :issue, project: project) }
        let(:event_data) do
          {
            id: child_work_item.id,
            namespace_id: project.namespace.id,
            previous_work_item_parent_id: previous_parent.id
          }
        end

        it 'includes previous parent in work item ids' do
          handler.handle_event(event)

          expect(WorkItems::Weights::UpdateWeightsWorker).to have_received(:perform_async).with([
            child_work_item.id,
            previous_parent.id
          ])
        end
      end
    end

    context 'when handling WorkItemClosedEvent' do
      let(:event_data) do
        {
          id: child_work_item.id,
          namespace_id: project.namespace.id
        }
      end

      let(:event) { WorkItems::WorkItemClosedEvent.new(data: event_data) }

      it 'calls UpdateWeightsWorker with work item id' do
        handler.handle_event(event)

        expect(WorkItems::Weights::UpdateWeightsWorker).to have_received(:perform_async).with([
          child_work_item.id
        ])
      end
    end

    context 'when handling WorkItemReopenedEvent' do
      let(:event_data) do
        {
          id: child_work_item.id,
          namespace_id: project.namespace.id
        }
      end

      let(:event) { WorkItems::WorkItemReopenedEvent.new(data: event_data) }

      it 'calls UpdateWeightsWorker with work item id' do
        handler.handle_event(event)

        expect(WorkItems::Weights::UpdateWeightsWorker).to have_received(:perform_async).with([
          child_work_item.id
        ])
      end
    end

    context 'when handling WorkItemCreatedEvent' do
      let(:event_data) do
        {
          id: child_work_item.id,
          namespace_id: project.namespace.id
        }
      end

      let(:event) { WorkItems::WorkItemCreatedEvent.new(data: event_data) }

      it 'calls UpdateWeightsWorker with work item id' do
        handler.handle_event(event)

        expect(WorkItems::Weights::UpdateWeightsWorker).to have_received(:perform_async).with([
          child_work_item.id
        ])
      end
    end

    context 'when handling WorkItemDeletedEvent' do
      let(:event_data) do
        {
          id: child_work_item.id,
          namespace_id: project.namespace.id,
          previous_work_item_parent_id: parent_work_item.id
        }
      end

      let(:event) { WorkItems::WorkItemDeletedEvent.new(data: event_data) }

      it 'calls UpdateWeightsWorker with parent work item id' do
        handler.handle_event(event)

        expect(WorkItems::Weights::UpdateWeightsWorker).to have_received(:perform_async).with([
          child_work_item.id,
          parent_work_item.id
        ])
      end
    end
  end

  describe 'integration with real events' do
    it 'is subscribed to the correct events' do
      event_store = Gitlab::EventStore.instance

      expect(event_store.subscriptions[WorkItems::WorkItemCreatedEvent]).to include(
        have_attributes(worker: described_class)
      )

      expect(event_store.subscriptions[WorkItems::WorkItemDeletedEvent]).to include(
        have_attributes(worker: described_class)
      )

      expect(event_store.subscriptions[WorkItems::WorkItemClosedEvent]).to include(
        have_attributes(worker: described_class)
      )

      expect(event_store.subscriptions[WorkItems::WorkItemReopenedEvent]).to include(
        have_attributes(worker: described_class)
      )
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:event) do
      WorkItems::WorkItemClosedEvent.new(data: {
        id: child_work_item.id,
        namespace_id: project.namespace.id
      })
    end
  end
end

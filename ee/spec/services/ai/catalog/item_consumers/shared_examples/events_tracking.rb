# frozen_string_literal: true

RSpec.shared_examples_for 'ItemConsumers::EventsTracking' do
  let(:event_name) { 'create_ai_catalog_item_consumer' }
  let(:project) { build(:project) }
  let(:group) { build(:group) }
  let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, project:, group:) }

  let(:builder_properties) do
    {
      item_type: 'custom_agent',
      custom_item_id: item_consumer.item.id
    }
  end

  before do
    allow(Ai::Catalog::Tracking::EventPropertiesBuilder).to receive(:new)
      .with(item: item_consumer.item, version: item_consumer.pinned_version)
      .and_return(instance_double(Ai::Catalog::Tracking::EventPropertiesBuilder, to_h: builder_properties))
  end

  context 'when no flow_trigger is provided' do
    it 'tracks an event without a triggers property' do
      expect(subject).to receive(:track_internal_event).with(
        event_name,
        user: subject.send(:current_user),
        project: project,
        namespace: group,
        additional_properties: builder_properties.merge(
          label: item_consumer.enabled.to_s,
          property: item_consumer.locked.to_s
        )
      )

      subject.track_item_consumer_event(item_consumer, event_name, nil)
    end
  end

  context 'when a flow_trigger with event_types is provided' do
    let(:event_type_ids) { [Ai::FlowTrigger::EVENT_TYPES[:mention], Ai::FlowTrigger::EVENT_TYPES[:merge_request]] }
    let(:flow_trigger) { instance_double(Ai::FlowTrigger, event_types: event_type_ids) }

    it 'tracks an event with a triggers property containing joined event type names' do
      expected_triggers = 'mention,merge_request'

      expect(subject).to receive(:track_internal_event).with(
        event_name,
        user: subject.send(:current_user),
        project: project,
        namespace: group,
        additional_properties: builder_properties.merge(
          label: item_consumer.enabled.to_s,
          property: item_consumer.locked.to_s,
          triggers: expected_triggers
        )
      )

      subject.track_item_consumer_event(item_consumer, event_name, flow_trigger)
    end
  end
end

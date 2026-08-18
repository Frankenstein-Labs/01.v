# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiUsageEventsRegistryDsl, feature_category: :value_stream_management do
  subject(:registry_module) do
    Class.new.tap do |module_class|
      module_class.extend(Gitlab::Tracking::AiUsageEventsRegistryDsl)
    end
  end

  context 'without events registered' do
    it 'returns empty events hash' do
      expect(registry_module.registered_events).to eq({})
    end

    it 'returns empty transformations array' do
      expect(registry_module.registered_transformations(:some_event)).to eq([])
    end

    it 'returns empty features array' do
      expect(registry_module.registered_features).to eq([])
    end
  end

  context 'with events registered' do
    it 'fails when event does not have internal events definition' do
      expect do
        registry_module.register_feature(:test_feature) do
          events(unknown_event: 1)
        end
      end.to raise_error("Event `unknown_event` is not defined in InternalEvents")
    end

    it 'fails when events are registered outside of a feature context' do
      expect do
        registry_module.events(ungrouped_event: 5)
      end.to raise_error("Cannot register events outside of a feature context. Use register_feature method.")
    end

    it 'fails when feature is registered inside of another feature' do
      expect do
        registry_module.register_feature(:outer) do
          register_feature(:inner)
        end
      end.to raise_error("Nested features are not supported. Use register_feature method on top level.")
    end

    context 'with InternalEvents definition in place' do
      before do
        allow(Gitlab::Tracking::EventDefinition).to receive(:internal_event_exists?)
                                                      .and_return(true)

        registry_module.register_feature(:test_feature) do
          events(simple_event: 1, multi_event: 2) do |context|
            context
          end

          events(no_block_event: 3)

          deprecated_events(old_event: 4)

          transformation(:multi_event) do
            { a: 'b' }
          end
        end
      end

      describe '.events' do
        it 'fails when same event ID already exists' do
          expect do
            registry_module.register_feature(:another_feature) do
              events(same_id_event: 1)
            end
          end.to raise_error("Event with id `1` was already registered")
        end

        it 'fails when same event name already exists' do
          expect do
            registry_module.register_feature(:another_feature) do
              events(simple_event: 123)
            end
          end.to raise_error("Event with name `simple_event` was already registered")
        end
      end

      describe '.registered_events' do
        it 'returns hash with registered event names and ids' do
          expect(registry_module.registered_events).to eq({
            'simple_event' => 1,
            'multi_event' => 2,
            'no_block_event' => 3,
            'old_event' => 4
          })
        end

        it 'filters by specific feature if passed' do
          expect(registry_module.registered_events(:non_existing_feature)).to eq({})
          expect(registry_module.registered_events(:test_feature)).to eq({
            'simple_event' => 1,
            'multi_event' => 2,
            'no_block_event' => 3,
            'old_event' => 4
          })
        end
      end

      describe '.registered_transformations' do
        it 'returns all registered transformation blocks for given event' do
          expect(registry_module.registered_transformations(:no_block_event).size).to eq(0)
          expect(registry_module.registered_transformations(:simple_event).size).to eq(1)
          expect(registry_module.registered_transformations(:multi_event).size).to eq(2)
        end
      end

      describe '.deprecated_event?' do
        it 'returns true for events declared as deprecated' do
          expect(registry_module.deprecated_event?(:simple_event)).to be_falsey
          expect(registry_module.deprecated_event?(:multi_event)).to be_falsey
          expect(registry_module.deprecated_event?(:no_block_event)).to be_falsey
          expect(registry_module.deprecated_event?(:old_event)).to be_truthy
        end
      end

      describe '.registered_features' do
        it 'returns list of all registered feature names' do
          expect(registry_module.registered_features).to contain_exactly(:test_feature)
        end

        it 'returns empty array when no features are registered' do
          new_registry = Class.new.tap do |module_class|
            module_class.extend(Gitlab::Tracking::AiUsageEventsRegistryDsl)
          end

          expect(new_registry.registered_features).to eq([])
        end
      end
    end
  end
end

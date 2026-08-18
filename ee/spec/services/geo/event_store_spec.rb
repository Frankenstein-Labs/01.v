# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::EventStore, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:secondary_node) { create(:geo_node) }

  let(:project_stub) { instance_double(Project) }

  let(:test_event_store_class) do
    Class.new(described_class) do
      self.event_type = :cache_invalidation_event

      def build_event
        Geo::CacheInvalidationEvent.new(key: 'test-key')
      end
    end
  end

  subject(:event_store) { test_event_store_class.new(project_stub) }

  describe '.event_type' do
    it 'can be set on subclasses' do
      expect(test_event_store_class.event_type).to eq(:cache_invalidation_event)
    end
  end

  describe '.can_create_event?' do
    context 'when on a secondary node' do
      before do
        stub_secondary_node
      end

      it 'returns false' do
        expect(test_event_store_class.can_create_event?).to be false
      end
    end

    context 'when on a primary node' do
      before do
        stub_primary_node
      end

      it 'returns true when secondary nodes exist' do
        expect(test_event_store_class.can_create_event?).to be true
      end

      it 'returns false when no secondary nodes exist' do
        allow(Gitlab::Geo).to receive(:secondary_nodes).and_return([])

        expect(test_event_store_class.can_create_event?).to be false
      end
    end
  end

  describe '#create!' do
    context 'when on a secondary node' do
      before do
        stub_secondary_node
      end

      it 'does not create an event' do
        expect { event_store.create! }.not_to change { Geo::CacheInvalidationEvent.count }
      end
    end

    context 'when on a primary node' do
      before do
        stub_primary_node
      end

      it 'creates an event when secondary nodes exist' do
        expect { event_store.create! }.to change { Geo::CacheInvalidationEvent.count }.by(1)
      end

      it 'creates a Geo::EventLog entry' do
        expect { event_store.create! }.to change { Geo::EventLog.count }.by(1)
      end

      it 'does not create an event when no secondary nodes exist' do
        allow(Gitlab::Geo).to receive(:secondary_nodes).and_return([])

        expect { event_store.create! }.not_to change { Geo::CacheInvalidationEvent.count }
      end

      context 'when event validation fails' do
        let(:invalid_event_store_class) do
          Class.new(described_class) do
            self.event_type = :cache_invalidation_event

            def build_event
              Geo::CacheInvalidationEvent.new(key: nil)
            end
          end
        end

        subject(:invalid_event_store) { invalid_event_store_class.new(project_stub) }

        it 'logs an error' do
          expect(Gitlab::Geo::Logger).to receive(:error).with(
            hash_including(
              message: 'Cache invalidation event could not be created',
              error: a_string_matching(/Key can't be blank/)
            )
          )

          invalid_event_store.create!
        end

        it 'does not raise an exception' do
          expect { invalid_event_store.create! }.not_to raise_error
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::ConnectionCleanupWorker, feature_category: :global_search do
  let(:worker) { described_class.new }
  let(:executor) { instance_double(::ActiveContext::Databases::Elasticsearch::Executor, drop_collection: nil) }
  let(:adapter) do
    adapter = ::ActiveContext::Databases::Elasticsearch::Adapter.new({}, options: { 'url' => 'http://localhost:9200' })
    allow(adapter).to receive(:executor).and_return(executor)
    adapter
  end

  before do
    allow(::ActiveContext::Adapter).to receive(:for_connection).and_return(adapter)
    allow(::ActiveContext).to receive(:adapter).and_return(adapter)
  end

  describe '#perform' do
    context 'when connection does not exist' do
      it 'returns early without error' do
        expect { worker.perform(999) }.not_to raise_error
      end
    end

    context 'when connection is active' do
      let!(:connection) { create(:ai_active_context_connection) }

      it 'returns early without destroying the connection' do
        expect { worker.perform(connection.id) }.not_to change { Ai::ActiveContext::Connection.count }
        expect(connection.reload).to be_active
      end

      it 'does not drop collections' do
        worker.perform(connection.id)

        expect(executor).not_to have_received(:drop_collection)
      end
    end

    context 'when connection is inactive' do
      let_it_be(:connection) { create(:ai_active_context_connection, :inactive) }
      let_it_be(:collection1) { create(:ai_active_context_collection, connection: connection, name: '1') }
      let_it_be(:collection2) { create(:ai_active_context_collection, connection: connection, name: '2') }

      it 'drops all collections' do
        worker.perform(connection.id)

        expect(executor).to have_received(:drop_collection).with(collection1.name_without_prefix)
        expect(executor).to have_received(:drop_collection).with(collection2.name_without_prefix)
      end

      it 'destroys the connection' do
        expect { worker.perform(connection.id) }.to change { Ai::ActiveContext::Connection.count }.by(-1)
      end

      context 'when adapter is not available' do
        before do
          allow(::ActiveContext::Adapter).to receive(:for_connection).with(connection).and_return(nil)
        end

        it 'still destroys the connection' do
          expect { worker.perform(connection.id) }.to change { Ai::ActiveContext::Connection.count }.by(-1)
        end

        it 'does not attempt to drop collections' do
          worker.perform(connection.id)
          expect(executor).not_to have_received(:drop_collection)
        end
      end

      context 'when connection has no collections' do
        let!(:connection_no_collections) { create(:ai_active_context_connection, :inactive) }

        before do
          allow(::ActiveContext::Adapter).to receive(:for_connection)
            .with(connection_no_collections).and_return(adapter)
        end

        it 'destroys the connection' do
          expect { worker.perform(connection_no_collections.id) }
            .to change { Ai::ActiveContext::Connection.count }.by(-1)
        end
      end

      context 'when dropping a collection fails' do
        before do
          allow(executor).to receive(:drop_collection).and_raise(StandardError, 'Connection failed')
        end

        it 'raises the error' do
          expect { worker.perform(connection.id) }
            .to raise_error(StandardError, 'Connection failed')
        end

        it 'does not destroy the connection' do
          expect { worker.perform(connection.id) }.to raise_error(StandardError)
          expect(Ai::ActiveContext::Connection.find_by_id(connection.id)).to be_present
        end
      end
    end
  end
end

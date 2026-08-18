# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Ai::ActiveContext partition integration', :active_context_integration, feature_category: :global_search do
  context 'with Elasticsearch', :elasticsearch_adapter do
    let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }

    describe '#add_field' do
      it 'adds a new field for type keyword and does not raise error if it already exists' do
        expect(schema).not_to include('some_keyword')

        ActiveContext.adapter.executor.add_field(:code) { |c| c.keyword :some_keyword }

        expect(schema).to include('some_keyword' => { 'type' => 'keyword' })

        expect { ActiveContext.adapter.executor.add_field(:code) { |c| c.keyword :some_keyword } }.not_to raise_error
      end

      it 'adds a new field for type vector' do
        expect(schema).not_to include('custom_embedding')

        ActiveContext.adapter.executor.add_field(:code) { |c| c.vector :custom_embedding, dimensions: 768 }

        expect(schema['custom_embedding']).to include(
          'type' => 'dense_vector',
          'dims' => 768,
          'index' => true,
          'similarity' => 'cosine'
        )
      end
    end
  end

  context 'with OpenSearch', :opensearch_adapter do
    let_it_be(:connection) { create(:ai_active_context_connection, :opensearch) }

    describe '#add_field' do
      it 'adds a new field for type keyword and does not raise error if it already exists' do
        expect(schema).not_to include('some_keyword')

        ActiveContext.adapter.executor.add_field(:code) { |c| c.keyword :some_keyword }

        expect(schema).to include('some_keyword' => { 'type' => 'keyword' })

        expect { ActiveContext.adapter.executor.add_field(:code) { |c| c.keyword :some_keyword } }.not_to raise_error
      end

      it 'adds a new field for type vector' do
        expect(schema).not_to include('custom_embedding')

        ActiveContext.adapter.executor.add_field(:code) { |c| c.vector :custom_embedding, dimensions: 768 }

        expect(schema['custom_embedding']).to include(
          'type' => 'knn_vector',
          'dimension' => 768,
          'method' => {
            'name' => 'hnsw',
            'engine' => 'lucene',
            'space_type' => 'cosinesimil',
            'parameters' => {
              'ef_construction' => 100,
              'm' => 16
            }
          }
        )
      end
    end
  end

  context 'with postgres', :postgres_adapter do
    let!(:connection) { create(:ai_active_context_connection, :postgresql, :inactive) }

    describe '#add_field' do
      it 'adds a new field for type keyword and does not raise error if it already exists' do
        expect(schema).not_to include('some_keyword')

        ActiveContext.adapter.executor.add_field(:code) { |c| c.keyword :some_keyword }

        expect(schema).to include('some_keyword' => 'text')

        expect { ActiveContext.adapter.executor.add_field(:code) { |c| c.keyword :some_keyword } }.not_to raise_error
      end

      it 'adds a new field for type vector' do
        expect(schema).not_to include('custom_embedding')

        ActiveContext.adapter.executor.add_field(:code) { |c| c.vector :custom_embedding, dimensions: 768 }

        expect(schema).to include('custom_embedding' => 'USER-DEFINED')
      end
    end
  end
end

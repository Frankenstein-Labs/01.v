# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Collection, :aggregate_failures, feature_category: :global_search do
  subject(:collection) { create(:ai_active_context_collection) }

  it { is_expected.to be_valid }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:connection_id) }

  it { is_expected.to validate_presence_of(:number_of_partitions) }
  it { is_expected.to validate_numericality_of(:number_of_partitions).is_greater_than_or_equal_to(1).only_integer }

  it { is_expected.to validate_presence_of(:connection_id) }

  it { is_expected.to belong_to(:connection).class_name('Ai::ActiveContext::Connection') }

  describe 'metadata' do
    it 'is valid when empty' do
      collection.metadata = {}
      expect(collection).to be_valid
    end

    it 'is valid with include_ref_fields as true' do
      collection.metadata = { include_ref_fields: true }
      expect(collection).to be_valid
    end

    it 'is invalid when include_ref_fields is null' do
      collection.metadata = { include_ref_fields: nil }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is valid with collection_class as a string' do
      collection.metadata = { collection_class: 'A string' }
      expect(collection).to be_valid
    end

    describe 'embedding model properties' do
      where(:embedding_model) do
        [:current_indexing_embedding_model, :next_indexing_embedding_model, :search_embedding_model]
      end

      with_them do
        it 'is valid with string model_ref and field' do
          collection.metadata = { embedding_model => { model_ref: 'model_1', field: 'field_1' } }
          expect(collection).to be_valid
        end

        it 'is invalid without model_ref' do
          collection.metadata = { embedding_model => { field: 'field_1' } }
          expect(collection).not_to be_valid
        end

        it 'is invalid without field' do
          collection.metadata = { embedding_model => { model_ref: 'model_1' } }
          expect(collection).not_to be_valid
        end

        it 'is valid with null model_type' do
          collection.metadata = {
            embedding_model => { model_ref: 'model_1', field: 'field_1', model_type: nil }
          }
          expect(collection).to be_valid
        end

        it 'is valid with model_type=gitlab_managed' do
          collection.metadata = {
            embedding_model => { model_ref: 'model_1', field: 'field_1', model_type: 'gitlab_managed' }
          }
          expect(collection).to be_valid
        end

        it 'is valid with model_type=self_hosted' do
          collection.metadata = {
            embedding_model => { model_ref: '1', field: 'field_1', model_type: 'self_hosted' }
          }
          expect(collection).to be_valid
        end

        it 'is valid with nil or positive dimensions' do
          [nil, 768, 1000].each do |dimensions|
            collection.metadata = {
              embedding_model => { model_ref: 'model_1', field: 'field_1', dimensions: dimensions }
            }
            expect(collection).to be_valid
          end
        end

        it 'is invalid with negative dimensions' do
          [-1, 0].each do |dimensions|
            collection.metadata = {
              embedding_model => { model_ref: 'model_1', field: 'field_1', dimensions: dimensions }
            }
            expect(collection).not_to be_valid
          end
        end

        it 'is valid with nil or positive embeddings_request_batch_size' do
          [nil, 200].each do |batch_size|
            collection.metadata = {
              embedding_model => { model_ref: 'model_1', field: 'field_1', embeddings_request_batch_size: batch_size }
            }
            expect(collection).to be_valid
          end
        end

        it 'is invalid with non-positive or non-integer embeddings_request_batch_size' do
          [-1, 0, 'str'].each do |batch_size|
            collection.metadata = {
              embedding_model => { model_ref: 'model_1', field: 'field_1', embeddings_request_batch_size: batch_size }
            }
            expect(collection).not_to be_valid
          end
        end
      end
    end

    it 'is invalid with arbitrary properties' do
      collection.metadata = { key: 'value' }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end
  end

  describe 'options' do
    it 'is valid when empty' do
      collection.options = {}
      expect(collection).to be_valid
    end

    it 'is valid when values follow expected types' do
      collection.options = {
        queue_shard_count: 2,
        queue_shard_limit: 1000
      }

      expect(collection).to be_valid
    end

    it 'is valid when nullable values are nil' do
      collection.options = {
        queue_shard_count: nil,
        queue_shard_limit: nil
      }

      expect(collection).to be_valid
    end

    it 'is valid with chunk_strategy set to a known value' do
      collection.options = { chunk_strategy: 'code_bytes', chunk_strategy_size: 1000 }
      expect(collection).to be_valid
    end

    it 'is valid with chunk_strategy and chunk_strategy_size as nil' do
      collection.options = { chunk_strategy: nil, chunk_strategy_size: nil }
      expect(collection).to be_valid
    end

    it 'is invalid when chunk_strategy is set without chunk_strategy_size' do
      collection.options = { chunk_strategy: 'code_bytes' }
      expect(collection).not_to be_valid
      expect(collection.errors[:chunk_strategy_size]).to include("can't be blank")
    end

    it 'is invalid when chunk_strategy_size is set without chunk_strategy' do
      collection.options = { chunk_strategy_size: 1000 }
      expect(collection).not_to be_valid
      expect(collection.errors[:chunk_strategy]).to include("can't be blank")
    end

    describe 'invalid options' do
      using RSpec::Parameterized::TableSyntax

      where(:key, :value) do
        :queue_shard_count   | "some string"
        :queue_shard_count   | 0

        :queue_shard_limit   | "some string"
        :queue_shard_limit   | 0

        :chunk_strategy      | "invalid_strategy"
        :chunk_strategy_size | "some string"
        :chunk_strategy_size | 0
      end

      with_them do
        before do
          collection.options = { key => value }
        end

        it 'results in validation errors' do
          expect(collection).not_to be_valid
          expect(collection.errors[:options]).to include('must be a valid json schema')
        end
      end
    end
  end

  describe '.partition_for' do
    using RSpec::Parameterized::TableSyntax

    let(:collection) { create(:ai_active_context_collection, number_of_partitions: 5) }

    where(:routing_value, :partition_number) do
      1 | 0
      2 | 1
      3 | 3
      4 | 2
      5 | 3
      6 | 3
      7 | 4
      8 | 4
      9 | 2
      10 | 2
    end

    with_them do
      it 'always returns the same partition for a routing value' do
        expect(collection.partition_for(routing_value)).to eq(partition_number)
      end
    end
  end

  describe '#update_metadata!' do
    context 'with valid metadata' do
      it 'updates the metadata with valid values' do
        expect(collection.metadata).to eq({})

        collection.update_metadata!(collection_class: 'DummyCollectionClass')

        expect(collection.reload.metadata).to eq({ 'collection_class' => 'DummyCollectionClass' })
      end

      it 'merges with existing metadata' do
        collection.update_metadata!(collection_class: 'DummyCollectionClass')
        collection.update_metadata!(collection_class: 'MockCollectionClass')

        expect(collection.reload.metadata).to eq({ 'collection_class' => 'MockCollectionClass' })
      end

      it 'upserts and keeps existing metadata' do
        collection.update_metadata!(collection_class: 'MockCollectionClass')
        collection.update_metadata!(include_ref_fields: true)

        expect(collection.reload.metadata).to eq({
          'collection_class' => 'MockCollectionClass',
          'include_ref_fields' => true
        })
      end
    end

    context 'with invalid metadata' do
      it 'raises an error when validation fails' do
        expect { collection.update_metadata!(include_ref_fields: "str") }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'does not change the metadata when validation fails' do
        collection.update_metadata!(include_ref_fields: true)
        expect(collection.reload.metadata).to eq({ 'include_ref_fields' => true })

        expect { collection.update_metadata!(include_ref_fields: "str") }.to raise_error(ActiveRecord::RecordInvalid)
        expect(collection.reload.metadata).to eq({ 'include_ref_fields' => true })
      end
    end
  end

  describe '#update_options!' do
    it 'upserts and keeps existing options' do
      collection.update!(options: { queue_shard_count: 2 })

      collection.reload
      expect(collection.options.symbolize_keys).to eq({ queue_shard_count: 2 })

      collection.update_options!({ queue_shard_limit: 200 })

      collection.reload
      expect(collection.options.symbolize_keys).to eq({
        queue_shard_count: 2,
        queue_shard_limit: 200
      })
    end

    describe 'chunking strategy guard' do
      let(:error_message) { 'chunking strategy can only be set when there is no current model' }

      context 'when setting chunk_strategy for the first time (no current embedding model)' do
        it 'succeeds' do
          expect { collection.update_options!(chunk_strategy: 'code_bytes', chunk_strategy_size: 1000) }
            .not_to raise_error
        end
      end

      context 'when changing chunk_strategy after indexing has begun (current_indexing_embedding_model present)' do
        before do
          collection.update!(options: { chunk_strategy: 'code_bytes', chunk_strategy_size: 1000 })
          collection.update_metadata!(
            current_indexing_embedding_model: { model_ref: 'model_1', field: 'embeddings_v1' }
          )
          collection.reload
        end

        it 'raises ChunkStrategyLocked error' do
          expect { collection.update_options!(chunk_strategy: 'code_pre_bert') }
            .to raise_error(Ai::ActiveContext::Collection::ChunkStrategyLocked, error_message)
        end
      end

      context 'when changing chunk_strategy_size after indexing has begun' do
        before do
          collection.update!(options: { chunk_strategy: 'code_bytes', chunk_strategy_size: 1000 })
          collection.update_metadata!(
            current_indexing_embedding_model: { model_ref: 'model_1', field: 'embeddings_v1' }
          )
          collection.reload
        end

        it 'raises ChunkStrategyLocked' do
          expect { collection.update_options!(chunk_strategy_size: 500) }
            .to raise_error(Ai::ActiveContext::Collection::ChunkStrategyLocked, error_message)
        end
      end

      context 'when setting chunk_strategy to the same value (no actual change)' do
        before do
          collection.update!(options: { chunk_strategy: 'code_bytes', chunk_strategy_size: 1000 })
          collection.update_metadata!(
            current_indexing_embedding_model: { model_ref: 'model_1', field: 'embeddings_v1' }
          )
          collection.reload
        end

        it 'succeeds without raising' do
          expect { collection.update_options!(chunk_strategy: 'code_bytes') }
            .not_to raise_error
        end
      end

      context 'when updating non-chunking options after indexing has begun' do
        before do
          collection.update_metadata!(
            current_indexing_embedding_model: { model_ref: 'model_1', field: 'embeddings_v1' }
          )
          collection.reload
        end

        it 'succeeds' do
          expect { collection.update_options!(queue_shard_count: 4) }
            .not_to raise_error
        end
      end
    end
  end

  describe 'jsonb_accessor' do
    it 'defines accessor methods for metadata fields' do
      expect(collection).to respond_to(:include_ref_fields)
      expect(collection).to respond_to(:collection_class)
    end

    it 'persists all accessor values to the metadata column' do
      collection.include_ref_fields = true
      collection.collection_class = 'MyClass'

      collection.save!

      expect(collection.reload.metadata).to include(
        'include_ref_fields' => true,
        'collection_class' => 'MyClass'
      )
    end
  end

  describe 'embedding model accessor methods' do
    where(:embedding_model) do
      [:current_indexing_embedding_model, :next_indexing_embedding_model, :search_embedding_model]
    end

    with_them do
      context 'with embedding model metadata' do
        before do
          collection.update_metadata!({
            embedding_model => { model_ref: 'model_123', field: 'embeddings_v123' }
          })
        end

        it 'returns the embedding model metadata' do
          model_metadata = collection.public_send(embedding_model)

          expect(model_metadata[:model_ref]).to eq('model_123')
          expect(model_metadata[:field]).to eq('embeddings_v123')
        end
      end

      context 'without embedding model metadata' do
        before do
          collection.update!(metadata: {})
        end

        it 'returns nil' do
          expect(collection.public_send(embedding_model)).to be_nil
        end
      end
    end
  end

  describe '#name_without_prefix' do
    before do
      collection.update!(name: 'documents')
    end

    it 'delegates to the adapter to remove the prefix from the collection name' do
      expect(collection.name_without_prefix)
        .to eq(collection.connection.adapter.collection_name_without_prefix(collection.name))
    end

    it 'returns the name unchanged' do
      expect(collection.name_without_prefix).to eq('documents')
    end
  end
end

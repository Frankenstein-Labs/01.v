# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Collections::Code, :aggregate_failures, feature_category: :code_suggestions do
  let_it_be(:connection) do
    create(:ai_active_context_connection, :elasticsearch)
  end

  let_it_be_with_reload(:collection) do
    create(:ai_active_context_collection, name: described_class.collection_name, connection: connection)
  end

  before do
    allow(described_class).to receive(:collection_record).and_return(collection)
  end

  describe '.indexing?' do
    it 'returns false when indexing is disabled' do
      allow(ActiveContext).to receive(:indexing?).and_return(false)

      expect(described_class.indexing?).to be(false)
    end

    context 'when ActiveContext indexing is enabled' do
      before do
        allow(ActiveContext).to receive(:indexing?).and_return(true)
      end

      it 'returns false when the collection record does not exist' do
        allow(described_class).to receive(:collection_record).and_return(nil)

        expect(described_class.indexing?).to be(false)
      end

      it 'returns false when the collection does not have a current embedding version' do
        collection.update_metadata!(current_indexing_embedding_model: nil)

        expect(described_class.indexing?).to be(false)
      end

      context 'when the collection has a current embedding version' do
        before do
          collection.update_metadata!(
            current_indexing_embedding_model: { model_ref: 'text_embedding_005_vertex', field: 'test_field_123' }
          )
        end

        it 'returns false if feature setting is not allowed' do
          allow(described_class).to receive(:feature_setting_allowed?).and_return(false)

          expect(described_class.indexing?).to be(false)
        end

        it 'returns true if feature setting is allowed' do
          allow(described_class).to receive(:feature_setting_allowed?).and_return(true)

          expect(described_class.indexing?).to be(true)
        end
      end
    end
  end

  describe '.feature_setting_allowed?' do
    it 'returns true when GitLab selects the embedding model' do
      allow(Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(true)

      expect(described_class.feature_setting_allowed?).to be(true)
    end

    context 'when user selects the embedding model' do
      before do
        allow(Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(false)

        allow(Ai::ActiveContext::Embedding).to receive(:feature_setting_allowed?)
            .with('code').and_return(embedding_feature_setting_allowed)
      end

      where(:embedding_feature_setting_allowed) { [false, true] }

      with_them do
        it 'delegates to Ai::ActiveContext::Embedding.feature_setting_allowed?' do
          expect(described_class.feature_setting_allowed?).to be(embedding_feature_setting_allowed)
        end
      end
    end
  end

  describe '.embedding_model_factory' do
    it 'returns the expected model factory class' do
      expect(described_class.embedding_model_factory).to eq(::Ai::ActiveContext::Embeddings::ModelFactory)
    end
  end

  describe '.track_refs!' do
    it 'tracks all hashes with the routing in a single call' do
      routing = '123'
      hashes = %w[hash1 hash2 hash3]

      expect(described_class).to receive(:track!).with(
        [
          { id: 'hash1', routing: routing },
          { id: 'hash2', routing: routing },
          { id: 'hash3', routing: routing }
        ]
      )

      described_class.track_refs!(routing: routing, hashes: hashes)
    end
  end

  describe '.track!' do
    let(:id) { 'hash' }
    let(:routing) { '123' }

    it 'enqueues an object correctly' do
      described_class.track!({ id: id, routing: routing })

      queued_items = ActiveContext::Queues.all_queued_items.values.flatten
      expect(queued_items.count).to eq(1)
      expect(queued_items.first).to eq("Ai::ActiveContext::References::Code|#{collection.reload.id}|#{routing}|#{id}")
    end

    context 'when collection record is not found' do
      before do
        allow(described_class).to receive(:collection_record).and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.track!({ id: id, routing: routing }) }
          .to raise_error(StandardError, /expected to have a collection record/)
      end
    end
  end

  describe '.redact_unauthorized_results!' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project_1) { create(:project, owners: [user]) }
    let_it_be(:project_2) { create(:project, owners: [user]) }
    let_it_be(:unauthorized_project) { create(:project) }

    let(:hit_1) { { 'id' => 1, 'project_id' => project_1.id, 'content' => 'test content 1' } }
    let(:hit_2) { { 'id' => 2, 'project_id' => project_2.id, 'content' => 'test content 2' } }
    let(:hit_3) { { 'id' => 3, 'project_id' => unauthorized_project.id, 'content' => 'test content 3' } }
    let(:elasticsearch_result) do
      {
        'hits' => {
          'total' => { 'value' => 2 },
          'hits' => [
            { '_source' => hit_1 },
            { '_source' => hit_2 },
            { '_source' => hit_3 }
          ]
        }
      }
    end

    let(:result) do
      ActiveContext::Databases::Elasticsearch::QueryResult.new(
        result: elasticsearch_result,
        collection: collection,
        user: user
      )
    end

    it 'includes results for projects accessible to the user' do
      new_result = described_class.redact_unauthorized_results!(result)
      expect(new_result.pluck('id')).to eq([hit_1['id'], hit_2['id']])
    end

    context 'when project is not found' do
      before do
        project_2.delete
      end

      it 'excludes results for the project' do
        new_result = described_class.redact_unauthorized_results!(result)
        expect(new_result.pluck('id')).to eq([hit_1['id']])
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns the original result without filtering' do
        expect(described_class.redact_unauthorized_results!(result)).to eq(result)
      end
    end
  end

  describe '.partition_name' do
    it 'is the collection name' do
      expect(described_class.partition_name).to eq(collection.name)
    end
  end

  describe '.partition_number' do
    it 'is calculated from collection.partition_for' do
      expect(collection).to receive(:partition_for).with('something')

      described_class.partition_number('something')
    end
  end

  describe 'embedding models' do
    shared_examples 'embedding model' do
      subject(:embedding_model) do
        described_class.public_send(embedding_model_key)
      end

      context 'when collection_record is nil' do
        let(:collection) { nil }

        it { is_expected.to be_nil }
      end

      context "when collection_record's model metadata is nil" do
        before do
          allow(collection).to receive(embedding_model_key).and_return(nil)
        end

        it { is_expected.to be_nil }
      end

      context "when collection_record's model metadata is set" do
        before do
          allow(collection).to receive(embedding_model_key).and_return(model_metadata)
          allow(Ai::ActiveContext::Embeddings::ModelFactory).to receive(:for).and_call_original
        end

        let(:model_metadata) do
          {
            model_ref: 'text_embedding_005_vertex',
            field: 'some_field_1'
          }
        end

        it 'builds an embedding model through the embedding_model_factory' do
          expect(Ai::ActiveContext::Embeddings::ModelFactory)
            .to receive(:for).with(model_metadata, **expected_custom_build_params)

          expect(embedding_model).to be_a(::ActiveContext::EmbeddingModel)
          expect(embedding_model.model_key).to eq('gitlab_managed__text_embedding_005_vertex')
          expect(embedding_model.field).to eq(:some_field_1)
        end

        context 'when the model metadata has a configured embeddings_request_batch_size' do
          let(:model_metadata) do
            {
              model_ref: 'text_embedding_005_vertex',
              field: 'some_field_1',
              embeddings_request_batch_size: 15
            }
          end

          it 'sets the embeddings_request_batch_size as the llm_params[:batch_size]' do
            expect(Ai::ActiveContext::Embeddings::ModelFactory)
              .to receive(:for).with(model_metadata, **expected_custom_build_params)

            expect(embedding_model).to be_a(::ActiveContext::EmbeddingModel)
            expect(embedding_model.model_key).to eq('gitlab_managed__text_embedding_005_vertex')
            expect(embedding_model.field).to eq(:some_field_1)
            expect(embedding_model.llm_params[:batch_size]).to eq(15)
          end
        end

        context "when model_metadata is an empty hash" do
          let(:model_metadata) { {} }

          it 'raises an error' do
            expect { embedding_model }.to raise_error(
              Ai::ActiveContext::Embeddings::ModelFactory::UnexpectedModelConfiguration,
              "`model_metadata` must have a `model_ref` and `field`"
            )
          end
        end

        context 'when model_metadata[:model_ref] is not in the embedding models lookup' do
          let(:model_metadata) do
            {
              model_ref: 'some_mock_model_ref',
              field: 'some_field_1'
            }
          end

          it 'raises an error' do
            expect { embedding_model }.to raise_error(
              Ai::ActiveContext::Embeddings::ModelFactory::MissingModelDefinition,
              "Missing definitions for Gitlab-managed model: some_mock_model_ref"
            )
          end
        end
      end
    end

    describe '#current_indexing_embedding_model' do
      it_behaves_like 'embedding model' do
        let(:embedding_model_key) { :current_indexing_embedding_model }
        let(:expected_custom_build_params) { {} }
      end
    end

    describe '#next_indexing_embedding_model' do
      it_behaves_like 'embedding model' do
        let(:embedding_model_key) { :next_indexing_embedding_model }
        let(:expected_custom_build_params) { {} }
      end
    end

    describe '#search_embedding_model' do
      it_behaves_like 'embedding model' do
        let(:embedding_model_key) { :search_embedding_model }
        let(:expected_custom_build_params) { { search: true } }
      end
    end
  end
end

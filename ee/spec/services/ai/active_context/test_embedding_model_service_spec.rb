# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::TestEmbeddingModelService, :aggregate_failures, feature_category: :global_search do
  shared_examples 'tests gitlab-managed model' do
    context 'when model_ref is a valid gitlab-managed model' do
      let(:model_ref) { 'text_embedding_005_vertex' }

      it 'tests embeddings generation and returns a successful response' do
        expect(::ActiveContext::EmbeddingModel).to receive(:new).with(
          hash_including(
            model_ref: model_ref,
            model_type: :gitlab_managed,
            dimensions: dimensions
          )
        )
        expect(mock_ac_embedding_model).to receive(:generate_embeddings)

        response = service.execute

        expect(response.success?).to be(true)
        expect(response.payload).to eq({
          tested_model_metadata: {
            model_type: model_type&.to_sym,
            model_ref: model_ref,
            dimensions: dimensions
          }
        })
      end
    end

    context 'when model_ref is not a valid gitlab-managed model' do
      let(:model_ref) { 'test_model_001' }

      it 'returns an error response' do
        response = service.execute

        expect(response.error?).to be(true)
        expect(response.message).to eq("Missing definitions for Gitlab-managed model: test_model_001")
      end
    end
  end

  let(:collection_class) { Ai::ActiveContext::Collections::Code }
  let(:model_ref) { 'text_embedding_005_vertex' }
  let(:dimensions) { 4 }
  let(:model_type) { nil }

  subject(:service) do
    described_class.new(
      collection_class: collection_class,
      model_ref: model_ref,
      dimensions: dimensions,
      model_type: model_type
    )
  end

  describe '#execute' do
    before do
      # mock embeddings generations request
      allow(mock_ac_embedding_model).to receive(:generate_embeddings).and_return([[1, 2, 3, 4]])
      allow(::ActiveContext::EmbeddingModel).to receive(:new).and_return(mock_ac_embedding_model)

      # assume Gitlab-selected model by default
      allow(Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(true)
    end

    let(:mock_ac_embedding_model) { instance_double(::ActiveContext::EmbeddingModel) }

    it_behaves_like 'tests gitlab-managed model'

    context 'for user-selected models' do
      before do
        allow(Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(false)
      end

      context 'when model_type=gitlab_managed' do
        let(:model_type) { 'gitlab_managed' }

        it_behaves_like 'tests gitlab-managed model'
      end

      context 'when model_type=self_hosted' do
        let_it_be(:self_hosted_embedding_model) do
          create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 1')
        end

        let_it_be(:self_hosted_general_model) do
          create(:ai_self_hosted_model, :general, name: 'General Model')
        end

        let(:model_type) { 'self_hosted' }

        context 'when model_ref is an embedding self-hosted model' do
          let(:model_ref) { self_hosted_embedding_model.id.to_s }

          it 'tests embeddings generation and returns a successful response' do
            expect(::ActiveContext::EmbeddingModel).to receive(:new).with(
              hash_including(
                model_ref: model_ref,
                model_type: :self_hosted,
                dimensions: dimensions
              )
            )
            expect(mock_ac_embedding_model).to receive(:generate_embeddings)

            response = service.execute

            expect(response.success?).to be(true)
            expect(response.payload).to eq({
              tested_model_metadata: {
                model_type: :self_hosted,
                model_ref: model_ref,
                dimensions: dimensions
              }
            })
          end
        end

        context 'when model_ref is a non-embedding self-hosted model' do
          let(:model_ref) { self_hosted_general_model.id.to_s }

          it 'returns an error response' do
            response = service.execute

            expect(response.error?).to be(true)
            expect(response.message).to eq("Self-hosted model must have 'embedding' family")
          end
        end

        context 'when model_ref is not a self-hosted model' do
          let(:model_ref) { 'text_embedding_005_vertex' }

          it 'returns an error response' do
            response = service.execute

            expect(response.error?).to be(true)
            expect(response.message).to eq("Self-hosted model with ID 'text_embedding_005_vertex' not found")
          end
        end
      end
    end

    context 'when there is an error in the embeddings request' do
      before do
        allow(mock_ac_embedding_model).to receive(:generate_embeddings).and_raise(
          StandardError, "error in embeddings generation"
        )
      end

      it 'returns an error response' do
        response = service.execute

        expect(response.error?).to be(true)
        expect(response.message).to eq("error in embeddings generation")
      end
    end

    context 'when the result is an empty array' do
      before do
        allow(mock_ac_embedding_model).to receive(:generate_embeddings).and_return([])
      end

      it 'returns an error indicating empty result' do
        response = service.execute

        expect(response.error?).to be(true)
        expect(response.message).to eq("Embeddings request returned no results.")
      end
    end

    context 'when the embeddings is empty' do
      before do
        allow(mock_ac_embedding_model).to receive(:generate_embeddings).and_return([[]])
      end

      it 'returns an error indicating empty result' do
        response = service.execute

        expect(response.error?).to be(true)
        expect(response.message).to eq("Embeddings request returned no results.")
      end
    end

    context 'when the resulting embeddings dimensions do not match the given dimensions' do
      before do
        allow(mock_ac_embedding_model).to receive(:generate_embeddings).and_return([[1, 2]])
      end

      it 'returns an error response' do
        response = service.execute

        expect(response.error?).to be(true)
        expect(response.message).to eq(
          "Result dimensions did not match the given dimensions. " \
            "The AI Gateway can only support the default dimensions for this model. " \
            "Please set the dimensions to `2`, " \
            "or file an issue with GitLab to request for non-default dimensions support."
        )
      end
    end
  end
end

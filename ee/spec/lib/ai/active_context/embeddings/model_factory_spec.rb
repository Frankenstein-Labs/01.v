# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Embeddings::ModelFactory, :aggregate_failures, feature_category: :code_suggestions do
  describe '.for' do
    subject(:embedding_model) { described_class.for(model_metadata) }

    let(:model_metadata) { nil }

    shared_examples 'returns nil if model_metadata is not set' do
      context 'when model_metadata is nil' do
        let(:model_metadata) { nil }

        it 'returns nil' do
          expect(embedding_model).to be_nil
        end
      end
    end

    shared_examples 'requires `model_ref` and `field` metadata' do
      context 'when model_metadata[:model_ref] is not set' do
        let(:model_metadata) { { field: 'test_embeddings_field' } }

        it 'raises an error' do
          expect { embedding_model }.to raise_error(
            described_class::UnexpectedModelConfiguration,
            "`model_metadata` must have a `model_ref` and `field`"
          )
        end
      end

      context 'when model_metadata[:field] is not set' do
        let(:model_metadata) { { model_ref: 'text_embedding_005_vertex' } }

        it 'raises an error' do
          expect { embedding_model }.to raise_error(
            described_class::UnexpectedModelConfiguration,
            "`model_metadata` must have a `model_ref` and `field`"
          )
        end
      end
    end

    shared_examples 'supports search embedding model' do
      it 'sets LLM parameter search=true' do
        expect(embedding_model.llm_class).to eq(::Gitlab::Llm::Embeddings::CodeEmbeddings)

        expect(embedding_model.llm_params).to match(
          hash_including(
            search: true,
            model_definition: be_a(::Gitlab::Llm::Embeddings::ModelDefinition)
          )
        )
      end
    end

    shared_examples 'supports embedding model with dimensions' do
      it 'sets the dimensions and includes it in the llm_params' do
        expect(embedding_model.llm_class).to eq(::Gitlab::Llm::Embeddings::CodeEmbeddings)
        expect(embedding_model.dimensions).to eq(32)

        expect(embedding_model.llm_params[:dimensions]).to eq(32)
      end
    end

    shared_examples 'gitlab-managed model' do
      context 'when model_metadata has the required values' do
        context 'when model_ref is not in the embedding models lookup' do
          before do
            allow(::Ai::ActiveContext::Embedding).to receive(:gitlab_managed_models_lookup).and_return({})
          end

          it 'raises an error if model_ref is not in the embedding models lookup' do
            expect { embedding_model }.to raise_error(
              described_class::MissingModelDefinition,
              "Missing definitions for Gitlab-managed model: text_embedding_005_vertex"
            )
          end
        end

        context 'when model_ref is in the embedding models lookup' do
          it 'returns the expected gitlab-selected model' do
            expect(embedding_model).to be_a(::ActiveContext::EmbeddingModel)
            expect(embedding_model.model_ref).to eq("text_embedding_005_vertex")
            expect(embedding_model.model_type).to eq(:gitlab_managed)
            expect(embedding_model.model_key).to eq("gitlab_managed__text_embedding_005_vertex")
            expect(embedding_model.field).to eq(:test_embeddings_field)
            expect(embedding_model.dimensions).to be_nil

            expect(embedding_model.llm_class).to eq(::Gitlab::Llm::Embeddings::CodeEmbeddings)

            expect(embedding_model.llm_params).to match(
              batch_size: 30,
              search: false,
              model_definition: be_a(::Gitlab::Llm::Embeddings::ModelDefinition)
            )

            llm_model_definition = embedding_model.llm_params[:model_definition]
            expect(llm_model_definition.feature_name).to eq(:embeddings_code)
            expect(llm_model_definition.unit_primitive).to eq(
              ::Gitlab::Llm::Embeddings::ModelDefinition::UNIT_PRIMITIVE_GENERATE_EMBEDDINGS_CODEBASE
            )
            expect(llm_model_definition.provider).to eq('gitlab')
            expect(llm_model_definition.identifier).to eq('text_embedding_005_vertex')
            expect(llm_model_definition.use_cloud_aigw).to be(expected_use_cloud_aigw_value)
            expect(llm_model_definition.custom_model).to be(false)
          end

          context 'for search embedding model' do
            subject(:embedding_model) { described_class.for(model_metadata, search: true) }

            it_behaves_like 'supports search embedding model'
          end

          context 'with dimensions' do
            subject(:embedding_model) { described_class.for(model_metadata.merge(dimensions: 32)) }

            it_behaves_like 'supports embedding model with dimensions'
          end

          context 'when embeddings_request_batch_size is set in the model_metadata' do
            subject(:embedding_model) do
              described_class.for(model_metadata.merge(embeddings_request_batch_size: 15))
            end

            it 'uses the given batch size' do
              expect(embedding_model.llm_params[:batch_size]).to eq(15)
            end
          end
        end
      end
    end

    shared_examples 'gitlab selects the model' do
      it_behaves_like 'returns nil if model_metadata is not set'
      it_behaves_like 'requires `model_ref` and `field` metadata'

      it_behaves_like 'gitlab-managed model' do
        let(:model_metadata) { { model_ref: 'text_embedding_005_vertex', field: 'test_embeddings_field' } }
        let(:expected_use_cloud_aigw_value) { false }
      end
    end

    context 'for semantic search on SaaS' do
      include_context 'for semantic search on SaaS'

      it_behaves_like 'gitlab selects the model'
    end

    context 'for semantic search on Dedicated' do
      include_context 'for semantic search on Dedicated'

      it_behaves_like 'gitlab selects the model'
    end

    context 'for semantic search on Self-Managed without self-hosted AIGW' do
      include_context 'for semantic search on Self-Managed without self-hosted AIGW'

      it_behaves_like 'gitlab selects the model'
    end

    context 'for semantic search on Self-Managed with self-hosted AIGW' do
      include_context 'for semantic search on Self-Managed with self-hosted AIGW'

      it_behaves_like 'returns nil if model_metadata is not set'
      it_behaves_like 'requires `model_ref` and `field` metadata'

      context 'when model_metadata[:model_type] is nil' do
        let(:model_metadata) { { model_ref: 'text_embedding_005_vertex', field: 'test_embeddings_field' } }

        it 'raises an error' do
          expect { embedding_model }.to raise_error(
            described_class::UnexpectedModelConfiguration,
            "`model_metadata` must have a `model_type` if Duo Self-Hosted is configured"
          )
        end
      end

      context 'when model_metadata[:model_type] is `gitlab_managed`' do
        it_behaves_like 'gitlab-managed model' do
          let(:model_metadata) do
            { model_ref: 'text_embedding_005_vertex', field: 'test_embeddings_field', model_type: 'gitlab_managed' }
          end

          let(:expected_use_cloud_aigw_value) { true }
        end
      end

      context 'when model_metadata[:model_type] is `self_hosted`' do
        let_it_be(:self_hosted_embedding_model) do
          create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 1')
        end

        let_it_be(:self_hosted_general_model) do
          create(:ai_self_hosted_model, :general, name: 'General Model')
        end

        let(:model_metadata) do
          { model_ref: self_hosted_model_id, field: 'test_embeddings_field', model_type: 'self_hosted' }
        end

        context 'when the given model_ref does not point to a self-hosted model record' do
          where(:self_hosted_model_id) { [0, 'str'] }

          with_them do
            it 'raises an error' do
              expect { embedding_model }.to raise_error(
                described_class::MissingModelDefinition,
                "Self-hosted model with ID '#{self_hosted_model_id}' not found"
              )
            end
          end
        end

        context 'when the given model_ref points to a non-embedding self-hosted model' do
          let(:self_hosted_model_id) { self_hosted_general_model.id }

          it 'raises an error' do
            expect { embedding_model }.to raise_error(
              described_class::UnexpectedModelConfiguration,
              "Self-hosted model must have 'embedding' family"
            )
          end
        end

        context 'when the given model_ref points to an embedding self-hosted model' do
          let(:self_hosted_model_id) { self_hosted_embedding_model.id }

          it 'returns the expected self-hosted model' do
            expect(embedding_model).to be_a(::ActiveContext::EmbeddingModel)
            expect(embedding_model.model_ref).to eq(self_hosted_embedding_model.id)
            expect(embedding_model.model_type).to eq(:self_hosted)
            expect(embedding_model.model_key).to eq("self_hosted__#{self_hosted_embedding_model.id}")
            expect(embedding_model.field).to eq(:test_embeddings_field)
            expect(embedding_model.dimensions).to be_nil

            expect(embedding_model.llm_class).to eq(::Gitlab::Llm::Embeddings::CodeEmbeddings)

            expect(embedding_model.llm_params).to match(
              model_definition: be_a(::Gitlab::Llm::Embeddings::ModelDefinition),
              batch_size: 30,
              search: false
            )

            llm_model_definition = embedding_model.llm_params[:model_definition]
            expect(llm_model_definition.feature_name).to eq(:embeddings_code)
            expect(llm_model_definition.unit_primitive).to eq(
              ::Gitlab::Llm::Embeddings::ModelDefinition::UNIT_PRIMITIVE_GENERATE_EMBEDDINGS_CODEBASE
            )
            expect(llm_model_definition.provider).to eq('litellm')
            expect(llm_model_definition.identifier).to eq(self_hosted_embedding_model.id)
            expect(llm_model_definition.use_cloud_aigw).to be(false)
            expect(llm_model_definition.custom_model).to be(true)
          end

          context 'for search embedding model' do
            subject(:embedding_model) { described_class.for(model_metadata, search: true) }

            it_behaves_like 'supports search embedding model'
          end

          context 'with dimensions' do
            subject(:embedding_model) { described_class.for(model_metadata.merge(dimensions: 32)) }

            it_behaves_like 'supports embedding model with dimensions'
          end

          context 'when embeddings_request_batch_size is set in the model_metadata' do
            subject(:embedding_model) do
              described_class.for(model_metadata.merge(embeddings_request_batch_size: 15))
            end

            it 'uses given batch size' do
              expect(embedding_model.llm_params[:batch_size]).to eq(15)
            end
          end
        end
      end

      context 'when model_metadata[:model_type] is not supported' do
        let(:model_metadata) do
          { model_ref: 'text_embedding_005_vertex', field: 'test_embeddings_field', model_type: 'dummy' }
        end

        it 'raises an error' do
          expect { embedding_model }.to raise_error(
            described_class::UnsupportedModelConfiguration,
            "`model_type` must be one of the following values: gitlab_managed|self_hosted"
          )
        end
      end
    end
  end
end

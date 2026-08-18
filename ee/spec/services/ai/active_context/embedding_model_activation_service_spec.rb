# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::EmbeddingModelActivationService, :aggregate_failures, feature_category: :global_search do
  let(:model_ref) { 'text_embedding_005_vertex' }
  let(:dimensions) { 768 }
  let(:model_type) { nil }
  let(:user) { nil }
  let(:expected_field_name) { 'embeddings_v1' }

  subject(:service) do
    described_class.new(
      collection_class: Ai::ActiveContext::Collections::Code,
      model_ref: model_ref,
      dimensions: dimensions,
      model_type: model_type,
      user: user
    )
  end

  describe '#initialize' do
    it 'initializes successfully' do
      expect(service).to be_a(described_class)
    end
  end

  describe '#execute!' do
    shared_examples 'successfully tests and updates the collection model' do
      it 'tests the given model metadata and updates collection.next_indexing_embedding_model' do
        expect(Ai::ActiveContext::TestEmbeddingModelService).to receive(:new).with(
          collection_class: Ai::ActiveContext::Collections::Code,
          model_ref: model_ref,
          dimensions: dimensions,
          model_type: model_type
        )
        expect(test_model_service).to receive(:execute)

        service.execute!

        expect(collection.reload.next_indexing_embedding_model.symbolize_keys).to eq({
          model_type: model_type,
          model_ref: model_ref,
          field: expected_field_name,
          dimensions: dimensions
        })
      end
    end

    shared_examples 'fails pre-flight checks' do
      it 'raises an InvalidError and does not test and update the model' do
        expect(Ai::ActiveContext::TestEmbeddingModelService).not_to receive(:new)
        expect(task_service).not_to receive(:create_chain)

        expect { service.execute! }.to raise_error(
          described_class::InvalidError, expected_error_message
        ).and not_change { collection.reload.next_indexing_embedding_model }
      end
    end

    shared_examples 'initiates model switching tasks without feature settings sync' do
      context 'when no previous embedding model exists' do
        it 'creates a chain with AddEmbeddingsField and UpdateCollectionMetadata only' do
          service.execute!

          expect(task_service).to have_received(:create_chain).with(
            [Ai::ActiveContext::Tasks::AddEmbeddingsField, {
              'collection' => collection.name_without_prefix,
              'field' => expected_field_name,
              'dimensions' => dimensions
            }],
            [Ai::ActiveContext::Tasks::UpdateCollectionMetadata, {
              'collection' => collection.name_without_prefix,
              'metadata' => {
                'current_indexing_embedding_model' => hash_including('field' => expected_field_name),
                'search_embedding_model' => hash_including('field' => expected_field_name),
                'next_indexing_embedding_model' => nil
              }
            }]
          )
        end
      end

      context 'when previous embedding model exists' do
        let(:previous_model_type) { nil }
        let(:previous_model_ref) { 'mock_embedding_001' }
        let(:previous_field_name) { 'embeddings_v1' }
        let(:expected_field_name) { 'embeddings_v2' }

        before do
          collection.reload.update_metadata!(
            current_indexing_embedding_model: {
              model_type: previous_model_type,
              model_ref: previous_model_ref,
              dimensions: dimensions,
              field: previous_field_name
            }
          )
        end

        it 'creates a chain with all four tasks, using the new field for indexing and old field for nullification' do
          service.execute!

          expect(task_service).to have_received(:create_chain).with(
            [Ai::ActiveContext::Tasks::AddEmbeddingsField, {
              'collection' => collection.name_without_prefix,
              'field' => expected_field_name,
              'dimensions' => dimensions
            }],
            [Ai::ActiveContext::Tasks::BackfillEmbeddings, {
              'collection' => collection.name_without_prefix,
              'field' => expected_field_name
            }],
            [Ai::ActiveContext::Tasks::UpdateCollectionMetadata, {
              'collection' => collection.name_without_prefix,
              'metadata' => {
                'current_indexing_embedding_model' => hash_including('field' => expected_field_name),
                'search_embedding_model' => hash_including('field' => expected_field_name),
                'next_indexing_embedding_model' => nil
              }
            }],
            [Ai::ActiveContext::Tasks::NullifyField, {
              'collection' => collection.name_without_prefix,
              'field' => previous_field_name
            }]
          )
        end
      end
    end

    shared_examples 'initiates model switching with feature settings sync' do
      context 'when no previous embedding model exists' do
        it 'includes SyncFeatureSettings in the task chain creation' do
          service.execute!

          expect(task_service).to have_received(:create_chain).with(
            [Ai::ActiveContext::Tasks::AddEmbeddingsField, anything],
            [Ai::ActiveContext::Tasks::UpdateCollectionMetadata, anything],
            [Ai::ActiveContext::Tasks::SyncFeatureSettings, {
              'collection' => collection.name_without_prefix,
              'metadata' => hash_including('field' => expected_field_name),
              'user_id' => user.id
            }]
          )
        end
      end

      context 'when previous embedding model exists' do
        let(:previous_model_type) { 'gitlab_managed' }
        let(:previous_model_ref) { 'mock_embedding_001' }
        let(:previous_field_name) { 'embeddings_v1' }
        let(:expected_field_name) { 'embeddings_v2' }

        before do
          collection.reload.update_metadata!(
            current_indexing_embedding_model: {
              model_type: previous_model_type,
              model_ref: previous_model_ref,
              dimensions: dimensions,
              field: previous_field_name
            }
          )
        end

        it 'includes SyncFeatureSettings in the task chain creation' do
          service.execute!

          expect(task_service).to have_received(:create_chain).with(
            [Ai::ActiveContext::Tasks::AddEmbeddingsField, anything],
            [Ai::ActiveContext::Tasks::BackfillEmbeddings, anything],
            [Ai::ActiveContext::Tasks::UpdateCollectionMetadata, anything],
            [Ai::ActiveContext::Tasks::SyncFeatureSettings, {
              'collection' => collection.name_without_prefix,
              'metadata' => hash_including('field' => expected_field_name),
              'user_id' => user.id
            }],
            [Ai::ActiveContext::Tasks::NullifyField, anything]
          )
        end
      end
    end

    let_it_be_with_reload(:collection) { create(:ai_active_context_collection, :code_collection) }
    let(:task_service) { instance_double(Ai::ActiveContext::TaskService) }
    let(:test_model_service) { instance_double(Ai::ActiveContext::TestEmbeddingModelService) }
    let(:test_model_response) { ServiceResponse.success }

    before do
      allow(Ai::ActiveContext::TaskService).to receive(:new).and_return(task_service)
      allow(task_service).to receive(:create_chain)

      allow(Ai::ActiveContext::TestEmbeddingModelService).to receive(:new).and_return(test_model_service)
      allow(test_model_service).to receive(:execute).and_return(test_model_response)

      collection.reload
      allow(collection).to receive(:update_metadata!).and_call_original
      allow(Ai::ActiveContext::Collections::Code).to receive(:collection_record).and_return(collection)

      allow(Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(true)
    end

    context 'when model_type is not given' do
      let(:model_type) { nil }

      it_behaves_like 'successfully tests and updates the collection model'

      it_behaves_like 'initiates model switching tasks without feature settings sync'

      context 'when unsupported model_ref is provided' do
        let(:model_ref) { 'test_model_001' }

        it_behaves_like 'fails pre-flight checks' do
          let(:expected_error_message) { "the given model 'test_model_001' is not offered by GitLab" }
        end
      end
    end

    context 'when model_type=gitlab_managed' do
      let(:model_type) { 'gitlab_managed' }

      it_behaves_like 'successfully tests and updates the collection model'

      it_behaves_like 'initiates model switching tasks without feature settings sync'

      context 'when unsupported model_ref is provided' do
        let(:model_ref) { 'test_model_001' }

        it_behaves_like 'fails pre-flight checks' do
          let(:expected_error_message) { "the given model 'test_model_001' is not offered by GitLab" }
        end
      end
    end

    context 'when model_type=self_hosted' do
      let(:model_type) { 'self_hosted' }

      it_behaves_like 'fails pre-flight checks' do
        let(:expected_error_message) { "model_type 'self_hosted' is not supported in the instance" }
      end
    end

    context 'when unsupported model_type is provided' do
      let(:model_type) { 'some_type' }

      it 'raises UpdateFailed and does not update the embedding model' do
        expect { service.execute! }.to raise_error(
          described_class::UpdateFailed,
          "Ai::ActiveContext::Collection - Validation failed: " \
            "Metadata must be a valid json schema"
        ).and not_change { collection.reload.next_indexing_embedding_model }
      end
    end

    context 'when unsupported dimensions value is provided' do
      let(:dimensions) { 0 }

      it 'raises UpdateFailed and does not create a task chain' do
        expect(collection).to receive(:update_metadata!).with(
          next_indexing_embedding_model: hash_including('dimensions' => 0)
        )
        expect(task_service).not_to receive(:create_chain)

        expect { service.execute! }.to raise_error(
          described_class::UpdateFailed,
          "Ai::ActiveContext::Collection - " \
            "Validation failed: Metadata must be a valid json schema"
        )
      end
    end

    context 'when next_indexing_embedding_model is already set' do
      before do
        collection.reload.update_metadata!(
          next_indexing_embedding_model: {
            model_ref: model_ref,
            dimensions: dimensions,
            field: 'embeddings_v1'
          }
        )
      end

      it 'raises InvalidError' do
        expect { service.execute! }.to raise_error(
          described_class::InvalidError, /next_indexing_embedding_model is already set/
        )
      end

      it 'does not update collection metadata' do
        expect(collection).not_to receive(:update_metadata!)
        expect { service.execute! }.to raise_error(described_class::InvalidError)
      end

      it 'does not create task chain' do
        expect { service.execute! }.to raise_error(described_class::InvalidError)
        expect(task_service).not_to have_received(:create_chain)
      end
    end

    context 'when collection_record is blank' do
      before do
        allow(Ai::ActiveContext::Collections::Code).to receive(:collection_record).and_return(nil)
      end

      it 'raises InvalidError' do
        expect { service.execute! }.to raise_error(described_class::InvalidError, /collection_record not found/)
      end
    end

    context 'when the update params are exactly the same as the current model' do
      let(:current_model_type) { model_type }
      let(:current_model_ref) { model_ref }
      let(:current_dimensions) { dimensions }

      before do
        collection.reload.update_metadata!(
          current_indexing_embedding_model: {
            model_type: current_model_type,
            model_ref: current_model_ref,
            dimensions: dimensions,
            field: 'embeddings_v1'
          }
        )
      end

      it_behaves_like 'fails pre-flight checks' do
        let(:expected_error_message) { 'the given model metadata is the same as the current model' }
      end

      context 'when model_type is present' do
        let(:model_type) { 'gitlab_managed' }

        it_behaves_like 'fails pre-flight checks' do
          let(:expected_error_message) { 'the given model metadata is the same as the current model' }
        end
      end
    end

    context 'when task chain creation fails' do
      before do
        allow(Ai::ActiveContext::TaskService).to receive(:new).and_call_original
        allow(Ai::ActiveContext::Task).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'raises and UpdateFailed error and reverts the model metadata update' do
        expect(collection.reload.next_indexing_embedding_model).to be_nil
        expect(collection).to receive(:update_metadata!).with(
          next_indexing_embedding_model: {
            'model_type' => model_type,
            'model_ref' => model_ref,
            'field' => expected_field_name,
            'dimensions' => dimensions
          }
        )

        expect { service.execute! }.to raise_error(
          described_class::UpdateFailed, 'Record invalid'
        )

        expect(collection.reload.next_indexing_embedding_model).to be_nil
      end
    end

    context 'when embeddings request test fails' do
      let(:test_model_response) { ServiceResponse.error(message: 'some error') }

      it 'raises InvalidError and does not update the embedding model' do
        expect { service.execute! }.to raise_error(
          described_class::InvalidError,
          "test embeddings request failed: some error"
        ).and not_change { collection.reload.next_indexing_embedding_model }
      end
    end

    context 'when embeddings request testing is skipped' do
      subject(:service) do
        described_class.new(
          collection_class: Ai::ActiveContext::Collections::Code,
          model_ref: model_ref,
          dimensions: dimensions,
          model_type: model_type,
          skip_embeddings_request_test: true
        )
      end

      it 'does not perform embeddings request testing' do
        expect(Ai::ActiveContext::TestEmbeddingModelService).not_to receive(:new)

        service.execute!

        expect(collection.reload.next_indexing_embedding_model.symbolize_keys).to include(
          model_type: model_type,
          model_ref: model_ref,
          dimensions: dimensions
        )
      end
    end

    context 'for user model selection' do
      before do
        allow(Ai::ActiveContext).to receive(:gitlab_selects_embedding_model?).and_return(false)
      end

      context 'when user is not given' do
        let(:user) { nil }

        it_behaves_like 'fails pre-flight checks' do
          let(:expected_error_message) { "user is required for user model selection" }
        end
      end

      context 'when user is given' do
        let_it_be(:user) { create(:user) }

        context 'when model_type is not given' do
          let(:model_type) { nil }

          it_behaves_like 'fails pre-flight checks' do
            let(:expected_error_message) { "model_type is required for user model selection" }
          end
        end

        context 'when model_type=gitlab_managed' do
          let(:model_type) { 'gitlab_managed' }

          context 'when unsupported model_ref is provided' do
            let(:model_ref) { 'test_model_001' }

            it_behaves_like 'fails pre-flight checks' do
              let(:expected_error_message) { "the given model 'test_model_001' is not offered by GitLab" }
            end
          end

          context 'when supported model_ref is provided' do
            let(:model_ref) { 'text_embedding_005_vertex' }

            context 'when testing terms were not accepted' do
              before do
                allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
              end

              it_behaves_like 'fails pre-flight checks' do
                let(:expected_error_message) do
                  'this AI feature is in BETA, please turn on self-hosted beta models and features'
                end
              end
            end

            context 'when testing terms were accepted' do
              before do
                allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
              end

              it_behaves_like 'successfully tests and updates the collection model'

              it_behaves_like 'initiates model switching with feature settings sync'
            end
          end
        end

        context 'when model_type=self_hosted' do
          let(:model_type) { 'self_hosted' }
          let(:model_ref) { self_hosted_embedding_model.id.to_s }

          context 'when a non-embedding self-hosted model is provided' do
            let_it_be(:self_hosted_general_model) do
              create(:ai_self_hosted_model, :general, name: 'General Model')
            end

            let(:model_ref) { self_hosted_general_model.id.to_s }

            it_behaves_like 'fails pre-flight checks' do
              let(:expected_error_message) do
                "Self-hosted embedding model with ID '#{self_hosted_general_model.id}' cannot be found, " \
                  "please ensure it is an existing embedding model and " \
                  "turn on self-hosted beta models and features"
              end
            end
          end

          context 'when the provided model_ref is not for a self-hosted model' do
            let(:model_ref) { 'text_embedding_005_vertex' }

            it_behaves_like 'fails pre-flight checks' do
              let(:expected_error_message) do
                "Self-hosted embedding model with ID 'text_embedding_005_vertex' cannot be found, " \
                  "please ensure it is an existing embedding model and " \
                  "turn on self-hosted beta models and features"
              end
            end
          end

          context 'with an embedding self-hosted model' do
            let_it_be(:self_hosted_embedding_model) do
              create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 1')
            end

            context 'when testing terms were not accepted' do
              before do
                allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
              end

              it_behaves_like 'fails pre-flight checks' do
                let(:expected_error_message) do
                  "Self-hosted embedding model with ID '#{self_hosted_embedding_model.id}' cannot be found, " \
                    "please ensure it is an existing embedding model and " \
                    "turn on self-hosted beta models and features"
                end
              end
            end

            context 'when testing terms were accepted' do
              before do
                allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
              end

              it_behaves_like 'successfully tests and updates the collection model'

              it_behaves_like 'initiates model switching with feature settings sync'
            end
          end
        end

        context 'when unsupported model_type is provided' do
          let(:model_type) { 'some_type' }

          context 'when testing terms were not accepted' do
            before do
              allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
            end

            it_behaves_like 'fails pre-flight checks' do
              let(:expected_error_message) do
                'this AI feature is in BETA, please turn on self-hosted beta models and features'
              end
            end
          end

          context 'when testing terms were accepted' do
            before do
              allow(Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
            end

            it 'raises UpdateFailed and does not update the embedding model' do
              expect { service.execute! }.to raise_error(
                described_class::UpdateFailed,
                "Ai::ActiveContext::Collection - Validation failed: " \
                  "Metadata must be a valid json schema"
              ).and not_change { collection.reload.next_indexing_embedding_model }
            end
          end
        end
      end
    end

    describe 'setting chunk strategy' do
      shared_examples 'fails chunk strategy update' do
        it 'does not update chunk strategy and raises an UpdateFailed' do
          expect { service.execute! }.to raise_error(
            described_class::UpdateFailed, expected_error_message
          )

          collection.reload
          expect(collection.chunk_strategy).to be_nil
          expect(collection.chunk_strategy_size).to be_nil

          expect(collection.next_indexing_embedding_model).to be_nil
          expect(task_service).not_to have_received(:create_chain)
        end
      end

      subject(:service) do
        described_class.new(
          collection_class: Ai::ActiveContext::Collections::Code,
          model_ref: model_ref,
          dimensions: dimensions,
          model_type: model_type,
          chunk_strategy: chunk_strategy,
          chunk_strategy_size: chunk_strategy_size
        )
      end

      before do
        # Call update! directly to bypass the update_options! immutability guard
        collection.update!(
          options: collection.options.merge(
            chunk_strategy: nil,
            chunk_strategy_size: nil
          )
        )
      end

      context 'when chunk_strategy and chunk_strategy_size are provided' do
        let(:chunk_strategy) { 'code_pre_bert' }
        let(:chunk_strategy_size) { 500 }

        it 'updates the collection options with chunk strategy' do
          service.execute!

          collection.reload
          expect(collection.options.symbolize_keys).to include(
            chunk_strategy: chunk_strategy,
            chunk_strategy_size: chunk_strategy_size
          )

          expect(collection.next_indexing_embedding_model).not_to be_nil
          expect(task_service).to have_received(:create_chain)
        end
      end

      context 'when only chunk_strategy is provided without chunk_strategy_size' do
        let(:chunk_strategy) { 'code_pre_bert' }
        let(:chunk_strategy_size) { nil }

        it_behaves_like 'fails chunk strategy update' do
          let(:expected_error_message) { /Chunk strategy size can't be blank/ }
        end
      end

      context 'when only chunk_strategy_size is provided without chunk_strategy' do
        let(:chunk_strategy) { nil }
        let(:chunk_strategy_size) { 500 }

        it_behaves_like 'fails chunk strategy update' do
          let(:expected_error_message) { /Chunk strategy can't be blank/ }
        end
      end

      context 'when current model has been set' do
        before do
          collection.update_metadata!(
            current_indexing_embedding_model:
            {
              model_type: 'gitlab_managed',
              model_ref: 'embedding_model_001_test',
              field: 'embeddings_v1',
              dimensions: 1024
            }
          )
        end

        let(:chunk_strategy) { 'code_pre_bert' }
        let(:chunk_strategy_size) { 500 }

        it_behaves_like 'fails chunk strategy update' do
          let(:expected_error_message) { /chunking strategy can only be set when there is no current model/ }
        end
      end

      context 'when chunk_strategy and chunk_strategy_size are nil' do
        let(:chunk_strategy) { nil }
        let(:chunk_strategy_size) { nil }

        it 'does not update chunk strategy' do
          service.execute!

          collection.reload
          expect(collection.chunk_strategy).to be_nil
          expect(collection.chunk_strategy_size).to be_nil

          expect(collection.next_indexing_embedding_model).not_to be_nil
          expect(task_service).to have_received(:create_chain)
        end
      end
    end
  end
end

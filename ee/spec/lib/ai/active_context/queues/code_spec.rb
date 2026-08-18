# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queues::Code, feature_category: :code_suggestions do
  before do
    allow(::ActiveContext).to receive_message_chain(:adapter, :full_collection_name)
      .and_return(ActiveContextHelpers.code_collection_name)
  end

  describe 'queue processing properties' do
    shared_examples 'has single shard' do
      it 'forces number_of_shards to 1' do
        expect(described_class.number_of_shards).to eq(1)
      end
    end

    shared_examples 'calculates the shard_limit from the default batch_size' do
      it 'calculates the shard_limit from the batch_size and embeddings rpm' do
        expect(described_class.shard_limit).to eq(
          described_class::TARGET_RPM_FOR_LIMITED_THROUGHPUT *
          Ai::ActiveContext::Embedding::DEFAULT_EMBEDDINGS_REQUEST_BATCH_SIZE
        )
      end
    end

    before do
      allow(described_class).to receive(:limit_throughput?).and_return(false)

      allow(Ai::ActiveContext::Embedding).to receive(:embeddings_request_batch_size).and_call_original
    end

    it 'returns default values' do
      expect(described_class.number_of_shards).to eq(1)
      expect(described_class.shard_limit).to eq(1000)
    end

    context 'when throughput is limited' do
      before do
        allow(described_class).to receive(:limit_throughput?).and_return(true)
      end

      it_behaves_like 'calculates the shard_limit from the default batch_size'
    end

    context 'when a Code collection record exists' do
      let_it_be_with_reload(:collection) { create(:ai_active_context_collection, :code_collection) }

      it 'returns default values' do
        expect(described_class.number_of_shards).to eq(1)
        expect(described_class.shard_limit).to eq(1000)
      end

      context 'when the collection queue-related options are set' do
        before do
          collection.update!(
            options: {
              queue_shard_count: 4,
              queue_shard_limit: configured_shard_limit
            }
          )
        end

        let(:configured_shard_limit) { 999 }

        it 'returns the values defined in the collection options' do
          expect(described_class.number_of_shards).to eq(4)
          expect(described_class.shard_limit).to eq(configured_shard_limit)
        end

        context 'when throughput is limited' do
          before do
            allow(described_class).to receive(:limit_throughput?).and_return(true)
          end

          it_behaves_like 'has single shard'

          it_behaves_like 'calculates the shard_limit from the default batch_size'

          context 'when the configured shard_limit is less than the calculated shard_limit' do
            let(:configured_shard_limit) { 10 }

            it 'uses the configured shard_limit' do
              expect(described_class.shard_limit).to eq(configured_shard_limit)
            end
          end

          context 'when the configured model has a custom batch size' do
            before do
              collection.update_metadata!(
                current_indexing_embedding_model: {
                  model_ref: 'model_1',
                  field: 'field_1',
                  embeddings_request_batch_size: model_batch_size
                }
              )
            end

            let(:model_batch_size) { 15 }

            it 'calculates the shard_limit from the metadata batch_size and embeddings rpm' do
              expect(described_class.shard_limit).to eq(
                described_class::TARGET_RPM_FOR_LIMITED_THROUGHPUT * model_batch_size
              )
            end
          end
        end
      end
    end
  end

  describe '.limit_throughput?' do
    subject(:limit_throughput) { described_class.limit_throughput? }

    context 'on saas instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
      end

      it { is_expected.to be false }
    end

    context 'on dedicated instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it { is_expected.to be false }
    end

    context 'on self-managed instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        allow(::Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
      end

      it { is_expected.to be false }

      context 'when the current_indexing_embedding_model is set' do
        before do
          allow(described_class::COLLECTION_CLASS).to receive(:current_indexing_embedding_model)
            .and_return(current_indexing_embedding_model)
        end

        let(:current_indexing_embedding_model) do
          ActiveContext::EmbeddingModel.new(
            field: :test_embeddings,
            model_ref: 'text_embedding_005_vertex',
            model_type: :gitlab_managed,
            llm_class: ::Gitlab::Llm::Embeddings::CodeEmbeddings,
            llm_params: llm_params
          )
        end

        context 'when llm_params is nil' do
          let(:llm_params) { nil }

          it { is_expected.to be false }
        end

        context 'when llm_params[:model_definition] is nil' do
          let(:llm_params) { { model_definition: nil } }

          it { is_expected.to be false }
        end

        context 'when llm_params[:model_definition] is set with a NON-gitlab-managed model' do
          let(:llm_params) do
            { model_definition: instance_double(::Gitlab::Llm::Embeddings::ModelDefinition, gitlab_managed?: false) }
          end

          it { is_expected.to be false }
        end

        context 'when llm_params[:model_definition] is set with a gitlab-managed model' do
          let(:llm_params) do
            { model_definition: instance_double(::Gitlab::Llm::Embeddings::ModelDefinition, gitlab_managed?: true) }
          end

          it { is_expected.to be false }
        end
      end
    end
  end

  describe '.preprocess_options' do
    it 'returns a hash with queue_name' do
      expect(described_class.preprocess_options).to eq({
        queue_name: 'code'
      })
    end
  end

  describe '.queues' do
    it 'includes the code queue' do
      expect(ActiveContext::Queues.queues).to include('ai_activecontext_queues:{code}')
    end
  end
end

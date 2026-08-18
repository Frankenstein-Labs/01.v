# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::SemanticSearchEmbeddingsHelper, :aggregate_failures, feature_category: :global_search do
  describe '.collection_name' do
    it 'titleizes the collection name', :aggregate_failures do
      expect(helper.collection_name(:code)).to eq("Code")
      expect(helper.collection_name(:merge_request)).to eq("Merge Request")
    end
  end

  describe '.embedding_model_display_name' do
    let(:dimensions) { 32 }
    let(:model_name) { 'Some Model - Vertex' }

    let(:model_metadata) do
      {
        model_type: :gitlab_managed,
        model_ref: 'some_model_vertex',
        dimensions: dimensions,
        model_name: model_name
      }
    end

    it 'returns the full display name' do
      expect(helper.embedding_model_display_name(model_metadata)).to eq(
        "Gitlab-managed | Some Model - Vertex | 32"
      )
    end

    context 'when model_metadata[:model_name] is nil' do
      let(:model_name) { nil }

      it "displays 'Unknown model'" do
        expect(helper.embedding_model_display_name(model_metadata)).to eq("Gitlab-managed | Unknown model | 32")
      end
    end

    context "when dimensions is nil" do
      let(:dimensions) { nil }

      it 'does not show the dimensions' do
        expect(helper.embedding_model_display_name(model_metadata)).to eq(
          "Gitlab-managed | Some Model - Vertex"
        )
      end
    end
  end

  describe '.embedding_models_grouped_options' do
    let(:current_model) { { model_type: :gitlab_managed, model_ref: 'text_embedding_005_vertex' } }
    let(:self_hosted_embedding_models) { [] }

    subject(:embedding_models_grouped_options) do
      helper.embedding_models_grouped_options(current_model, self_hosted_embedding_models)
    end

    it 'includes Gitlab-managed models sorted alphabetically' do
      expect(embedding_models_grouped_options).to eq(
        [
          [
            'Gitlab-managed',
            [
              ['embedding-model-001 - TEST', 'gitlab_managed__embedding_model_001_test'],
              ['text-embedding-005 - Vertex', 'gitlab_managed__text_embedding_005_vertex']
            ]
          ]
        ]
      )
    end

    context 'when there are Self-hosted embedding models' do
      let(:self_hosted_embedding_model_1) do
        build(:ai_self_hosted_model, :embedding, id: 1, name: 'Embedding Model B', identifier: 'some-model-b')
      end

      let(:self_hosted_embedding_model_2) do
        build(:ai_self_hosted_model, :embedding, id: 2, name: 'Embedding Model A', identifier: 'some-model-a')
      end

      let(:self_hosted_embedding_models) { [self_hosted_embedding_model_1, self_hosted_embedding_model_2] }

      it 'includes Gitlab-managed and Self-hosted models sorted alphabetically' do
        expect(embedding_models_grouped_options).to eq(
          [
            [
              'Gitlab-managed',
              [
                ['embedding-model-001 - TEST', 'gitlab_managed__embedding_model_001_test'],
                ['text-embedding-005 - Vertex', 'gitlab_managed__text_embedding_005_vertex']
              ]
            ],
            [
              'Self-hosted',
              [
                ['Embedding Model A', "self_hosted__2"],
                ['Embedding Model B', "self_hosted__1"]
              ]
            ]
          ]
        )
      end
    end

    context 'when current_model is nil' do
      let(:current_model) { nil }

      it "includes 'No model selected' option at the beginning" do
        expect(embedding_models_grouped_options.first).to eq(
          [
            'No model selected',
            [["--", nil]]
          ]
        )
      end
    end
  end

  describe '.embedding_model_key' do
    it 'returns nil if model_metadata is blank', :aggregate_failures do
      expect(helper.embedding_model_key(nil)).to be_nil
      expect(helper.embedding_model_key({})).to be_nil
    end

    it 'builds from the model_type and model_ref' do
      model_metadata = { model_type: :gitlab_managed, model_ref: 'test_model_001' }
      expect(helper.embedding_model_key(model_metadata)).to eq("gitlab_managed__test_model_001")
    end
  end

  describe '.embedding_model_dimensions' do
    it 'returns nil if model_metadata is blank', :aggregate_failures do
      expect(helper.embedding_model_dimensions(nil)).to be_nil
      expect(helper.embedding_model_dimensions({})).to be_nil
    end

    it 'returns the model dimensions if present', :aggregate_failures do
      expect(helper.embedding_model_dimensions({ dimensions: 2 })).to eq(2)
      expect(helper.embedding_model_dimensions({ model_type: :gitlab_managed })).to be_nil
    end
  end

  describe '.chunk_strategy_options' do
    it 'returns all supported chunk strategies as options' do
      expect(helper.chunk_strategy_options).to eq(
        [
          ['Code Bytes', 'code_bytes'],
          ['Code Pre Bert', 'code_pre_bert']
        ]
      )
    end
  end

  describe '.chunking_strategy_display' do
    it 'returns the formatted chunking strategy and size' do
      expect(helper.chunking_strategy_display('code_pre_bert', 240)).to eq('Code Pre Bert | 240')
      expect(helper.chunking_strategy_display(:code_pre_bert, 240)).to eq('Code Pre Bert | 240')
    end

    it 'returns only the strategy if size is blank' do
      expect(helper.chunking_strategy_display('code_bytes', nil)).to eq('Code Bytes')
      expect(helper.chunking_strategy_display('code_pre_bert', '')).to eq('Code Pre Bert')
    end

    it 'returns default values if strategy is blank regardless of size' do
      expect(helper.chunking_strategy_display(nil, 1000)).to eq('Code Bytes | 1000')
      expect(helper.chunking_strategy_display('', 240)).to eq('Code Bytes | 1000')
      expect(helper.chunking_strategy_display(nil, nil)).to eq('Code Bytes | 1000')
    end
  end
end

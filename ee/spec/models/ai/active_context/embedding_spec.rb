# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Embedding, :aggregate_failures, feature_category: :global_search do
  let_it_be(:model_metadata_validation_schema) do
    file_path = Rails.root.join('ee/app/validators/json_schemas/ai_active_context_embedding_metadata.json')
    Gitlab::Json.safe_parse(File.read(file_path))
  end

  let_it_be(:collection_options_validation_schema) do
    file_path = Rails.root.join('ee/app/validators/json_schemas/ai_active_context_collection_options.json')
    Gitlab::Json.safe_parse(File.read(file_path))
  end

  let(:supported_model_types) { [:gitlab_managed, :self_hosted] }
  let(:schema_model_types) do
    model_metadata_validation_schema['properties']['model_type']['enum'].compact.map(&:to_sym)
  end

  let(:schema_chunk_strategies) do
    collection_options_validation_schema['properties']['chunk_strategy']['enum'].compact.map(&:to_sym)
  end

  it 'defines all supported model types and matches the model metadata validation schema' do
    defined_model_types = described_class::MODEL_TYPES

    expect(defined_model_types).to match_array(supported_model_types)
    expect(defined_model_types).to match_array(schema_model_types)
  end

  it 'defines all supported chunk strategies and matches the collection options validation schema' do
    defined_chunk_strategies = described_class::CHUNK_STRATEGIES

    expect(defined_chunk_strategies).to match_array([:code_bytes, :code_pre_bert])
    expect(defined_chunk_strategies).to match_array(schema_chunk_strategies)
  end

  describe '.mapped_feature_setting' do
    it "returns the collection's mapped feature setting" do
      expect(described_class.mapped_feature_setting(:code)).to eq('embeddings_code')
      expect(described_class.mapped_feature_setting('code')).to eq('embeddings_code')
    end

    it 'returns nil for unmapped collection names' do
      expect(described_class.mapped_feature_setting(:unknown)).to be_nil
      expect(described_class.mapped_feature_setting('unknown')).to be_nil
    end
  end

  describe '.has_mapped_feature_setting?' do
    it 'returns true for collections with mapped feature settings' do
      expect(described_class.has_mapped_feature_setting?(:code)).to be(true)
      expect(described_class.has_mapped_feature_setting?('code')).to be(true)
    end

    it 'returns false for unmapped collection names' do
      expect(described_class.has_mapped_feature_setting?(:unknown)).to be(false)
      expect(described_class.has_mapped_feature_setting?('unknown')).to be(false)
    end
  end

  describe '.feature_setting_allowed?' do
    context 'for code collection' do
      context 'when testing terms were accepted' do
        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
        end

        it 'returns true' do
          expect(described_class.feature_setting_allowed?(:code)).to be(true)
          expect(described_class.feature_setting_allowed?('code')).to be(true)
        end
      end

      context 'when testing terms were not accepted' do
        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
        end

        it 'returns false' do
          expect(described_class.feature_setting_allowed?(:code)).to be(false)
          expect(described_class.feature_setting_allowed?('code')).to be(false)
        end
      end
    end

    context 'for unknown collection' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
      end

      it 'returns false' do
        expect(described_class.feature_setting_allowed?(:unknown)).to be(false)
        expect(described_class.feature_setting_allowed?('unknown')).to be(false)
      end
    end
  end

  describe '.gitlab_managed_models_lookup' do
    let(:actual_models) { ['text_embedding_005_vertex'] }
    let(:test_models) { ['embedding_model_001_test'] }
    let(:actual_and_test_models) { actual_models + test_models }

    subject(:gitlab_managed_models_lookup) { described_class.gitlab_managed_models_lookup }

    it 'returns the actual and test supported models with a name for each model' do
      expect(gitlab_managed_models_lookup.keys).to match_array(actual_and_test_models)
      expect(gitlab_managed_models_lookup).to all(satisfy { |_k, m| m[:model_name].present? })
    end

    context 'when not in dev or test environment' do
      before do
        allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
      end

      it 'returns only the actual supported models' do
        expect(gitlab_managed_models_lookup.keys).to match_array(actual_models)
      end
    end
  end

  describe '.self_hosted_models' do
    let_it_be(:self_hosted_embedding_model_1) do
      create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 1', identifier: 'embedding-1')
    end

    let_it_be(:self_hosted_embedding_model_2) do
      create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 2', identifier: 'embedding-2')
    end

    let_it_be(:self_hosted_general_model) do
      create(:ai_self_hosted_model, :general, name: 'General Model')
    end

    context 'when testing terms have been accepted' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
      end

      it 'returns self-hosted embedding models' do
        expect(described_class.self_hosted_models).to match_array(
          [self_hosted_embedding_model_1, self_hosted_embedding_model_2]
        )
      end
    end

    context 'when testing terms have not been accepted' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
      end

      it 'returns an empty list' do
        expect(described_class.self_hosted_models).to be_empty
      end
    end
  end

  describe '.attach_model_name' do
    let(:model_metadata) do
      {
        model_type: model_type,
        model_ref: model_ref
      }
    end

    subject(:model_metadata_with_name) { described_class.attach_model_name(model_metadata) }

    context 'when model_type=:gitlab_managed' do
      let(:model_type) { :gitlab_managed }

      context 'if model_ref is in the gitlab-managed models lookup' do
        let(:model_ref) { 'text_embedding_005_vertex' }

        it 'attaches the gitlab-managed model name' do
          expect(model_metadata_with_name).to eq(
            model_metadata.merge(model_name: 'text-embedding-005 - Vertex')
          )
        end
      end

      context 'if model_ref is not in the lookup' do
        let(:model_ref) { 'some-model' }

        it 'attaches a nil model name' do
          expect(model_metadata_with_name).to eq(model_metadata.merge(model_name: nil))
        end
      end
    end

    context 'when model_type=:self_hosted' do
      let(:model_type) { :self_hosted }

      let_it_be(:self_hosted_embedding_model) do
        create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 1', identifier: 'embedding-1')
      end

      context 'if self-hosted model exists' do
        let(:model_ref) { self_hosted_embedding_model.id.to_s }

        it 'attaches the self-hosted model name' do
          expect(model_metadata_with_name).to eq(
            model_metadata.merge(model_name: 'Embedding Model 1')
          )
        end
      end

      context 'if the self-hosted model does not exist' do
        let(:model_ref) { non_existing_record_id.to_s }

        it 'attaches a nil model name' do
          expect(model_metadata_with_name).to eq(model_metadata.merge(model_name: nil))
        end
      end
    end

    context 'when model_type is nil' do
      let(:model_type) { nil }
      let(:model_ref) { 'text_embedding_005_vertex' }

      it 'follows the gitlab-managed model behavior', :aggregate_failures do
        expect(model_metadata_with_name).to eq(
          model_metadata.merge(model_name: 'text-embedding-005 - Vertex')
        )
      end
    end

    context 'when model_metadata is nil' do
      let(:model_metadata) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe '.embeddings_request_batch_size' do
    using RSpec::Parameterized::TableSyntax

    subject(:batch_size) do
      described_class.embeddings_request_batch_size(model_metadata)
    end

    context 'when model_metadata is nil or empty' do
      where(:model_metadata) { [nil, {}] }

      with_them do
        it 'returns the generic default batch size' do
          expect(batch_size).to eq(30)
        end
      end
    end

    context 'when embeddings_request_batch_size is nil or invalid' do
      where(:configured_batch_size) { [nil, 0, 'str'] }

      with_them do
        where(:model_ref, :model_type, :expected_batch_size) do
          'text_embedding_005_vertex' | nil              | 30
          'text_embedding_005_vertex' | :gitlab_managed  | 30
          'embedding_model_001_test'  | :gitlab_managed  | 100
          'dummy_model_ref'           | :gitlab_managed  | 30
          '1'                         | :self_hosted     | 30
        end

        with_them do
          let(:model_metadata) do
            {
              model_ref: model_ref,
              model_type: model_type,
              embeddings_request_batch_size: configured_batch_size
            }
          end

          it 'returns the default batch size' do
            expect(batch_size).to eq(expected_batch_size)
          end
        end
      end
    end

    context 'when the embeddings_request_batch_size is present and greater than zero' do
      context 'for self-hosted models' do
        where(:configured_batch_size) { ['12', 12, 123] }

        with_them do
          let(:model_metadata) do
            {
              model_type: :self_hosted,
              model_ref: '1',
              embeddings_request_batch_size: configured_batch_size
            }
          end

          it 'returns the configured batch size' do
            expect(batch_size).to eq(configured_batch_size.to_i)
          end
        end
      end

      context 'for gitlab-managed models' do
        where(:model_type, :model_ref, :configured_batch_size, :expected_batch_size) do
          nil             | 'text_embedding_005_vertex' | '12' | 12
          :gitlab_managed | 'text_embedding_005_vertex' | 12   | 12
          :gitlab_managed | 'text_embedding_005_vertex' | 123  | 30
          :gitlab_managed | 'embedding_model_001_test'  | 123  | 100
          :gitlab_managed | 'dummy_model_ref'           | 123  | 30
        end

        with_them do
          let(:model_metadata) do
            {
              model_type: model_type,
              model_ref: model_ref,
              embeddings_request_batch_size: configured_batch_size
            }
          end

          it 'returns the correct batch size' do
            expect(batch_size).to eq(expected_batch_size)
          end
        end
      end
    end
  end

  describe '.valid_model_ref?' do
    context 'for gitlab-managed model type' do
      it 'validates against the actual and test supported models' do
        expect(described_class.valid_model_ref?('text_embedding_005_vertex')).to be(true)
        expect(described_class.valid_model_ref?('embedding_model_001_test')).to be(true)
        expect(described_class.valid_model_ref?('test_model_1')).to be(false)

        expect(described_class.valid_model_ref?('text_embedding_005_vertex', model_type: :gitlab_managed)).to be(true)
        expect(described_class.valid_model_ref?('embedding_model_001_test', model_type: :gitlab_managed)).to be(true)
        expect(described_class.valid_model_ref?('test_model_1', model_type: :gitlab_managed)).to be(false)
      end

      context 'when not in dev or test environment' do
        before do
          allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
        end

        it 'validates against the actual supported models' do
          expect(described_class.valid_model_ref?('text_embedding_005_vertex')).to be(true)
          expect(described_class.valid_model_ref?('embedding_model_001_test')).to be(false)
          expect(described_class.valid_model_ref?('test_model_1')).to be(false)
        end
      end
    end

    context 'for self-hosted model type' do
      let_it_be(:embedding_model) { create(:ai_self_hosted_model, :embedding, name: 'Embedding Model 1') }
      let_it_be(:general_model) { create(:ai_self_hosted_model, :general, name: 'General Model') }

      subject(:valid_model_ref) do
        described_class.valid_model_ref?(self_hosted_model_id, model_type: :self_hosted)
      end

      context 'when given self-hosted model is present and an embedding model' do
        let(:self_hosted_model_id) { embedding_model.id }

        context 'when testing terms have not been accepted' do
          before do
            allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
          end

          it { is_expected.to be(false) }
        end

        context 'when testing terms have been accepted' do
          before do
            allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
          end

          it { is_expected.to be(true) }
        end
      end

      context 'when given self-hosted model is present but NOT an embedding model' do
        let(:self_hosted_model_id) { general_model.id }

        it { is_expected.to be(false) }
      end

      context 'when given self-hosted model is not present' do
        let(:self_hosted_model_id) { 0 }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '.self_hosted?' do
    it 'returns the expected result' do
      expect(described_class.self_hosted?(nil)).to be(false)
      expect(described_class.self_hosted?(:gitlab_managed)).to be(false)
      expect(described_class.self_hosted?(:self_hosted)).to be(true)
      expect(described_class.self_hosted?('self_hosted')).to be(true)
    end
  end
end

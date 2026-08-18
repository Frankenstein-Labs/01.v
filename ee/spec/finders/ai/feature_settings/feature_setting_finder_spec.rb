# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSettings::FeatureSettingFinder,
  feature_category: :"self-hosted_models" do
  let_it_be(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1,
      duo_chat: 2,
      duo_agent_platform: 3,
      duo_agent_platform_agentic_chat: 4,
      embeddings_code: 5
    }
  end

  let_it_be(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'model_name', model: :mistral)
  end

  let_it_be(:existing_feature_setting) do
    create(:ai_feature_setting,
      self_hosted_model: self_hosted_model,
      feature: :duo_chat,
      provider: :self_hosted
    )
  end

  before do
    allow(::Ai::FeatureSetting).to receive(:allowed_features).and_return(test_ai_feature_enum)
  end

  subject(:execute_finder) { described_class.new(**args).execute }

  describe '#execute' do
    context 'when no argument is provided' do
      let(:args) { {} }

      let(:expected_dap_results) do
        [:duo_agent_platform, :duo_agent_platform_agentic_chat].map do |feature|
          ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)
        end
      end

      let(:expected_classic_results) do
        [:code_generations, :code_completions, :duo_chat].map do |feature|
          ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)
        end
      end

      let(:expected_semantic_search_results) do
        [:embeddings_code].map do |feature|
          ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)
        end
      end

      it 'returns feature settings grouped by dap, classic, and semantic_search', :aggregate_failures do
        results = execute_finder

        expect(results).to be_a(Hash)
        expect(results.keys).to match_array([:dap, :classic, :semantic_search])

        expected_results = {
          dap: expected_dap_results,
          classic: expected_classic_results,
          semantic_search: expected_semantic_search_results
        }

        [:dap, :classic, :semantic_search].each do |key|
          # Testing attributes because uninitialized instances never have the same ref even with same values
          expect(results[key].map(&:id)).to match_array(expected_results[key].map(&:id))
          expect(results[key].map(&:feature)).to match_array(expected_results[key].map(&:feature))
          expect(results[key].map(&:provider)).to match_array(expected_results[key].map(&:provider))
          expect(results[key].map(&:self_hosted_model)).to match_array(expected_results[key].map(&:self_hosted_model))
        end
      end
    end

    context 'when a self_hosted_model_id argument is provided' do
      let(:args) { { self_hosted_model_id: self_hosted_model } }

      context 'with an existing self-hosted model' do
        it 'returns settings belonging to self-hosted model grouped by scope', :aggregate_failures do
          results = execute_finder

          expect(results).to be_a(Hash)
          expect(results.keys).to match_array([:dap, :classic, :semantic_search])
          expect(results[:dap]).to be_empty
          expect(results[:classic]).to match_array([existing_feature_setting])
          expect(results[:semantic_search]).to be_empty
        end
      end

      context 'with an non-existing self-hosted model' do
        let(:args) { { self_hosted_model_id: non_existing_record_id } }

        it 'returns empty arrays for dap, classic, and semantic_search', :aggregate_failures do
          results = execute_finder

          expect(results).to be_a(Hash)
          expect(results.keys).to match_array([:dap, :classic, :semantic_search])
          expect(results[:dap]).to be_empty
          expect(results[:classic]).to be_empty
          expect(results[:semantic_search]).to be_empty
        end
      end
    end
  end
end

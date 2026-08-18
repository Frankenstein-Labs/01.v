# frozen_string_literal: true

RSpec.shared_context 'with model selection definitions' do
  let(:valid_feature) { :duo_chat }
  let(:valid_model_definitions) do
    {
      "models" => [
        { "name" => "Claude Sonnet 3.7 - Anthropic", "identifier" => "claude-3-7-sonnet-20250219" },
        { "name" => "Claude Sonnet 3.5 - Anthropic", "identifier" => "claude_3_5_sonnet_20240620" }
      ],
      "unit_primitives" => [
        {
          "feature_setting" => "duo_chat",
          "default_model" => "claude-3-7-sonnet-20250219",
          "selectable_models" => %w[claude-3-7-sonnet-20250219 claude_3_5_sonnet_20240620],
          "beta_models" => [],
          "unit_primitives" => %w[ask_build ask_commit]
        }
      ]
    }
  end
end

RSpec.shared_context 'with model selections fetch definition service side-effect context' do
  let(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
        { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude_sonnet_3_7' },
        { 'name' => 'OpenAI Chat GPT 4o', 'identifier' => 'openai_chatgpt_4o' },
        { 'name' => 'Claude Sonnet 4.0', 'identifier' => 'claude_sonnet_4_20250514' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'code_completions',
          'default_model' => 'claude_sonnet_3_5',
          'selectable_models' => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
          'beta_models' => []
        },
        {
          'feature_setting' => 'code_generations',
          'default_model' => 'claude_sonnet_3_5',
          'selectable_models' => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
          'beta_models' => []
        },
        {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude_sonnet_3_5',
          'selectable_models' => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
          'beta_models' => []
        },
        {
          'feature_setting' => 'duo_agent_platform',
          'default_model' => 'claude_sonnet_4_20250514',
          'selectable_models' => %w[claude_sonnet_4_20250514 claude_sonnet_3_7],
          'beta_models' => []
        },
        {
          'feature_setting' => 'duo_agent_platform_agentic_chat',
          'default_model' => 'claude_sonnet_4_20250514',
          'selectable_models' => %w[claude_sonnet_4_20250514 claude_sonnet_3_7],
          'beta_models' => []
        }
      ]
    }
  end

  let(:model_definitions_response) { model_definitions.to_json }

  include_context 'with the model selections fetch definition service as side-effect'
end

RSpec.shared_context 'with the model selections fetch definition service as side-effect' do
  let(:base_url) { ::Gitlab::AiGateway.cloud_connector_url }
  let(:fetch_service_endpoint_url) { "#{base_url}/v1/models%2Fdefinitions" }

  before do
    allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |side_effect|
      allow(side_effect).to receive(:model_selection_enabled?).and_return(true)
    end

    allow(::Gitlab::AiGateway).to receive(:url).and_return(base_url)
  end
end

RSpec.shared_examples 'model selection feature setting' do
  context 'when ::Ai::ModelSelection::FeaturesConfigurable is included' do
    it { is_expected.to validate_presence_of(:feature) }

    context 'when required methods are not implemented by including class' do
      let_it_be(:dummy_feature_setting_class, freeze: false) do
        Class.new(ApplicationRecord) do
          include Ai::ModelSelection::FeaturesConfigurable

          self.table_name = "ai_feature_settings"
        end
      end

      before do
        stub_const('DummyModel', dummy_feature_setting_class)
      end

      it '.find_or_initialize_by_feature raises NotImplementedError' do
        expect do
          DummyModel.find_or_initialize_by_feature
        end.to raise_error(NotImplementedError,
          '.find_or_initialize_by_feature method must be implemented for Model Selection logic')
      end
    end

    describe '#provider' do
      it 'returns the MODEL_PROVIDER' do
        expect(ai_feature_setting.provider).to eq(described_class::MODEL_PROVIDER)
      end
    end

    describe '#base_url' do
      let(:url) { "http://localhost:5000" }

      it 'returns Gitlab::AiGateway.url for self hosted features' do
        expect(Gitlab::AiGateway).to receive(:url).and_return(url)

        expect(ai_feature_setting.base_url).to eq(url)
      end
    end

    describe '#self_hosted?' do
      it 'returns false' do
        expect(ai_feature_setting.self_hosted?).to be_falsey
      end
    end

    describe '#disabled?' do
      it 'returns false' do
        expect(ai_feature_setting.disabled?).to be_falsey
      end
    end

    describe '#metadata' do
      it_behaves_like '#metadata is defined for AI configurable features' do
        let(:feature_setting) { ai_feature_setting }
      end

      it 'has the title and main_feature methods delegated to' do
        expect(ai_feature_setting.title).to eq(ai_feature_setting.metadata.title)
        expect(ai_feature_setting.main_feature).to eq(ai_feature_setting.metadata.main_feature)
      end
    end

    describe '.enabled_features_for' do
      let(:all_features) do
        { code_generations: 0, code_completions: 1, summarize_review: 2, review_merge_request: 3 }
      end

      let(:ga_features) do
        { code_generations: 0, code_completions: 1 }
      end

      let(:features_under_flags) do
        {
          summarize_review: 'summarize_my_code_review',
          review_merge_request: 'add_ai_summary_for_new_mr'
        }
      end

      before do
        stub_const('::Ai::ModelSelection::FeaturesConfigurable::FEATURES', all_features)
        stub_const('::Ai::ModelSelection::FeaturesConfigurable::FEATURES_UNDER_FLAGS', features_under_flags)

        ai_feature_setting.namespace.namespace_settings.update!(experiment_features_enabled: true)
      end

      context 'when no features are disabled' do
        before do
          features_under_flags.each_value do |flag|
            stub_feature_flags(flag.to_sym => true)
          end
        end

        context 'when experimental features are enabled' do
          it 'returns all features' do
            enabled_features = described_class.enabled_features_for(ai_feature_setting.namespace)

            expect(enabled_features).to eq(all_features)
          end
        end

        context 'when experimental features are disabled' do
          before do
            ai_feature_setting.namespace.namespace_settings.update!(experiment_features_enabled: false)
          end

          it 'does not return experimental features' do
            enabled_features = described_class.enabled_features_for(ai_feature_setting.namespace)

            expect(enabled_features).to eq(ga_features)
          end
        end
      end

      context 'when a feature is disabled' do
        let(:expected_enabled_features) do
          { code_generations: 0, code_completions: 1, review_merge_request: 3 }
        end

        before do
          stub_feature_flags(summarize_my_code_review: false)
        end

        context 'when experimental features are enabled' do
          it 'does not return the disabled feature' do
            enabled_features = described_class.enabled_features_for(ai_feature_setting.namespace)

            expect(enabled_features).to eq(expected_enabled_features)
          end
        end

        context 'when experimental features are disabled' do
          before do
            ai_feature_setting.namespace.namespace_settings.update!(experiment_features_enabled: false)
          end

          it 'does not return experimental features' do
            enabled_features = described_class.enabled_features_for(ai_feature_setting.namespace)

            expect(enabled_features).to eq(ga_features)
          end
        end
      end

      context 'when all features are disabled' do
        before do
          features_under_flags.each_value do |flag|
            stub_feature_flags(flag.to_sym => false)
          end
        end

        context 'when experimental features are enabled' do
          it 'does not return experimental features' do
            enabled_features = described_class.enabled_features_for(ai_feature_setting.namespace)

            expect(enabled_features).to eq(ga_features)
          end
        end

        context 'when experimental features are disabled' do
          before do
            ai_feature_setting.namespace.namespace_settings.update!(experiment_features_enabled: false)
          end

          it 'does not return experimental features' do
            enabled_features = described_class.enabled_features_for(ai_feature_setting.namespace)

            expect(enabled_features).to eq(ga_features)
          end
        end
      end
    end
  end
end

RSpec.shared_examples '#validate_model_ref_with_definition is called' do
  let(:model_ref) { "claude-3-7-sonnet-20250219" }
  let(:model_definitions) { valid_model_definitions }

  context 'when offered_model_ref is nil' do
    let(:model_ref) { '' }

    it 'does not add any errors' do
      ai_feature_setting.valid?

      expect(ai_feature_setting.errors[:offered_model_ref]).to be_empty
    end
  end

  context 'when model_definitions is empty' do
    let(:model_definitions) { {} }

    it 'adds an error about missing model definitions' do
      ai_feature_setting.valid?

      expect(ai_feature_setting.errors[:feature]).to include("No model definition given for validation")
    end
  end

  context 'when feature is not found in model definitions' do
    let(:model_definitions) do
      {
        "models" => [],
        "unit_primitives" => [
          {
            "feature_setting" => "code_completions",
            "selectable_models" => ["claude-3-7-sonnet-20250219"]
          }
        ]
      }
    end

    it 'adds an error about the feature not found' do
      ai_feature_setting.valid?

      expect(ai_feature_setting.errors[:offered_model_ref]).to include('Feature not found in model definitions')
    end
  end

  context 'when model is not compatible with the feature' do
    let(:model_ref) { "incompatible_model" }

    it 'adds an error about incompatible model' do
      ai_feature_setting.valid?

      expect(ai_feature_setting.errors[:offered_model_ref])
        .to include("Selected model 'incompatible_model' is not compatible with the feature 'duo_chat'")
    end
  end

  context 'when model is compatible with the feature' do
    it 'does not add any errors' do
      ai_feature_setting.valid?

      expect(ai_feature_setting.errors).to be_empty
    end
  end
end

RSpec.shared_examples '#set_model_name is called' do
  let(:model_ref) { "claude-3-7-sonnet-20250219" }
  let(:model_definitions) { valid_model_definitions }
  let(:expected_model_name) { "Claude Sonnet 3.7 - Anthropic" }

  context 'when offered_model_ref has changed' do
    context 'when offered_model_ref is empty' do
      let(:model_ref) { "" }

      it 'sets the offered_model_name to empty string' do
        ai_feature_setting.valid?

        expect(ai_feature_setting.offered_model_name).to eq('')
      end
    end

    context 'when model_definitions is empty' do
      let(:model_definitions) { {} }

      it 'adds an error about missing model definitions' do
        ai_feature_setting.valid?

        expect(ai_feature_setting.errors[:feature]).to include("No model definition given for validation")
      end

      it 'does not set the offered_model_name' do
        expect { ai_feature_setting.valid? }.not_to change { ai_feature_setting.offered_model_name }
      end
    end

    context 'when model reference is not found in definitions' do
      let(:model_ref) { "non_existent_model" }

      it 'adds an error about model reference not found' do
        ai_feature_setting.valid?

        expect(ai_feature_setting.errors[:offered_model_ref]).to include('Model reference not found in definitions')
      end
    end

    context 'when model name is empty in the data' do
      let(:model_definitions) do
        {
          "models" => [
            { "name" => "", "identifier" => "claude-3-7-sonnet-20250219" }
          ],
          "unit_primitives" => [
            {
              "feature_setting" => "duo_chat",
              "selectable_models" => ["claude-3-7-sonnet-20250219"]
            }
          ]
        }
      end

      it 'adds an error about no model name found' do
        ai_feature_setting.valid?

        expect(ai_feature_setting.errors[:offered_model_ref]).to include('No model name found in model data')
      end
    end

    context 'when everything is valid' do
      it 'sets the offered_model_name to the name from the model data' do
        ai_feature_setting.valid?

        expect(ai_feature_setting.offered_model_name).to eq(expected_model_name)
      end
    end
  end

  context 'when offered_model_ref has not changed' do
    it 'does not call set_model_name' do
      expect(ai_feature_setting).to receive(:offered_model_ref_changed?).and_return(false)
      expect(ai_feature_setting).not_to receive(:set_model_name)
      ai_feature_setting.valid?
    end
  end
end

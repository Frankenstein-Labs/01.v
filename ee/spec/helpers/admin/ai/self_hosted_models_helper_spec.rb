# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::Ai::SelfHostedModelsHelper, feature_category: :"self-hosted_models" do
  using RSpec::Parameterized::TableSyntax

  let(:user) { build(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
    allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
  end

  describe '#model_choices_as_options' do
    it 'returns an array of hashes with model options sorted alphabetically' do
      expected_result = [
        { modelValue: "CLAUDE_3", modelName: "Claude", releaseState: "GA" },
        { modelValue: "CODELLAMA", modelName: "Code Llama", releaseState: "BETA" },
        { modelValue: "CODEGEMMA", modelName: "CodeGemma", releaseState: "BETA" },
        { modelValue: "DEEPSEEKCODER", modelName: "DeepSeek Coder", releaseState: "BETA" },
        { modelValue: "EMBEDDING", modelName: "Embedding", releaseState: "BETA" },
        { modelValue: "GPT", modelName: "GPT", releaseState: "GA" },
        { modelValue: "GEMINI", modelName: "Gemini", releaseState: "BETA" },
        { modelValue: "GENERAL", modelName: "General", releaseState: "BETA" },
        { modelValue: "LLAMA3", modelName: "Llama 3", releaseState: "BETA" },
        { modelValue: "MISTRAL", modelName: "Mistral", releaseState: "GA" },
        { modelValue: "CODESTRAL", modelName: "Mistral Codestral", releaseState: "GA" },
        { modelValue: "MIXTRAL", modelName: "Mixtral", releaseState: "GA" },
        { modelValue: "QWEN", modelName: "Qwen", releaseState: "BETA" }
      ]

      expect(helper.model_choices_as_options).to eq(expected_result)
    end

    it 'humanizes the model name when there is no mapped name available' do
      allow(::Ai::SelfHostedModel).to receive(:models).and_return(["unmapped_model"])

      expect(helper.model_choices_as_options).to eq([
        {
          modelValue: "UNMAPPED_MODEL",
          modelName: "Unmapped model",
          releaseState: nil
        }
      ])
    end

    it 'filters out beta models if they are not enabled' do
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)

      expect(helper.model_choices_as_options).to eq([
        { modelValue: "CLAUDE_3", modelName: "Claude", releaseState: "GA" },
        { modelValue: "GPT", modelName: "GPT", releaseState: "GA" },
        { modelValue: "MISTRAL", modelName: "Mistral", releaseState: "GA" },
        { modelValue: "CODESTRAL", modelName: "Mistral Codestral", releaseState: "GA" },
        { modelValue: "MIXTRAL", modelName: "Mixtral", releaseState: "GA" }
      ])
    end
  end

  describe '#can_manage_instance_model_selection?' do
    it 'returns false if ability is not allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_instance_model_selection).and_return(false)
      expect(helper.can_manage_instance_model_selection?).to be(false)
    end

    it 'returns true if ability is allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_instance_model_selection).and_return(true)
      expect(helper.can_manage_instance_model_selection?).to be(true)
    end
  end

  describe '#can_manage_self_hosted_models?' do
    it 'returns false if ability is not allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_self_hosted_models_settings).and_return(false)
      expect(helper.can_manage_self_hosted_models?).to be(false)
    end

    it 'returns true if ability is allowed' do
      allow(Ability).to receive(:allowed?).with(user, :manage_self_hosted_models_settings).and_return(true)
      expect(helper.can_manage_self_hosted_models?).to be(true)
    end
  end

  describe '#can_manage_dap_self_hosted_models?' do
    where(:read_allowed, :update_allowed, :expected_result) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      it 'returns true only when both read and update abilities are allowed' do
        allow(Ability).to receive(:allowed?).with(user, :read_dap_self_hosted_model).and_return(read_allowed)
        allow(Ability).to receive(:allowed?).with(user, :update_dap_self_hosted_model).and_return(update_allowed)
        expect(helper.can_manage_dap_self_hosted_models?).to be(expected_result)
      end
    end
  end

  describe '#instance_model_selection_view_model' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :manage_instance_model_selection).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :manage_self_hosted_models_settings).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_dap_self_hosted_model).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :update_dap_self_hosted_model).and_return(true)
    end

    where(:read_allowed, :update_allowed, :expected_available) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      it 'sets modelSelectionAllowlistAvailable based on read and update abilities' do
        allow(Ability).to receive(:allowed?).with(user, :read_model_selection_allowlist).and_return(read_allowed)
        allow(Ability).to receive(:allowed?).with(user, :update_model_selection_allowlist).and_return(update_allowed)
        expect(helper.instance_model_selection_view_model)
          .to include(modelSelectionAllowlistAvailable: expected_available)
      end
    end
  end

  describe '#beta_models_enabled?' do
    it 'returns true if testing terms have been accepted' do
      expect(helper.beta_models_enabled?).to be(true)
    end

    it 'returns false if testing terms have not been accepted' do
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)

      expect(helper.beta_models_enabled?).to be(false)
    end
  end
end

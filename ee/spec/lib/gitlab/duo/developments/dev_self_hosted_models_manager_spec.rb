# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::DevSelfHostedModelsManager, feature_category: :"self-hosted_models" do
  describe '.seed_models' do
    let_it_be(:user) { create(:user, id: 1) }
    let(:model_names) do
      [
        "Claude Sonnet 3.7 [Bedrock]",
        "Claude Haiku 3.5 [Bedrock]",
        "Claude Sonnet 4 [Bedrock]",
        "Llama 3.3 70b [Bedrock]",
        "Llama 3.1 8b [Bedrock]",
        "Llama 3.1 70b [Bedrock]",
        "Mistral Small [FireworksAI]",
        "Mixtral 8x22b [FireworksAI]",
        "Llama 3.1 70b [FireworksAI]",
        "Llama 3.3 70b [FireworksAI]",
        "Llama 3.1 8b [FireworksAI]",
        "Codestral 22b v0.1 [FireworksAI]",
        "Nomic Embed Text v1.5 [Fireworks AI]"
      ]
    end

    subject(:seed_models) { described_class.seed_models }

    context 'when models do not exist' do
      it 'creates the models' do
        seed_models

        expect(Ai::SelfHostedModel.pluck(:name)).to match_array(model_names)
      end
    end

    context 'when some models already exist' do
      let!(:self_hosted_model) { create(:ai_self_hosted_model, name: "Claude Sonnet 3.7 [Bedrock]") }

      it 'creates only the non-existing models' do
        expect { seed_models }.to change { ::Ai::SelfHostedModel.count }
                                    .from(1)
                                    .to(model_names.size)

        expect(::Ai::SelfHostedModel.where(name: "Claude Sonnet 3.7 [Bedrock]").size).to eq(1)
        expect(Ai::SelfHostedModel.pluck(:name)).to match_array(model_names)
      end
    end
  end

  describe '.list_models' do
    let_it_be(:user) { create(:user, id: 1) }

    before do
      described_class.seed_models
    end

    subject(:list_models) { described_class.list_models }

    it 'lists the models' do
      message = <<~MSG
        The following models are available
        Claude Sonnet 3.7 [Bedrock]
        Claude Haiku 3.5 [Bedrock]
        Claude Sonnet 4 [Bedrock]
        Llama 3.3 70b [Bedrock]
        Llama 3.1 8b [Bedrock]
        Llama 3.1 70b [Bedrock]
        Mistral Small [FireworksAI]
        Mixtral 8x22b [FireworksAI]
        Codestral 22b v0.1 [FireworksAI]
        Llama 3.1 8b [FireworksAI]
        Llama 3.1 70b [FireworksAI]
        Llama 3.3 70b [FireworksAI]
        Nomic Embed Text v1.5 [Fireworks AI]
      MSG

      expect { list_models }.to output(message).to_stdout
    end
  end

  describe '.clean_up_duo_self_hosted' do
    let_it_be(:user) { create(:user, id: 1) }
    let_it_be(:models) { described_class.seed_models }
    let_it_be(:ai_feature_setting) do
      create(
        :ai_feature_setting,
        feature: :code_completions,
        self_hosted_model: ::Ai::SelfHostedModel.first
      )
    end

    subject(:clean_up) { described_class.clean_up_duo_self_hosted }

    it 'removes all models and settings' do
      clean_up

      expect(::Ai::SelfHostedModel.count).to be(0)
      expect(::Ai::FeatureSetting.count).to be(0)
    end
  end
end

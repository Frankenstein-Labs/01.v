# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::SelfHostedModelSelection, feature_category: :duo_agent_platform do
  let(:feature) { :duo_agent_platform_agentic_chat }

  let(:self_hosted_model) do
    build(:ai_self_hosted_model, name: 'My Mistral', identifier: 'mistralai/mistral-7b')
  end

  let(:feature_setting) do
    build(:ai_feature_setting, feature: feature, self_hosted_model: self_hosted_model)
  end

  subject(:model_selection) { described_class.new(feature_setting) }

  it 'does not fetch the cloud model catalog' do
    expect(::Ai::ModelSelection::FetchModelDefinitionsService).not_to receive(:new)

    model_selection.selectable_models
  end

  describe '#selectable_models' do
    it 'returns the self-hosted model as the sole entry' do
      expect(model_selection.selectable_models).to contain_exactly(
        { ref: 'mistralai/mistral-7b', name: 'My Mistral' }
      )
    end
  end

  describe '#default_model' do
    it 'returns the self-hosted model' do
      expect(model_selection.default_model).to eq({ ref: 'mistralai/mistral-7b', name: 'My Mistral' })
    end
  end

  describe '#pinned_model' do
    it 'returns the self-hosted model so clients lock the picker instead of showing a dropdown' do
      expect(model_selection.pinned_model).to eq({ ref: 'mistralai/mistral-7b', name: 'My Mistral' })
    end
  end

  describe '#do_not_consider_user_selected_model?' do
    it 'is true regardless of the requested model', :aggregate_failures do
      expect(model_selection.do_not_consider_user_selected_model?('mistralai/mistral-7b')).to be(true)
      expect(model_selection.do_not_consider_user_selected_model?('claude_sonnet_4_20250514')).to be(true)
    end
  end

  context 'when the identifier is blank' do
    let(:self_hosted_model) do
      build(:ai_self_hosted_model, name: 'Ollama Mistral', identifier: '')
    end

    it 'uses the model enum value as the ref' do
      expect(model_selection.default_model).to eq({ ref: 'mistral', name: 'Ollama Mistral' })
    end
  end
end

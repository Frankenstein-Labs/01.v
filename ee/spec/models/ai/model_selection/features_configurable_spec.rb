# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::FeaturesConfigurable, feature_category: :"self-hosted_models" do
  describe '.agentic_chat_feature_name' do
    it 'returns :duo_agent_platform_agentic_chat' do
      expect(described_class.agentic_chat_feature_name).to eq(:duo_agent_platform_agentic_chat)
    end
  end

  describe '.workflow_feature_name' do
    it 'returns :duo_agent_platform' do
      expect(described_class.workflow_feature_name).to eq(:duo_agent_platform)
    end
  end
end

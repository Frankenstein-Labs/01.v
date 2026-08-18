# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAcceptedSelfHostedModels'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiAcceptedSelfHostedModels') }

  it 'exposes all the curated LLMs for self-hosted feature' do
    expect(described_class.values.keys).to match_array(%w[
      CODEGEMMA
      CODELLAMA
      CODESTRAL
      MISTRAL
      MIXTRAL
      DEEPSEEKCODER
      GENERAL
      LLAMA3
      CLAUDE_3
      GPT
      GEMINI
      EMBEDDING
      QWEN
    ])
  end
end

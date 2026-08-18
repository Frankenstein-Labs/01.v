# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::PromptResolvers::ReviewMergeRequest, feature_category: :duo_code_review do
  describe '.execute' do
    subject(:prompt_version) { described_class.execute }

    before do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(false)
    end

    context 'when amazon_q is enabled' do
      before do
        allow(::Ai::AmazonQ).to receive(:enabled?).and_return(true)
      end

      it 'returns the correct prompt version for Amazon Q' do
        expect(prompt_version).to eq('amazon_q/1.0.0')
      end
    end

    context 'when no specific feature flags are enabled' do
      it 'returns the default prompt version for Claude 4.0 Sonnet' do
        expect(prompt_version).to eq('1.3.0')
      end
    end
  end
end

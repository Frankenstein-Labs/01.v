# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::ResponseModifiers::GitCommand, feature_category: :code_review_workflow do
  subject(:response_modifier) { described_class.new(ai_response) }

  let(:ai_response) { 'foobar' }

  it 'extracts text and format it to expected format of glab' do
    expect(response_modifier.response_body).to eq({
      predictions: [
        candidates: [
          {
            content: ai_response
          }
        ]
      ]
    })
  end

  it 'returns empty errors' do
    expect(response_modifier.errors).to be_empty
  end

  context 'when error is present' do
    let(:ai_response) { { 'detail' => 'error' } }

    it 'returns the error' do
      expect(response_modifier.errors).to eq(['error'])
    end
  end
end

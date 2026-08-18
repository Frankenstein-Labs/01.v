# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiMessageAdditionalContext, feature_category: :duo_chat do
  subject(:message_additional_context) { described_class.new(data) }

  let(:data) do
    [
      {
        category: 'file',
        id: 'additonial_context.rb',
        content: 'puts "additional context"',
        metadata: { 'something' => 'something' }.to_json
      },
      {
        category: 'snippet',
        id: 'print_context_method',
        content: 'def additional_context; puts "context"; end',
        metadata: { 'something' => 'something else' }.to_json
      }
    ]
  end

  describe '#to_a' do
    it 'returns list of hashes with all attributes' do
      expect(message_additional_context.to_a).to eq(data.map(&:stringify_keys))
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiMessageAdditionalContextItem, feature_category: :duo_chat do
  subject(:item) { described_class.new(data) }

  let(:data) do
    {
      category: 'file',
      id: 'additonial_context.rb',
      content: 'puts "additional context"',
      metadata: { 'something' => 'something' }.to_json
    }
  end

  describe '#to_h' do
    it 'returns hash with all attributes' do
      expect(item.to_h).to eq(data.stringify_keys)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiMessageContext, feature_category: :duo_chat do
  subject(:message_context) { described_class.new(data) }

  let(:data) do
    {
      resource: build_stubbed(:user),
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
    }
  end

  let(:timestamp) { 1.year.ago }

  describe '#to_h' do
    it 'returns hash with all attributes' do
      expect(message_context.to_h).to eq(data.stringify_keys)
    end
  end
end

# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Llm::Chain::StreamedAnswer, feature_category: :duo_chat do
  describe '#next_chunk' do
    let(:streamed_answer) { described_class.new }

    context 'when stream is empty' do
      it 'returns nil' do
        expect(streamed_answer.next_chunk("")).to be_nil
      end
    end

    context 'when stream contains a chunk' do
      it 'returns content with incremental chunk ids' do
        expect(streamed_answer.next_chunk("Hello")).to eq({ content: "Hello", id: 1 })
        expect(streamed_answer.next_chunk(" ")).to eq({ content: " ", id: 2 })
        expect(streamed_answer.next_chunk("World")).to eq({ content: "World", id: 3 })
      end
    end
  end
end

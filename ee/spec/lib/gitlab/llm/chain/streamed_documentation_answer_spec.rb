# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Llm::Chain::StreamedDocumentationAnswer, feature_category: :duo_chat do
  describe '#next_chunk' do
    let(:streamed_answer) { described_class.new }

    context 'when stream is empty' do
      it 'returns nil' do
        expect(streamed_answer.next_chunk("")).to be_nil
      end
    end

    context 'when stream contains an answer' do
      it 'returns the content with an incremented id', :aggregate_failures do
        expect(streamed_answer.next_chunk("A")).to eq({ id: 1, content: "A" })
        expect(streamed_answer.next_chunk("fork")).to eq({ id: 2, content: "fork" })
      end
    end

    context 'when receiving sources' do
      it 'no longer returns chunks', :aggregate_failures do
        expect(streamed_answer.next_chunk("A")).to eq({ id: 1, content: "A" })
        expect(streamed_answer.next_chunk("")).to be_nil
        expect(streamed_answer.next_chunk("fork")).to eq({ id: 2, content: "fork" })
        expect(streamed_answer.next_chunk("ATTRS")).to be_nil
        expect(streamed_answer.next_chunk(" ")).to be_nil
        expect(streamed_answer.next_chunk("IDX-123")).to be_nil
      end
    end
  end
end

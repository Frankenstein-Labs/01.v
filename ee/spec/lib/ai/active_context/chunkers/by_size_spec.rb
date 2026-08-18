# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Chunkers::BySize, feature_category: :global_search do
  let(:chunk_size) { 10 }
  let(:overlap) { 2 }
  let(:content) { "This is a test string that needs to be chunked properly" }

  subject(:chunker) { described_class.new(chunk_size: chunk_size, overlap: overlap) }

  before do
    allow(chunker).to receive(:content).and_return(content)
  end

  describe '#chunks' do
    context 'when content is shorter than chunk_size' do
      let(:chunk_size) { 100 }

      it 'returns a single chunk' do
        chunks = chunker.chunks

        expect(chunks.size).to eq(1)
        expect(chunks.first).to eq(content)
      end
    end

    context 'when content is longer than chunk_size' do
      let(:chunk_size) { 10 }
      let(:overlap) { 0 }

      it 'splits content into chunks of the specified size' do
        chunks = chunker.chunks

        expect(chunks.size).to eq(6)
        expect(chunks[0]).to eq("This is a ")
        expect(chunks[1]).to eq("test strin")
        expect(chunks[2]).to eq("g that nee")
        expect(chunks[3]).to eq("ds to be c")
        expect(chunks[4]).to eq("hunked pro")
        expect(chunks[5]).to eq("perly")
      end
    end

    context 'with overlap' do
      let(:chunk_size) { 10 }
      let(:overlap) { 2 }

      it 'creates chunks with the specified overlap' do
        chunks = chunker.chunks

        expect(chunks.size).to eq(7)

        expect(chunks[0]).to eq("This is a ")
        expect(chunks[1]).to eq("a test str")
        expect(chunks[2]).to eq("tring that")
        expect(chunks[3]).to eq("at needs t")
        expect(chunks[4]).to eq(" to be chu")
        expect(chunks[5]).to eq("hunked pro")
        expect(chunks[6]).to eq("roperly")
      end
    end

    context 'with empty content' do
      let(:content) { "" }

      it 'returns an empty array' do
        chunks = chunker.chunks

        expect(chunks).to be_empty
      end
    end

    context 'with nil content' do
      let(:content) { nil }

      before do
        allow(chunker).to receive(:content).and_return(content)
      end

      it 'returns an empty array' do
        chunks = chunker.chunks

        expect(chunks).to be_empty
      end
    end

    context 'when the last chunk is smaller than the chunk size' do
      let(:content) { "123456789" }
      let(:chunk_size) { 5 }
      let(:overlap) { 0 }

      it 'includes the remaining content in the last chunk' do
        chunks = chunker.chunks

        expect(chunks.size).to eq(2)
        expect(chunks[0]).to eq("12345")
        expect(chunks[1]).to eq("6789")
      end
    end
  end
end

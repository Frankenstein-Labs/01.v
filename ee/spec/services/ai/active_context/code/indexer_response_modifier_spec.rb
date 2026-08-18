# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::IndexerResponseModifier, feature_category: :global_search do
  let(:processed_ids) { [] }
  let(:block) { proc { |id| processed_ids << id } }
  let(:modifier) { described_class.new(&block) }

  describe '#process_line' do
    subject(:process_line) { modifier.process_line(line) }

    context 'with valid hash IDs' do
      let(:line) { '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef' }

      it 'calls the block with the hash ID' do
        process_line
        expect(processed_ids).to eq([line])
      end
    end

    context 'with hash IDs containing whitespace' do
      let(:line) { '  1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  ' }

      it 'strips whitespace and calls the block' do
        process_line
        expect(processed_ids).to eq(['1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'])
      end
    end

    context 'with section break' do
      let(:line) { '--section-start--' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with version header' do
      let(:line) { 'version,build_time' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with version data' do
      let(:line) { 'v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with ID section header' do
      let(:line) { 'id' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with empty line' do
      let(:line) { '' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with whitespace-only line' do
      let(:line) { '   ' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with invalid hash (too short)' do
      let(:line) { 'hash123' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with invalid hash (contains non-hex characters)' do
      let(:line) { '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdeg' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end

    context 'with JSON output' do
      let(:line) { '{"time":"2025-06-24T10:02:09.778727+02:00","level":"ERROR","msg":"failed"}' }

      it 'does not call the block' do
        process_line
        expect(processed_ids).to be_empty
      end
    end
  end

  describe 'processing multiple lines' do
    it 'processes a complete indexer output stream' do
      lines = [
        '--section-start--',
        'version,build_time',
        'v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC',
        '--section-start--',
        'id',
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        '--section-start--',
        'other_section',
        'some_data'
      ]

      lines.each { |line| modifier.process_line(line) }

      expect(processed_ids).to eq(%w[
        1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
        abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
      ])
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::Parsers::EscapePatternHandler, feature_category: :duo_chat do
  let(:text) { "Some text with a link" }
  let(:link_info) { { link: "https://example.com", starting_index: 5, ending_index: 25 } }
  let(:escape_info) { { pattern: "https://example.com", contains_escaped_backticks: false, start_is_escaped: false } }
  let(:indexes) { { space: 0 } }

  subject(:handler) { described_class.new(text, link_info, escape_info, indexes) }

  describe '#generate_pattern' do
    context 'when method is "both"' do
      before do
        link_info[:method] = 'both'
      end

      it 'handles normal case' do
        result = handler.generate_pattern
        expect(result).to eq({
          link: "https://example.com",
          new_pattern: "`https://example.com`",
          starting_index: 5,
          ending_index: 25,
          add_to_index: 2,
          update_index: 2
        })
      end

      context 'when contains escaped backticks' do
        before do
          escape_info[:contains_escaped_backticks] = true
        end

        it 'handles escaped backticks' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq(" `https://example.com`")
          expect(indexes[:space]).to eq(1)
        end
      end

      context 'when start is escaped' do
        before do
          escape_info[:start_is_escaped] = true
        end

        it 'handles escaped start' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq("\\ `https://example.com`")
          expect(result[:link]).to eq("\\https://example.com")
          expect(indexes[:space]).to eq(1)
        end
      end
    end

    context 'when method is "front"' do
      before do
        link_info[:method] = 'front'
      end

      it 'handles normal case' do
        result = handler.generate_pattern
        expect(result[:new_pattern]).to eq("`https://example.com")
      end

      context 'when contains escaped backticks' do
        before do
          escape_info[:contains_escaped_backticks] = true
        end

        it 'handles escaped backticks' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq("` `https://example.com")
          expect(indexes[:space]).to eq(1)
        end
      end

      context 'when start is escaped' do
        before do
          escape_info[:start_is_escaped] = true
        end

        it 'handles escaped start' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq("\\ `https://example.com")
          expect(result[:link]).to eq("\\https://example.com")
          expect(indexes[:space]).to eq(1)
        end
      end
    end

    context 'when method is "end"' do
      before do
        link_info[:method] = 'end'
      end

      it 'handles normal case' do
        result = handler.generate_pattern
        expect(result[:new_pattern]).to eq("https://example.com`")
      end

      context 'when contains escaped backticks' do
        before do
          escape_info[:contains_escaped_backticks] = true
        end

        it 'handles escaped backticks' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq(" `https://example.com`")
          expect(indexes[:space]).to eq(1)
        end
      end

      context 'when start is escaped' do
        before do
          escape_info[:start_is_escaped] = true
        end

        it 'handles escaped start' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq("\\ https://example.com`")
          expect(result[:link]).to eq("\\https://example.com")
          expect(indexes[:space]).to eq(1)
        end
      end
    end

    context 'when method is "none"' do
      before do
        link_info[:method] = 'none'
      end

      it 'handles normal case' do
        result = handler.generate_pattern
        expect(result[:new_pattern]).to eq("https://example.com")
      end

      context 'when contains escaped backticks' do
        before do
          escape_info[:contains_escaped_backticks] = false
        end

        it 'handles escaped backticks' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq("https://example.com")
          expect(indexes[:space]).to eq(0)
        end
      end

      context 'when start is escaped' do
        before do
          escape_info[:start_is_escaped] = true
        end

        it 'handles escaped start' do
          result = handler.generate_pattern
          expect(result[:new_pattern]).to eq("https://example.com")
          expect(result[:link]).to eq("https://example.com")
          expect(indexes[:space]).to eq(0)
        end
      end
    end
  end
end

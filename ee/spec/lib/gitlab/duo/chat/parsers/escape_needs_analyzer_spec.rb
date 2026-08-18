# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::Parsers::EscapeNeedsAnalyzer, feature_category: :duo_chat do
  let(:text) { "This is a test with a URL: https://gitlab.com and another URL: http://example.com" }
  let(:markdown_blocks) { [] }
  let(:urls) do
    [
      { link: "https://gitlab.com", starting_index: 27, ending_index: 44 },
      { link: "http://example.com", starting_index: 61, ending_index: 79 }
    ]
  end

  let(:escaped_links) { [] }

  subject(:analyzer) { described_class.new(text, markdown_blocks, urls, escaped_links) }

  describe '#analyze' do
    it 'returns a hash of required escapes' do
      result = analyzer.analyze
      expect(result).to be_a(Hash)
    end

    context 'when no escapes are needed' do
      let(:text) { "There are no urls in this text." }
      let(:urls) { [] }

      it 'returns an empty hash' do
        expect(analyzer.analyze).to be_empty
      end
    end

    context 'when beginning escapes are needed' do
      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 27, ending_index: 45 },
          { link: "http://example.com", starting_index: 61, ending_index: 80 }
        ]
      end

      let(:text) { "This is a test with a URL: https://gitlab.com` and another URL: http://example.com" }

      it 'includes front escapes in the result' do
        result = analyzer.analyze
        expect(result['front']).to be_present
      end
    end

    context 'when ending escapes are needed' do
      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 28, ending_index: 46 },
          { link: "http://example.com", starting_index: 62, ending_index: 81 }
        ]
      end

      let(:text) { "This is a test with a URL: `https://gitlab.com and another URL: `http://example.com" }

      it 'includes end escapes in the result' do
        result = analyzer.analyze
        expect(result['end']).to be_present
      end
    end

    context 'when both beginning and ending escapes are needed' do
      let(:text) { "This is a test with a URL: https://gitlab.com and another URL: http://example.com" }

      it 'includes both escapes in the result' do
        result = analyzer.analyze
        expect(result['both']).to be_present
      end
    end

    context 'when URLs are already escaped' do
      let(:escaped_links) { [[27, 44], [61, 79]] }

      it 'does not include already escaped URLs in the result' do
        result = analyzer.analyze
        expect(result).to be_empty
      end
    end

    context 'when markdown blocks are present' do
      let(:markdown_blocks) { [[0, 20]] }

      it 'considers markdown blocks when analyzing' do
        result = analyzer.analyze
        expect(result).not_to be_empty
      end
    end

    context 'when URLs are within markdown blocks' do
      let(:markdown_blocks) { [[0, 50]] }
      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 27, ending_index: 44 }
        ]
      end

      it 'does not include URLs within markdown blocks in the result' do
        result = analyzer.analyze
        expect(result['front']).to be_empty
        expect(result['end']).to be_empty
      end
    end

    context 'when consecutive URLs are present' do
      let(:text) { "URLs: https://gitlab.com http://example.com" }
      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 6, ending_index: 23 },
          { link: "http://example.com", starting_index: 24, ending_index: 42 }
        ]
      end

      it 'correctly handles consecutive URLs' do
        result = analyzer.analyze
        expect(result['both']).to be_present
        expect(result['both'].length).to eq(2)
      end
    end

    context 'when URL is enclosed in backticks' do
      let(:text) { "URL with backticks: `https://gitlab.com`" }
      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 21, ending_index: 39 }
        ]
      end

      it 'correctly identifies already escaped URLs' do
        result = analyzer.analyze
        expect(result).to be_empty
      end
    end

    context 'when URL is before any markdown blocks' do
      let(:text) do
        <<~MARKDOWN
          Testing example with https://example.com before a markdown block
          ```
          Example markdown block
          ```
        MARKDOWN
      end

      let(:markdown_blocks) { [65, 95] }
      let(:urls) do
        [
          { link: "https://example.com", starting_index: 20, ending_index: 40 }
        ]
      end

      it 'correctly analyzes the need for beginning backtick' do
        result = analyzer.analyze
        expect(result['both']).to be_present
      end
    end

    context 'when URL is in a markdown block' do
      let(:text) do
        <<~MARKDOWN
          Testing example with URL in markdown blocks
          ```
          https://example.com
          ```
        MARKDOWN
      end

      let(:markdown_blocks) { [44, 71] }
      let(:urls) do
        [
          { link: "https://example.com", starting_index: 48, ending_index: 67 }
        ]
      end

      it 'correctly analyzes the need for both' do
        result = analyzer.analyze
        expect(result['both']).to be_present
      end
    end

    context 'when URL is after all markdown blocks' do
      let(:text) do
        <<~MARKDOWN
          Testing example with URL after a markdown block
          ```
          Example markdown block
          ```
          https://example.com
        MARKDOWN
      end

      let(:markdown_blocks) { [48, 78] }
      let(:urls) do
        [
          { link: "https://example.com", starting_index: 79, ending_index: 98 }
        ]
      end

      it 'correctly analyzes the need for beginning backtick' do
        result = analyzer.analyze
        expect(result['both']).to be_present
      end
    end

    context 'when the URL is at the start and needs escaped' do
      let(:text) { "https://gitlab.com" }
      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 0, ending_index: 18 }
        ]
      end

      it 'correctly handles consecutive URLs' do
        result = analyzer.analyze
        expect(result['both']).to be_present
      end
    end

    context 'when URL indices are out of bounds' do
      let(:text) { "https://example.com" }
      let(:markdown_blocks) { [[25, 50]] }
      let(:urls) do
        [
          { link: "https://example.com", starting_index: 0, ending_index: 18 },
          { link: "https://gitlab.com", starting_index: 60, ending_index: 78 }
        ]
      end

      it 'handles out of bounds URL indices gracefully' do
        result = analyzer.analyze

        # First URL should need both escapes
        expect(result['both']).to include(hash_including(
          link: 'https://example.com',
          starting_index: 0,
          ending_index: 18
        ))

        # Second URL: text slice is nil
        expect(result['front']).to include(hash_including(
          link: 'https://gitlab.com',
          starting_index: 60,
          ending_index: 78
        ))
      end
    end

    context 'when the URL is already escaped' do
      let(:text) { "Some text `https://gitlab.com` and more text" }
      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 10, ending_index: 29 }
        ]
      end

      let(:escaped_links) { [[0, 10]] }

      it 'correctly handles consecutive URLs' do
        result = analyzer.analyze
        expect(result['both']).to be_empty
      end
    end

    context 'when there is a single code block and the URLs are after' do
      let(:text) do
        <<~MARKDOWN
          ```
          Example markdown block
          ```

          https://example.com Some text https://gitlab.com More text
        MARKDOWN
      end

      let(:markdown_blocks) { [[0, 20]] }

      let(:urls) do
        [
          { link: "https://example.com", starting_index: 31, ending_index: 50 },
          { link: "https://gitlab.com", starting_index: 61, ending_index: 79 }
        ]
      end

      it 'correctly analyzes the need for beginning backtick on the URLs' do
        result = analyzer.analyze

        expect(result['both']).to include(hash_including(link: 'https://example.com', starting_index: 31,
          ending_index: 50))
        expect(result['both']).to include(hash_including(link: 'https://gitlab.com', starting_index: 61,
          ending_index: 79))
      end
    end

    context 'when there are multiple code blocks and URLs and the first URL is after the second code block' do
      let(:text) do
        <<~MARKDOWN
          ```
          Example markdown block
          ```

          ```
          Example markdown block
          ```

          https://example.com Some text https://gitlab.com More text
        MARKDOWN
      end

      let(:markdown_blocks) { [[0, 20], [22, 42]] }

      let(:urls) do
        [
          { link: "https://example.com", starting_index: 64, ending_index: 83 },
          { link: "https://gitlab.com", starting_index: 94, ending_index: 112 }
        ]
      end

      it 'correctly analyzes the need for backticks on the URLs' do
        result = analyzer.analyze

        expect(result['both']).to include(hash_including(link: 'https://example.com', starting_index: 64,
          ending_index: 83))
        expect(result['both']).to include(hash_including(link: 'https://gitlab.com', starting_index: 94,
          ending_index: 112))
      end
    end

    context 'when the URLs are before and after two code blocks' do
      let(:text) do
        <<~MARKDOWN
          https://example.com

          ```
          Example markdown block
          ```

          ```
          Example markdown block
          ```

          Some text https://gitlab.com More text
        MARKDOWN
      end

      let(:markdown_blocks) { [[21, 52], [53, 83]] }

      let(:urls) do
        [
          { link: "https://example.com", starting_index: 0, ending_index: 19 },
          { link: "https://gitlab.com", starting_index: 95, ending_index: 113 }
        ]
      end

      it 'correctly analyzes the text' do
        result = analyzer.analyze

        expect(result['both']).to include(hash_including(link: 'https://gitlab.com'))
      end
    end

    context 'when the URLs are inside a markdown block' do
      let(:text) do
        <<~MARKDOWN
          ```
          Example markdown block
          https://example.com
          Some text https://gitlab.com More text
          ```

          Additional text here
        MARKDOWN
      end

      let(:markdown_blocks) { [[0, 89]] }

      let(:urls) do
        [
          { link: "https://example.com", starting_index: 27, ending_index: 46 },
          { link: "https://gitlab.com", starting_index: 57, ending_index: 75 }
        ]
      end

      it 'correctly analyzes the text, skipping the URLs in the code block' do
        result = analyzer.analyze

        expect(result['both']).to include(hash_including(link: 'https://gitlab.com'))
      end
    end

    context 'when a URL is between two code blocks' do
      let(:text) do
        <<~MARKDOWN
          ```
          Example markdown block
          ```

          Some text https://gitlab.com More text

          ```
          Example markdown block
          ```

        MARKDOWN
      end

      let(:markdown_blocks) { [[0, 30], [72, 102]] }
      # let(:previous_url_escaped_indexes) { [0, 19] } # Simulating previous URL ending at index 20

      let(:urls) do
        [
          { link: "https://gitlab.com", starting_index: 40, ending_index: 60 }
        ]
      end

      it 'correctly analyzes the text' do
        result = analyzer.analyze

        expect(result['both']).to include(hash_including(link: 'https://gitlab.com'))
      end
    end

    # Test cases not going through public interface
    context 'when no escapes are required' do
      let(:link) { "http://example.com" }
      let(:starting_index) { 0 }
      let(:ending_index) { 10 }

      it 'returns hash with "none" key' do
        result = analyzer.send(:determine_required_escape_type, false, false, link, starting_index, ending_index)

        expect(result).to have_key('none')
        expect(result['none']).to contain_exactly(
          {
            sanitize_method: 'none',
            link: link,
            starting_index: starting_index,
            ending_index: ending_index
          }
        )
      end
    end

    context 'when no escapes are required it returns 0 for escapes required' do
      let(:link) { "http://example.com" }
      let(:starting_index) { 0 }
      let(:ending_index) { 10 }
      let(:escaped_type_stub) { { "none" => [{ sanitize_method: "none", link: "https://example.com", starting_index: 0, ending_index: 10 }] } }

      it 'returns hash with "none" key' do
        result = analyzer.send(:count_required_backticks, escaped_type_stub)

        expect(result).to contain_exactly([:end_escapes_required, 0], [:front_escapes_required, 0])
      end
    end
  end
end

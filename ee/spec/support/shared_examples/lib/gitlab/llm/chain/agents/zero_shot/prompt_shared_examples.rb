# frozen_string_literal: true

RSpec.shared_examples 'zero shot prompt' do
  describe '.current_blob_prompt' do
    let(:project) { build(:project) }
    let(:blob) { fake_blob(path: 'foobar.rb', data: 'puts "hello world"') }

    subject(:prompt) { described_class.current_blob_prompt(blob) }

    it 'returns prompt' do
      expected_prompt = <<~PROMPT
        The current code file that user sees is foobar.rb and has the following content:
        <content>
        puts "hello world"
        </content>

      PROMPT

      expect(prompt).to eq(expected_prompt)
    end
  end

  describe '.current_selection_prompt' do
    let(:current_file) do
      {
        file_name: 'test.py',
        selected_text: 'code selection',
        cotent_above_cursor: 'content_above_cursor',
        content_below_cursor: 'content_below_cursor'
      }
    end

    subject(:prompt) { described_class.current_selection_prompt(current_file) }

    it 'returns the base prompt' do
      expected_prompt = <<~PROMPT
        User selected code below enclosed in <code></code> tags in file test.py to work with:

        <code>
          code selection
        </code>

      PROMPT

      expect(prompt).to eq(expected_prompt)
    end
  end
end

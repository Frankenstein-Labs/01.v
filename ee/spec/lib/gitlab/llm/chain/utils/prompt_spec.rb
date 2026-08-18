# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Utils::Prompt, feature_category: :duo_chat do
  let(:content) { ["multi", "line", "%<message>s"] }

  describe 'messages with roles' do
    it 'returns message as system' do
      expect(described_class.as_system(content)).to eq([:system, "multi\nline\n%<message>s"])
    end

    it 'returns message as assistant' do
      expect(described_class.as_assistant(content)).to eq([:assistant, "multi\nline\n%<message>s"])
    end

    it 'returns message as user' do
      expect(described_class.as_user(content)).to eq([:user, "multi\nline\n%<message>s"])
    end
  end

  describe '#no_role_text' do
    let(:prompt) { described_class.as_assistant(content) }
    let(:input_vars) { { message: 'input' } }

    it 'returns bare text from role based prompt' do
      expect(described_class.no_role_text([prompt], input_vars)).to eq("multi\nline\ninput")
    end
  end

  describe '#role_text' do
    let(:input_vars) { { message: 'input' } }

    context 'with roles defined' do
      let(:roles) { Gitlab::Llm::Chain::Concerns::AnthropicPrompt::ROLE_NAMES }

      context 'for assistant' do
        let(:prompt) { described_class.as_assistant(content) }

        it 'returns role-based text from role based prompt' do
          expect(described_class.role_text([prompt], input_vars, roles: roles))
            .to eq("Assistant: multi\nline\ninput")
        end
      end

      context 'for user' do
        let(:prompt) { described_class.as_user(content) }

        it 'returns role-based text from role based prompt' do
          expect(described_class.role_text([prompt], input_vars, roles: roles))
            .to eq("Human: multi\nline\ninput")
        end
      end

      context 'for system' do
        let(:prompt) { described_class.as_system(content) }

        it 'returns role-based text from role based prompt' do
          expect(described_class.role_text([prompt], input_vars, roles: roles))
            .to eq("multi\nline\ninput")
        end
      end
    end

    context 'without roles defined' do
      context 'for assistant' do
        let(:prompt) { described_class.as_assistant(content) }

        it 'returns role-based text from role based prompt' do
          expect(described_class.role_text([prompt], input_vars)).to eq("multi\nline\ninput")
        end
      end

      context 'for user' do
        let(:prompt) { described_class.as_user(content) }

        it 'returns role-based text from role based prompt' do
          expect(described_class.role_text([prompt], input_vars)).to eq("multi\nline\ninput")
        end
      end

      context 'for system' do
        let(:prompt) { described_class.as_system(content) }

        it 'returns role-based text from role based prompt' do
          expect(described_class.role_text([prompt], input_vars)).to eq("multi\nline\ninput")
        end
      end
    end
  end

  describe '#role_conversation' do
    let(:content) { %w[multi line message] }
    let(:prompt) { described_class.as_assistant(content) }

    it 'returns bare text from role based prompt' do
      result = { role: :assistant, content: "multi\nline\nmessage" }

      expect(described_class.role_conversation([prompt])).to eq([result])
    end

    # if the user input contains % chars, a parsing error will occur if `format`
    # is used on the text. As a result, only gitlab-controlled prompts should
    # use `format` to interpolate variables. This tests ensures we don't accidentally add `format` to
    # this method in the future.
    context 'when user prompt contains a %' do
      let(:content) { ["multi", "line", "%essage"] }
      let(:prompt) { described_class.as_user(content) }

      it 'does not return an error' do
        result = { role: :user, content: "multi\nline\n%essage" }

        expect(described_class.role_conversation([prompt])).to eq([result])
      end
    end
  end

  describe '#format_conversation' do
    let(:content) { %w[multi line message] }
    let(:variables) { {} }

    subject(:formatted_conversation) { described_class.format_conversation(prompt, variables) }

    context 'when provided variables' do
      let(:content) { 'hello %<provided_string>s' }
      let(:variables) { { provided_string: 'test' } }
      let(:prompt) { [described_class.as_assistant(content)] }

      it 'substitutes provided variables' do
        expect(formatted_conversation)
          .to eq([[:assistant, "hello test"]])
      end
    end
  end
end

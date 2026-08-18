# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::SlashCommand, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:content) { '/explain' }
  let(:tools) { Gitlab::Llm::Completions::Chat::COMMAND_TOOLS }
  let(:message) do
    build(:ai_chat_message, user: instance_double(User), resource: nil, request_id: 'uuid', content: content)
  end

  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: nil, ai_request: ai_request_double,
      current_file: {
        file_name: 'test.py',
        selected_text: selected_text,
        content_above_cursor: 'code above',
        content_below_cursor: 'code below'
      }
    )
  end

  let(:selected_text) { 'selected text' }

  describe '.for' do
    subject { described_class.for(message: message, context: context, tools: tools) }

    it { is_expected.to be_an_instance_of(described_class) }

    context 'when command is unknown' do
      let(:content) { '/something' }

      it { is_expected.to be_nil }
    end

    context 'when tools are empty' do
      let(:tools) { [] }

      it { is_expected.to be_nil }
    end

    context 'when request comes from the Web' do
      let(:message) do
        build(:ai_chat_message, user: instance_double(User), resource: nil, request_id: 'uuid', content: content)
      end

      it 'returns web as platform_origin' do
        is_expected
          .to be_an_instance_of(described_class)
          .and have_attributes(platform_origin: 'web')
      end
    end

    context 'when request comes from VS Code extension' do
      context 'with platform_origin attribute' do
        let(:message) do
          build(:ai_chat_message, user: instance_double(User), content: content, platform_origin: 'vs_code_extension')
        end

        it 'returns vs_code_extension as platform origin' do
          is_expected
            .to be_an_instance_of(described_class)
            .and have_attributes(platform_origin: 'vs_code_extension')
        end
      end
    end
  end

  describe '#prompt_options' do
    let(:user_input) { nil }
    let(:selected_code_with_input_instruction) { 'explain %<input>s in the code' }
    let(:input_without_selected_code_instruction) { 'Explain the input provided by the user: %<input>s.' }
    let(:params) do
      {
        name: content,
        user_input: user_input,
        tool: nil,
        command_options: {
          selected_code_without_input_instruction: 'explain the code',
          selected_code_with_input_instruction: selected_code_with_input_instruction,
          input_without_selected_code_instruction: input_without_selected_code_instruction
        },
        context: context
      }
    end

    subject { described_class.new(**params).prompt_options }

    it { is_expected.to eq({ input: 'explain the code' }) }

    context 'when user input is present' do
      let(:user_input) { 'method params' }

      it { is_expected.to eq({ input: 'explain method params in the code' }) }

      context 'when selected_code_with_input_instruction is not part of command definition' do
        let(:selected_code_with_input_instruction) { nil }

        it { is_expected.to eq({ input: 'explain the code' }) }
      end

      context 'when selected_text is empty' do
        let(:selected_text) { nil }

        it { is_expected.to eq({ input: 'Explain the input provided by the user: method params.' }) }

        context 'when input_without_selected_code_instruction is not part of command definition' do
          let(:input_without_selected_code_instruction) { nil }

          it { is_expected.to eq({ input: 'explain method params in the code' }) }

          context 'when selected_code_with_input_instruction is not part of command definition' do
            let(:selected_code_with_input_instruction) { nil }

            it { is_expected.to eq({ input: 'explain the code' }) }
          end
        end
      end
    end
  end
end

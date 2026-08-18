# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiMessage, feature_category: :duo_chat do
  subject { described_class.new(data) }

  let(:content) { 'response' }
  let(:user) { build_stubbed(:user) }
  let(:thread) { build_stubbed(:ai_conversation_thread) }
  let(:data) do
    {
      timestamp: timestamp,
      id: 'uuid',
      request_id: 'original_request_id',
      errors: ['some error1', 'another error'],
      extras: {},
      role: 'user',
      content: content,
      ai_action: 'chat',
      client_subscription_id: 'client_subscription_id',
      user: user,
      chunk_id: 1,
      thread: thread,
      type: 'tool',
      context: Gitlab::Llm::AiMessageContext.new(resource: user),
      referer_url: 'http://127.0.0.1:3000',
      additional_context: Gitlab::Llm::AiMessageAdditionalContext.new(
        [
          { category: 'file', id: 'additonial_context.rb', content: 'puts "additional context"' },
          { category: 'snippet', id: 'print_context_method', content: 'def additional_context; puts "context"; end' }
        ]
      )
    }
  end

  let(:timestamp) { 1.year.ago }

  describe 'defaults' do
    it 'sets default timestamp', :freeze_time do
      expect(described_class.new(data.except(:timestamp)).timestamp).to eq(Time.current)
    end

    it 'generates id' do
      id = described_class.new(data.except(:id)).id

      expect(id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end
  end

  describe '#initialize' do
    context 'when the attribute is not in the ATTRIBUTES_LIST' do
      before do
        stub_const("#{described_class}::ATTRIBUTES_LIST", [:id, :role, :user])
      end

      it 'does not set the attribute' do
        result = described_class.new(data)
        expect(result.referer_url).to be_nil
      end
    end

    context 'when the attribute is in the ATTRIBUTES_LIST' do
      before do
        stub_const("#{described_class}::ATTRIBUTES_LIST", [:id, :role, :user, :referer_url])
      end

      it 'sets the attribute' do
        result = described_class.new(data)
        expect(result.referer_url).to eq('http://127.0.0.1:3000')
      end
    end
  end

  describe 'validations' do
    it 'raises an error when role is absent' do
      expect do
        described_class.new(data.except(:role))
      end.to raise_error(ArgumentError)
    end

    it 'raises an error when role is not from the list' do
      expect do
        described_class.new(data.merge(role: 'not_a_role'))
      end.to raise_error(ArgumentError)
    end
  end

  describe '#to_global_id' do
    it 'returns global ID' do
      expect(subject.to_global_id.to_s).to eq('gid://gitlab/Gitlab::Llm::AiMessage/uuid')
    end
  end

  describe '#size' do
    it 'returns 0 if content is missing' do
      data[:content] = nil

      expect(subject.size).to eq(0)
    end

    it 'returns size of the content if present' do
      expect(subject.size).to eq(data[:content].size)
    end
  end

  describe '#save!' do
    it 'raises NoMethodError' do
      expect { subject.save! }.to raise_error(NoMethodError, "Can't save regular AiMessage.")
    end
  end

  describe '#to_h' do
    it 'returns hash with all attributes' do
      expect(subject.to_h).to eq(data.stringify_keys)
    end
  end

  describe '#slash_command?' do
    using RSpec::Parameterized::TableSyntax

    where(:message, :is_slash_command) do
      nil                  | false
      'something'          | false
      '/explain'           | true
      '/explain something' | true
      '/e xplain somethin' | true
      '/ something'        | false
      ' /something'        | false
    end

    with_them do
      let(:content) { message }

      it { expect(subject.slash_command?).to eq(is_slash_command) }
    end
  end

  describe '#slash_command_and_input' do
    using RSpec::Parameterized::TableSyntax

    where(:message, :output) do
      nil                  | []
      'something'          | []
      '/explain'           | ['/explain']
      '/explain something' | ['/explain', 'something']
      '/e xplain somethin' | ['/e', 'xplain somethin']
      '/ something'        | []
      ' /something'        | []
    end

    with_them do
      let(:content) { message }

      it { expect(subject.slash_command_and_input).to eq(output) }
    end
  end

  describe '#user?' do
    context 'when role is user' do
      it { is_expected.to be_user }
    end

    context 'when role is not user' do
      before do
        data[:role] = 'system'
      end

      it { is_expected.not_to be_user }
    end
  end

  describe '#assistant?' do
    context 'when role is assistant' do
      before do
        data[:role] = 'assistant'
      end

      it { is_expected.to be_assistant }
    end

    context 'when role is not assistant' do
      it { is_expected.not_to be_assistant }
    end
  end

  describe '#resource' do
    it 'delegates to context' do
      expect(subject.resource).to eq(data[:context].resource)
    end
  end

  describe '#==' do
    it 'returns true if comparing to self' do
      m1 = build(:ai_message)

      expect(m1).to eq(m1)
    end

    it 'compares id only' do
      m1 = build(:ai_chat_message, content: 'foobarbaz')
      m2 = build(:ai_chat_message, content: 'foobar...')

      expect(m1).not_to eq(m2)

      m2.id = m1.id

      expect(m1).to eq(m2)
    end

    it 'returns false if class is different' do
      m1 = build(:ai_message, content: 'foobar')
      m2 = build(:ai_chat_message, content: 'foobar', id: m1.id)

      expect(m1).not_to eq(m2)
    end

    it 'returns false if id is nil' do
      m1 = build(:ai_message, id: nil)
      m2 = build(:ai_message, id: nil)

      expect(m1).not_to eq(m2)
    end
  end

  describe "#chat?" do
    it 'returns true for chat message' do
      expect(subject).not_to be_chat
    end
  end

  describe '#thread_id' do
    context 'when thread is present' do
      it 'returns the thread id' do
        expect(subject.thread_id).to eq(thread.id)
      end
    end

    context 'when thread is nil' do
      it 'returns nil' do
        subject.thread = nil

        expect(subject.thread_id).to be_nil
      end
    end
  end
end

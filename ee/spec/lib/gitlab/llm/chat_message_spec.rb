# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ChatMessage, feature_category: :duo_chat do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:thread, freeze: false) { create(:ai_conversation_thread) }

  subject { build(:ai_chat_message, user: user, thread: thread) }

  describe '#conversation_reset?' do
    it 'returns true for reset message' do
      expect(build(:ai_chat_message, content: '/reset')).to be_conversation_reset
    end

    it 'returns false for regular message' do
      expect(subject).not_to be_conversation_reset
    end
  end

  describe '#clear_history?' do
    it "returns true for clear message" do
      expect(build(:ai_chat_message, content: '/clear')).to be_clear_history
    end

    it 'returns false for regular message' do
      expect(subject).not_to be_clear_history
    end
  end

  describe '#question?' do
    where(:role, :content, :expectation) do
      [
        ['user', 'foo?', true],
        ['user', '/reset', false],
        ['user', '/clear', false],
        ['user', '/new', false],
        ['assistant', 'foo?', false]
      ]
    end

    with_them do
      it "returns expectation" do
        subject.assign_attributes(role: role, content: content)

        expect(subject.question?).to eq(expectation)
      end
    end
  end

  describe '#save!' do
    it 'saves the message to chat storage' do
      expect_next_instance_of(Gitlab::Llm::ChatStorage, subject.user, thread) do |instance|
        expect(instance).to receive(:add).with(subject)
      end

      subject.save!
    end

    it 'raises error if thread is absent' do
      subject.thread = nil

      expect { subject.save! }.to raise_error "thread_absent"
    end

    context 'for /reset message' do
      it 'saves the message to chat storage' do
        message = build(:ai_chat_message, user: user, content: '/reset')

        expect_next_instance_of(Gitlab::Llm::ChatStorage, message.user, nil) do |instance|
          expect(instance).to receive(:add).with(message)
        end

        message.save!
      end
    end

    context 'for slash commands to clear history' do
      it "removes all messages from chat storage for message '/new'" do
        message = build(:ai_chat_message, user: user, content: '/new')

        expect_next_instance_of(Gitlab::Llm::ChatStorage, message.user, nil) do |instance|
          expect(instance).to receive(:clear!)
        end

        message.save!
      end

      it "removes all messages from chat storage for message '/clear'" do
        message = build(:ai_chat_message, user: user, content: '/clear')

        expect_next_instance_of(Gitlab::Llm::ChatStorage, message.user, nil) do |instance|
          expect(instance).to receive(:clear!)
        end

        message.save!
      end
    end
  end

  describe "#chat?" do
    it 'returns true for chat message' do
      expect(subject).to be_chat
    end
  end

  describe '#active_record' do
    it 'returns the active record if assigned' do
      subject.active_record = build_stubbed(:ai_conversation_message)

      expect(subject.active_record).to be_a(Ai::Conversation::Message)
    end

    it 'returns the active record if saved' do
      subject.save!

      expect(subject.active_record).to be_a(Ai::Conversation::Message)
    end

    it 'returns nil if not saved' do
      subject

      expect(subject.active_record).to be_nil
    end
  end
end

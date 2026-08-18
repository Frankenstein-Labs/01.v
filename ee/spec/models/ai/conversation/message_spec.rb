# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversation::Message, feature_category: :duo_chat do
  using RSpec::Parameterized::TableSyntax

  subject(:message) { create(:ai_conversation_message) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization') }
    it { is_expected.to belong_to(:thread).class_name('Ai::Conversation::Thread') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:thread_id) }

    describe 'extras json validation' do
      context 'when extras match the JSON schema' do
        let(:valid_json) do
          {
            additional_context: [
              {
                id: "123",
                category: "category",
                content: "content",
                metadata: { key: "value" }
              }
            ],
            agent_scratchpad: [
              {
                action: {
                  thought: "thought",
                  tool: "tool",
                  tool_input: "tool_input"
                },
                observation: "observation"
              }
            ],
            sources: [
              {
                source_url: "https://example.com",
                title: "Fork a project",
                source_type: "doc",
                md5sum: "md5sum",
                source: "project_forks.md"
              }
            ],
            has_feedback: false
          }.to_json
        end

        it { is_expected.to allow_value(valid_json).for(:extras) }
      end
    end

    context 'when record already exists' do
      let(:invalid_json) { { invalid_key: "value" }.to_json }
      let(:updated_invalid_json) { { another_invalid_key: "value" }.to_json }
      let(:message) { create(:ai_conversation_message) }

      before do
        message.extras = invalid_json
        message.save!(validate: false)
      end

      it 'skips validation if extras is not changed' do
        expect(message.update(content: 'New content')).to be true
      end

      it 'accepts valid JSON when extras is changed' do
        expect(message.update(extras: updated_invalid_json)).to be true
      end
    end

    context 'when there are fields undefined in the JSON schema' do
      let(:invalid_json) { { invalid_key: "value" }.to_json }
      let(:thread) { create(:ai_conversation_thread) }

      subject { build(:ai_conversation_message, thread: thread, content: 'test', role: 'user', extras: invalid_json) }

      it { is_expected.to be_valid }
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(user: 1, assistant: 2) }
  end

  describe 'scopes' do
    describe '.for_thread' do
      subject(:messages_for_thread) { described_class.for_thread(thread) }

      let(:thread) { create(:ai_conversation_thread) }
      let(:message1) { create(:ai_conversation_message, thread: thread) }
      let(:message2) { create(:ai_conversation_message, thread: thread) }
      let(:other_message) { create(:ai_conversation_message) }

      it 'returns messages for the specified thread' do
        expect(messages_for_thread).to match_array([message1, message2])
      end
    end

    describe '.for_id' do
      let_it_be(:message_xid) { SecureRandom.uuid }
      let_it_be(:message) { create(:ai_conversation_message, message_xid: message_xid) }

      it 'returns message with the specified record id' do
        expect(described_class.for_id(message.id)).to eq([message])
      end

      it 'returns message with the specified record id as string' do
        expect(described_class.for_id(message.id.to_s)).to eq([message])
      end

      it 'returns message with the specified message_xid' do
        expect(described_class.for_id(message_xid)).to eq([message])
      end
    end

    describe '.ordered' do
      subject(:messages) { described_class.ordered }

      let!(:message1) { create(:ai_conversation_message) }
      let!(:message2) { create(:ai_conversation_message) }

      it 'returns messages ordered by id' do
        expect(messages).to eq([message1, message2])
      end
    end

    describe '.for_user' do
      let_it_be(:user) { create(:user) }
      let_it_be(:thread) { create(:ai_conversation_thread, user: user) }

      let_it_be(:message) { create(:ai_conversation_message, thread: thread, role: :user) }
      let_it_be(:message_from_other_user) { create(:ai_conversation_message, role: :user) }

      it 'returns messages readable by the user' do
        messages = described_class.for_user(user)

        expect(messages).to contain_exactly(message)
      end
    end

    describe '.find_for_user!' do
      let_it_be(:user) { create(:user) }
      let_it_be(:thread) { create(:ai_conversation_thread, user: user) }
      let_it_be(:message) { create(:ai_conversation_message, thread: thread) }

      context 'when message exists and belongs to the user' do
        it 'returns the message' do
          expect(described_class.find_for_user!(message.message_xid, user)).to eq(message)
        end
      end

      context 'when message exists but belongs to different user' do
        let(:other_user) { create(:user) }

        it 'raises ActiveRecord::RecordNotFound' do
          expect do
            described_class.find_for_user!(message.message_xid, other_user)
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when message_xid does not exist' do
        let(:non_existent_xid) { SecureRandom.uuid }

        it 'raises ActiveRecord::RecordNotFound' do
          expect do
            described_class.find_for_user!(non_existent_xid, user)
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end

  describe '.recent' do
    subject(:messages) { described_class.recent(limit) }

    let_it_be(:message1) { create(:ai_conversation_message) }
    let_it_be(:message2) { create(:ai_conversation_message) }
    let_it_be(:message3) { create(:ai_conversation_message) }

    let(:limit) { 2 }

    it 'returns recent messages' do
      expect(messages).to eq([message2, message3])
    end

    context 'when limit is nil' do
      let(:limit) { nil }

      it 'returns recent messages without limit' do
        expect(messages).to eq([message1, message2, message3])
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation :truncate_referer_url' do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, organizations: [organization]) }
      let(:thread) { create(:ai_conversation_thread, user: user, organization: organization) }
      let(:long_url) { "https://gitlab.com/#{'a' * 300}" }

      it 'truncates referer_url to 255 characters' do
        message = described_class.new(thread: thread, content: 'message', role: 'user', referer_url: long_url)
        message.valid?
        expect(message.referer_url.length).to eq(255)
        expect(message.referer_url).to eq(long_url.truncate(255, omission: ''))
        expect(message).to be_valid
      end
    end

    describe 'before_create :populate_organization_id' do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, organizations: [organization]) }
      let(:thread) { create(:ai_conversation_thread, user: user, organization: organization) }

      it 'sets organization_id from thread' do
        message = described_class.create!(thread: thread, content: 'message', role: 'user')

        expect(message.organization_id).to eq(user.organizations.first.id)
      end
    end
  end

  context 'with loose foreign key on ai_conversation_threads.thread_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:ai_conversation_thread) }
      let_it_be(:model) { create(:ai_conversation_message, thread: parent) }
    end
  end

  describe '#conversation_reset?' do
    it 'returns true for reset message' do
      expect(build(:ai_conversation_message, content: '/reset')).to be_conversation_reset
    end

    it 'returns false for regular message' do
      expect(message).not_to be_conversation_reset
    end
  end

  describe '#clear_history?' do
    it "returns true for clear message" do
      expect(build(:ai_conversation_message, content: '/clear')).to be_clear_history
    end

    it 'returns false for regular message' do
      expect(message).not_to be_clear_history
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
        message.assign_attributes(role: role, content: content)

        expect(message.question?).to eq(expectation)
      end
    end
  end

  describe '#extras' do
    let_it_be_with_refind(:message) { create(:ai_conversation_message) }

    where(:input, :has_feedback, :expected_output) do
      nil            | true  | { 'has_feedback' => true }
      { 'k' => 'v' } | true  | { 'k' => 'v', 'has_feedback' => true }
      '{"k":"v"}'    | false | { 'k' => 'v', 'has_feedback' => false }
      '{invalid}'    | true  | { 'has_feedback' => true }
    end

    with_them do
      it 'returns hash' do
        message.extras = input
        allow(message).to receive(:has_feedback?).and_return(has_feedback)

        expect(message.extras).to eq(expected_output)
      end
    end
  end

  describe '#error_details' do
    let_it_be_with_refind(:message) { create(:ai_conversation_message) }

    where(:input, :expected_output) do
      nil                   | []
      %w[error1 error2]     | %w[error1 error2]
      '["error1","error2"]' | %w[error1 error2]
      '[invalid:json]'      | []
    end

    with_them do
      it 'returns array' do
        message.error_details = input

        expect(message.error_details).to eq(expected_output)
      end
    end
  end
end

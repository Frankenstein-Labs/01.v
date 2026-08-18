# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiMessage'], feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:current_user) { build_stubbed(:user) }
  let_it_be(:message, freeze: false) { create(:ai_conversation_message) }
  let_it_be(:thread) { message.thread }

  it { expect(described_class.graphql_name).to eq('AiMessage') }

  it 'has the expected fields' do
    expected_fields = %w[
      id request_id content content_html role timestamp errors type chunk_id thread_id
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe '#id' do
    it 'returns message_xid' do
      resolved_field = resolve_field(:id, message, current_user: current_user)

      expect(resolved_field).to eq(message.message_xid)
    end
  end

  describe '#thread_id' do
    it 'returns thread id' do
      resolved_field = resolve_field(:thread_id, message, current_user: current_user)

      expect(resolved_field).to eq(thread.id)
    end
  end

  describe '#content_html' do
    let(:content) { message.content }

    before do
      allow(Banzai).to receive(:render_and_post_process).with(content, {
        current_user: current_user,
        only_path: false,
        pipeline: :full,
        allow_comments: false,
        skip_project_check: true
      }).and_return('banzai_content')
    end

    it 'renders html through Banzai' do
      resolved_field = resolve_field(:content_html, message, current_user: current_user)

      expect(resolved_field).to eq('banzai_content')
    end

    context 'when message contains an error' do
      before do
        message.error_details = { details: 'An unexpected error has occurred' }
      end

      after do
        message.error_details = nil
      end

      it 'does not render content_html' do
        resolved_field = resolve_field(:content_html, message, current_user: current_user)

        expect(resolved_field).to be_nil
      end
    end
  end

  describe '#errors' do
    before do
      message.error_details = ['foo']
    end

    after do
      message.error_details = nil
    end

    it 'returns errors' do
      resolved_field = resolve_field(:errors, message, current_user: current_user)

      expect(resolved_field).to eq(['foo'])
    end
  end

  describe '.authorization' do
    it 'allows ai_features scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features)
    end
  end

  context 'when object is Hash' do
    it { expect(described_class.graphql_name).to eq('AiMessage') }

    it 'has the expected fields' do
      expected_fields = %w[
        id request_id content content_html role timestamp errors type chunk_id thread_id
      ]

      expect(described_class).to include_graphql_fields(*expected_fields)
    end

    describe '#id' do
      let(:expected_id) { '123' }
      let(:message) { build(:ai_message, id: expected_id) }

      it 'returns message id' do
        resolved_field = resolve_field(:id, message.to_h, current_user: current_user)

        expect(resolved_field).to eq(expected_id)
      end
    end

    describe '#thread_id' do
      let(:thread) { build_stubbed(:ai_conversation_thread, user: current_user) }
      let(:expected_value) { thread.id }
      let(:message) { build(:ai_message, thread: thread) }

      it 'returns thread id' do
        resolved_field = resolve_field(:thread_id, message.to_h, current_user: current_user)

        expect(resolved_field).to eq(expected_value)
      end
    end

    describe '#content_html' do
      let(:message) { build(:ai_message, content: content) }
      let(:content) { "Hello, **World**!" }

      context 'when content is html renderable' do
        before do
          allow(Banzai).to receive(:render_and_post_process).with(content, {
            current_user: current_user,
            only_path: false,
            pipeline: :full,
            allow_comments: false,
            skip_project_check: true
          }).and_return('banzai_content')
        end

        it 'renders html through Banzai' do
          resolved_field = resolve_field(:content_html, message.to_h, current_user: current_user)

          expect(resolved_field).to eq('banzai_content')
        end
      end

      context 'when message contains an error' do
        it 'does not render content_html' do
          resolved_field = resolve_field(
            :content_html,
            message.to_h.merge(errors: 'An unexpected error has occurred'),
            current_user: current_user
          )

          expect(resolved_field).to be_nil
        end
      end
    end

    describe '#errors' do
      let(:message) { build(:ai_message, errors: ['foo']) }

      it 'returns errors' do
        resolved_field = resolve_field(:errors, message.to_h, current_user: current_user)

        expect(resolved_field).to eq(['foo'])
      end
    end

    describe '.authorization' do
      it 'allows ai_features scope token' do
        expect(described_class.authorization.permitted_scopes).to include(:ai_features)
      end
    end
  end
end

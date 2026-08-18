# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::ChatMessagesResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user).tap { |u| project.add_developer(u) } }
    let_it_be(:another_user) do
      create(:user).tap do |u|
        project.add_developer(u)
      end
    end

    let(:args) { {} }

    subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: user }, args: args) }

    it 'returns empty' do
      expect(resolver).to eq([])
    end

    context 'when there is a message' do
      let!(:thread) do
        create(:ai_conversation_thread, user: user, conversation_type: :duo_chat_legacy)
      end

      let!(:message) do
        create(:ai_conversation_message, created_at: Time.new(2020, 2, 2, 17, 30, 45, '+00:00'),
          thread: thread, message_xid: 'message_xid')
      end

      shared_examples_for 'message response' do
        it 'returns the message' do
          expect(resolver).to match([message])
        end
      end

      it_behaves_like 'message response'

      context 'when thread_id is specified' do
        let(:args) { { thread_id: thread.to_global_id } }

        it_behaves_like 'message response'

        context 'when thread is not found' do
          let!(:thread) { create(:ai_conversation_thread, user: another_user) }

          it 'returns error' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
              "Thread not found. It may have expired.") do
              resolver
            end
          end
        end
      end

      context 'when conversation_type is not specified, and thread of same type is absent' do
        let(:args) { {} }
        let!(:thread) { create(:ai_conversation_thread, user: user, conversation_type: :duo_chat) }

        it 'returns empty and creates fallback thread' do
          expect do
            expect(resolver).to eq([])
          end.to change { Ai::Conversation::Thread.count }.by(1)
        end
      end

      context 'when conversation_type is specified' do
        let(:args) { { conversation_type: 'duo_chat_legacy' } }

        it_behaves_like 'message response'

        context 'when duo_chat_legacy thread is not found' do
          let!(:thread) { create(:ai_conversation_thread, user: user, conversation_type: :duo_chat) }

          it 'returns empty and does not create fallback thread' do
            expect do
              expect(resolver).to eq([])
            end.not_to change { Ai::Conversation::Thread.count }
          end
        end

        context 'when duo_chat thread is not found' do
          let(:args) { { conversation_type: 'duo_chat' } }
          let!(:thread) { create(:ai_conversation_thread, user: another_user, conversation_type: :duo_chat) }

          it 'returns empty and does not create fallback thread' do
            expect do
              expect(resolver).to eq([])
            end.not_to change { Ai::Conversation::Thread.count }
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Conversations::TitleResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user).tap { |u| project.add_developer(u) } }
    let_it_be(:thread) { nil }

    subject(:resolver) { resolve(described_class, obj: thread, ctx: { current_user: user }) }

    it 'returns nil' do
      expect(resolver).to be_nil
    end

    context 'when there are threads' do
      let!(:thread) { create(:ai_conversation_thread, user: user) }

      let!(:message) do
        create(:ai_conversation_message, content: 'First message', thread: thread)
      end

      it 'returns the title' do
        expect(resolver.value).to eq('First message')
      end
    end
  end
end

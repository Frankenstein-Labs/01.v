# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Conversations::ThreadsResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user).tap { |u| project.add_developer(u) } }
    let_it_be(:another_user) { create(:user).tap { |u| project.add_developer(u) } }

    let(:args) { {} }

    subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: user }, args: args) }

    it 'returns empty' do
      expect(resolver).to eq([])
    end

    context 'when there are threads' do
      let_it_be(:thread_1) { create(:ai_conversation_thread, user: user, last_updated_at: 1.day.ago) }
      let_it_be(:thread_2) { create(:ai_conversation_thread, user: user) }
      let_it_be(:thread_3) { create(:ai_conversation_thread, user: another_user) }

      it 'returns results' do
        expect(resolver).to eq([thread_2, thread_1])
      end

      context 'when id is specified' do
        let(:args) { { id: thread_1.to_global_id } }

        it 'returns results' do
          expect(resolver).to eq([thread_1])
        end
      end

      context 'when conversation_type is specified' do
        let(:args) { { conversation_type: 'duo_chat' } }

        it 'returns results' do
          expect(resolver).to eq([thread_2, thread_1])
        end
      end
    end
  end
end

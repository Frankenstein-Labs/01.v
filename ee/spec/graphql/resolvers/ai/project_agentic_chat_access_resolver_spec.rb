# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::ProjectAgenticChatAccessResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }

  describe '#resolve' do
    subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: user }) }

    context 'when user is not logged in' do
      let(:user) { nil }

      it 'returns false' do
        expect(resolver).to be(false)
      end
    end

    context 'when user is logged in' do
      context 'when user has access to agentic chat' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, project).and_return(true)
        end

        it 'returns true' do
          expect(resolver).to be(true)
        end
      end

      context 'when user does not have access to agentic chat' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, project).and_return(false)
        end

        it 'returns false' do
          expect(resolver).to be(false)
        end
      end
    end
  end
end

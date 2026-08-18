# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::UserClassicChatAccessResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

  describe '#resolve' do
    subject(:resolver) { resolve(described_class, ctx: { current_user: user }) }

    context 'when user is not logged in' do
      let(:user) { nil }

      it 'returns false' do
        expect(resolver).to be(false)
      end
    end

    context 'when user is logged in' do
      context 'when user has access to classic chat' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :access_duo_classic_chat, :global).and_return(true)
        end

        it 'returns true' do
          expect(resolver).to be(true)
        end
      end

      context 'when user does not have access to classic chat' do
        before do
          allow(Ability).to receive(:allowed?).with(user, :access_duo_classic_chat, :global).and_return(false)
        end

        it 'returns false' do
          expect(resolver).to be(false)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::DuoDefaultNamespaceCandidatesResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group1) { create(:group) }
  let_it_be(:group2) { create(:group) }

  let(:current_user) { user }
  let(:context) { { current_user: current_user } }

  subject(:resolve_namespaces) { resolve(described_class, ctx: context) }

  describe '#resolve' do
    context 'when user has namespace candidates' do
      before do
        allow(user.user_preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.where(id: [group1.id, group2.id]))
      end

      it 'returns the candidates from user preference' do
        expect(resolve_namespaces).to match_array([group1, group2])
      end
    end

    context 'when user has no namespace candidates' do
      before do
        allow(user.user_preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.none)
      end

      it 'returns empty result' do
        expect(resolve_namespaces).to be_empty
      end
    end

    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it 'returns empty result' do
        expect(resolve_namespaces).to be_empty
      end
    end
  end
end

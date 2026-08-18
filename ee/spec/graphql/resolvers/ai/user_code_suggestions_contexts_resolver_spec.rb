# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::UserCodeSuggestionsContextsResolver, feature_category: :code_suggestions do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

  describe '#resolve' do
    shared_examples 'returns an empty array' do
      it { expect(result).to eq([]) }
    end

    subject(:result) { resolve(described_class, ctx: { current_user: current_user }) }

    context 'when current user is not given' do
      let(:current_user) { nil }

      it_behaves_like 'returns an empty array'
    end

    context 'when current user is given' do
      let(:current_user) { user }

      context 'when code suggestions is switched off for instance' do
        before do
          stub_feature_flags(ai_duo_code_suggestions_switch: false)
        end

        it_behaves_like 'returns an empty array'
      end

      context 'when user does not have access to code suggestions' do
        # there is no set up needed here because a single user
        # does not have access to code suggestions by default
        it_behaves_like 'returns an empty array'
      end

      context 'when user has access to code suggestions' do
        before do
          allow(current_user).to receive(:can?).with(:access_code_suggestions).and_return(true)
        end

        let(:all_additional_contexts) { %w[repository_xray open_tabs imports] }
        let(:expected_additional_contexts) { all_additional_contexts }

        it 'returns the expected additional contexts' do
          expect(result).to eq(expected_additional_contexts)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::CodeReview::Modes::Classic, feature_category: :duo_code_review do
  subject(:mode) { described_class.new(user: user, container: container) }

  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:container) { project }

  describe '#mode' do
    it 'returns the mode name' do
      expect(mode.mode).to eq(:classic)
    end
  end

  describe '#enabled?' do
    it 'always returns true' do
      expect(mode).to be_enabled
    end
  end

  describe '#active?' do
    let(:feature_authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
    let(:user_has_access_ai_review_mr_ability) { true }
    let(:feature_authorizer_allowed) { true }

    before do
      allow(Ability).to receive(:allowed?)
        .with(user, :access_ai_review_mr, container)
        .and_return(user_has_access_ai_review_mr_ability)

      allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new)
        .with(
          container: container,
          feature_name: :review_merge_request,
          user: user
        )
        .and_return(feature_authorizer)

      allow(feature_authorizer).to receive(:allowed?)
        .and_return(feature_authorizer_allowed)
    end

    shared_examples 'not active' do
      it 'returns false' do
        expect(mode).not_to be_active
      end
    end

    shared_examples 'active' do
      it 'returns true' do
        expect(mode).to be_active
      end
    end

    context 'when no user in the context' do
      let(:user) { nil }

      include_examples 'not active'
    end

    context 'when user has access_ai_review_mr ability and feature authorizer allows' do
      include_examples 'active'
    end

    context 'when user does not have access_ai_review_mr ability' do
      let(:user_has_access_ai_review_mr_ability) { false }

      include_examples 'not active'
    end

    context 'when feature authorizer does not allow' do
      let(:feature_authorizer_allowed) { false }

      include_examples 'not active'
    end

    context 'when both conditions fail' do
      let(:user_has_access_ai_review_mr_ability) { false }
      let(:feature_authorizer_allowed) { false }

      include_examples 'not active'
    end

    context 'when user has ability but feature authorizer does not allow' do
      let(:user_has_access_ai_review_mr_ability) { true }
      let(:feature_authorizer_allowed) { false }

      include_examples 'not active'
    end

    context 'when user does not have ability but feature authorizer allows' do
      let(:user_has_access_ai_review_mr_ability) { false }
      let(:feature_authorizer_allowed) { true }

      include_examples 'not active'
    end
  end
end

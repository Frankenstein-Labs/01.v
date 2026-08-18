# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::TestingTermsAcceptance, feature_category: :"self-hosted_models" do
  describe 'valid?' do
    let(:user_id) { 1 }
    let(:user_email) { 'abc@gitlab.com' }

    subject(:acceptance) { described_class.new(user_id: user_id, user_email: user_email) }

    it { is_expected.to be_valid }

    context 'when user_id is missing' do
      let(:user_id) { nil }

      it { is_expected.not_to be_valid }
    end

    context 'when email is too long' do
      let(:user_email) { 'a' * 256 }

      it { is_expected.not_to be_valid }
    end

    context 'when email is missing' do
      let(:user_email) { nil }

      it { is_expected.not_to be_valid }
    end
  end

  describe 'has_accepted?' do
    subject { described_class.has_accepted? }

    context 'when no user has accepted' do
      it { is_expected.to be(false) }
    end

    context 'when at least 1 user has accepted' do
      before do
        create(:ai_testing_terms_acceptances, user_id: 1, user_email: 'sample')
      end

      it { is_expected.to be(true) }
    end
  end
end

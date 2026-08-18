# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::AppearancesHelper, feature_category: :shared do
  let_it_be(:user) { build_stubbed(:user) }

  describe '#brand_title' do
    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when onboarding is disabled' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'returns nil with custom sign in' do
        expect(helper.send(:custom_sign_in_brand_title)).to be_nil
      end

      it 'returns nil with custom sign up' do
        expect(helper.send(:custom_sign_up_brand_title)).to be_nil
      end
    end

    context 'when onboarding is enabled' do
      before do
        stub_saas_features(onboarding: true)
      end

      it 'returns the sign-in page title' do
        expect(helper.send(:custom_sign_in_brand_title)).to eq('Sign in to GitLab')
      end

      it 'returns the sign-up page title' do
        expect(helper.send(:custom_sign_up_brand_title)).to eq('Get started with GitLab')
      end
    end
  end
end

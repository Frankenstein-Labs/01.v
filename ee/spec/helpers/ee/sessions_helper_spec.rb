# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SessionsHelper, feature_category: :system_access do
  describe '#show_passkey_immediately?' do
    context 'when the redirect_sign_in_when_login_not_found SaaS feature is available' do
      before do
        stub_saas_features(redirect_sign_in_when_login_not_found: true)
      end

      it 'returns false' do
        expect(helper.show_passkey_immediately?).to be(false)
      end
    end

    context 'when the redirect_sign_in_when_login_not_found SaaS feature is not available' do
      before do
        stub_saas_features(redirect_sign_in_when_login_not_found: false)
      end

      it 'returns true' do
        expect(helper.show_passkey_immediately?).to be(true)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::DiscoverPremiumController, feature_category: :activation do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:license) { create(:license, :ultimate_trial) }

  describe 'GET show' do
    before do
      stub_saas_features(subscriptions_trials: false)
    end

    subject { response }

    shared_examples 'discover not available' do
      it 'renders with not found' do
        get admin_discover_premium_path

        is_expected.to have_gitlab_http_status(:not_found)
        is_expected.not_to render_template(:show)
      end
    end

    context 'when user is an admin', :enable_admin_mode do
      before do
        login_as(admin)
      end

      it 'renders with success' do
        get admin_discover_premium_path

        is_expected.to have_gitlab_http_status(:ok)
      end

      context 'when there is no license', :without_license do
        it_behaves_like 'discover not available'
      end
    end

    context 'when user is not an admin' do
      before do
        login_as(user)
      end

      it_behaves_like 'discover not available'
    end

    it 'renders not found when saas feature subscriptions_trials is available', :enable_admin_mode do
      stub_saas_features(subscriptions_trials: true)
      login_as(admin)

      get admin_discover_premium_path

      is_expected.to have_gitlab_http_status(:not_found)
    end
  end
end

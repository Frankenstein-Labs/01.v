# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabCreditsDashboard::UsersController,
  :enable_admin_mode, feature_category: :consumables_cost_management do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:display_gitlab_credits_user_data) { true }

  before do
    sign_in(admin)
    stub_application_setting(display_gitlab_credits_user_data: display_gitlab_credits_user_data)
  end

  describe 'GET /admin/gitlab_credits_dashboard/users' do
    subject(:request) { get admin_gitlab_credits_dashboard_user_path(username: user.username) }

    it 'returns 200' do
      request

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'renders 404 when in .com', :saas do
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'renders 404 when unlicensed' do
      allow(License).to receive(:current).and_return(nil)
      request

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when instance only has a gitlab_credits add-on' do
      before do
        stub_licensed_features(usage_billing: false)
        create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, :self_managed)
        stub_request(:head, %r{https://customers\.staging\.gitlab\.com/api/v1/consumers/resolve})
          .to_return(status: 200, body: "", headers: {})
      end

      it 'returns 200' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when display_gitlab_credits_user_data is false' do
      let(:display_gitlab_credits_user_data) { false }

      it 'renders 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    it 'pushes wallet_agnostic_credits_dashboard feature flag to the frontend' do
      request

      expect(response.body).to have_pushed_frontend_feature_flags(walletAgnosticCreditsDashboard: true)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabCreditsDashboardController, :enable_admin_mode, feature_category: :consumables_cost_management do
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe 'GET /admin/gitlab_credits_dashboard' do
    subject(:request) { get admin_gitlab_credits_dashboard_index_path }

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

    context 'for display_gitlab_credits_user_data' do
      before do
        stub_application_setting(display_gitlab_credits_user_data: true)
      end

      it 'pushes the setting to the frontend' do
        request

        expect(response.body).to include('gon.display_gitlab_credits_user_data=true')
      end
    end

    it 'pushes wallet_agnostic_credits_dashboard feature flag to the frontend' do
      request

      expect(response.body).to include('"walletAgnosticCreditsDashboard":true')
    end
  end
end

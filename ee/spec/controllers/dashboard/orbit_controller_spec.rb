# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dashboard::OrbitController, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user) }

  describe 'GET #show' do
    before do
      stub_config(knowledge_graph: { 'enabled' => true })
      stub_feature_flags(knowledge_graph: true)
      sign_in(user)
    end

    it 'renders the show template even when no licensed namespace, so the upsell empty state shows' do
      get :show

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(knowledge_graph: false)
      end

      it 'returns 404' do
        get :show

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when service is not configured' do
      before do
        stub_config(knowledge_graph: { 'enabled' => false })
      end

      it 'returns 404' do
        get :show

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out(user)
      end

      it 'redirects to sign in' do
        get :show

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

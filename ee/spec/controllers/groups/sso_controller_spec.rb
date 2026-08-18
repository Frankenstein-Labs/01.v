# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SsoController, feature_category: :system_access do
  let(:user) { create(:user) }
  let(:group) { create(:group, :private, name: 'our-group') }

  before do
    stub_licensed_features(group_saml: true)
    allow(Devise).to receive(:omniauth_providers).and_return(%i[group_saml])
    sign_in(user)
  end

  context 'SAML configured' do
    let!(:saml_provider) { create(:saml_provider, group: group) }

    it 'has status 200' do
      get :saml, params: { group_id: group }

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'malicious redirect parameter falls back to group_path' do
      get :saml, params: { group_id: group, redirect: '///malicious-url' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(assigns[:redirect_path]).to eq(group_path(group))
    end

    context 'when user_sso_return_to is set in session' do
      let(:oauth_redirect_url) { '/oauth/authorize?client_id=test-app' }

      it 'redirect_path is taken from session instead of group_path' do
        session[:user_sso_return_to] = oauth_redirect_url

        get :saml, params: { group_id: group }

        expect(response).to have_gitlab_http_status(:ok)
        expect(assigns[:redirect_path]).to eq(oauth_redirect_url)
        expect(session[:user_sso_return_to]).to be_nil
      end

      it 'session takes precedence over redirect parameter' do
        session[:user_sso_return_to] = oauth_redirect_url

        get :saml, params: { group_id: group, redirect: '/some-other-path' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(assigns[:redirect_path]).to eq(oauth_redirect_url)
        expect(session[:user_sso_return_to]).to be_nil
      end
    end

    it 'passes group name to the view' do
      get :saml, params: { group_id: group }

      expect(assigns[:group_name]).to eq 'our-group'
    end

    it 'allows account unlinking' do
      create(:group_saml_identity, saml_provider: saml_provider, user: user)

      expect do
        delete :unlink, params: { group_id: group }
      end.to change { Identity.count }.by(-1)
    end

    context 'when SAML is disabled for the group' do
      before do
        saml_provider.update!(enabled: false)
      end

      it 'renders 404' do
        get :saml, params: { group_id: group }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'still allows account unlinking' do
        create(:group_saml_identity, saml_provider: saml_provider, user: user)

        expect do
          delete :unlink, params: { group_id: group }
        end.to change { Identity.count }.by(-1)
      end
    end

    context 'when SAML trial has expired' do
      before do
        create(:group_saml_identity, saml_provider: saml_provider, user: user)
        stub_licensed_features(group_saml: false)
      end

      it 'DELETE /unlink still allows account unlinking' do
        expect do
          delete :unlink, params: { group_id: group }
        end.to change { Identity.count }.by(-1)
      end

      it 'GET /saml renders 404' do
        get :saml, params: { group_id: group }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not signed in' do
      it 'acts as route not found' do
        sign_out(user)

        get :saml, params: { group_id: group }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when group has moved' do
      let(:redirect_route) { group.redirect_routes.create!(path: 'old-path') }

      it 'redirects to new location' do
        get :saml, params: { group_id: redirect_route.path }

        expect(response).to redirect_to(sso_group_saml_providers_path(group))
      end
    end

    context 'when current user has a SAML provider configured' do
      let(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }
      let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }

      before do
        sign_out(user)
        sign_in(identity.user)
      end

      it 'renders `devise_empty` template' do
        get :saml, params: { group_id: group }

        expect(response).to render_template('devise_empty')
      end
    end

    context 'when current user does not have a SAML provider configured' do
      it 'renders `devise` template' do
        get :saml, params: { group_id: group }

        expect(response).to render_template('devise')
      end

      context 'with a redirect parameter' do
        render_views

        it 'includes redirect path in the Authorize button' do
          redirect_path = '/our-group/project/-/work_items/1'

          get :saml, params: { group_id: group, redirect: redirect_path }

          expect(assigns(:redirect_path)).to eq(redirect_path)

          doc = Nokogiri::HTML.parse(response.body)
          button = doc.at_css('[data-testid="saml-sso-signin-button"]')
          expect(button).to be_present
          expect(button['href']).to include("redirect_to=#{CGI.escape(redirect_path)}")
        end
      end
    end
  end

  context 'saml_provider is unconfigured for the group' do
    context 'when user cannot configure Group SAML' do
      it 'renders 404' do
        get :saml, params: { group_id: group }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user can admin group_saml' do
      before do
        group.add_owner(user)
      end

      it 'redirects to the Group SAML config page' do
        get :saml, params: { group_id: group }

        expect(response).to redirect_to(group_saml_providers_path)
      end

      it 'sets a flash message explaining that setup is required' do
        get :saml, params: { group_id: group }

        expect(flash[:notice]).to match(/not been configured/)
      end
    end
  end

  context 'group does not exist' do
    it 'renders 404' do
      get :saml, params: { group_id: 'not-a-group' }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when user is not signed in' do
      it 'acts as route not found' do
        sign_out(user)

        get :saml, params: { group_id: 'not-a-group' }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

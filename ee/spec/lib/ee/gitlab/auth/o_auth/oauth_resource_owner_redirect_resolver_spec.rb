# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::OAuth::OauthResourceOwnerRedirectResolver, feature_category: :system_access do
  let(:resolver) { described_class.new(request, session) }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:session) { {} }
  let(:saml_provider) { create(:saml_provider, enforced_sso: true) }
  let(:group) { saml_provider.group }
  let(:child_group) { create(:group, parent: group) }

  before do
    allow(Gitlab).to receive(:ee?).and_return(true)
    allow(resolver).to receive(:new_user_session_url).and_return('/login')
    allow(request).to receive(:fullpath).and_return('/oauth/authorize?client_id=123')
  end

  describe '#resolve_redirect_url' do
    subject(:resolve_redirect_url) { resolver.resolve_redirect_url }

    context 'when root_namespace_id is blank' do
      before do
        allow(request).to receive(:query_parameters).and_return({ 'root_namespace_id' => nil })
      end

      it 'returns new_user_session_url' do
        expect(resolve_redirect_url).to eq('/login')
      end

      it 'does not query for group' do
        expect(::Group).not_to receive(:find_by_id)
        resolve_redirect_url
      end

      it 'does not set user_sso_return_to in session' do
        resolve_redirect_url
        expect(session[:user_sso_return_to]).to be_nil
      end
    end

    context 'when namespace is found' do
      before do
        allow(request).to receive(:query_parameters).and_return({ 'root_namespace_id' => group.id.to_s })
      end

      context 'when found namespace is a Group' do
        context 'when feature flag is enabled' do
          context 'when SSO URL is present' do
            let(:sso_url) { "/groups/#{group.full_path}/-/saml/sso" }

            before do
              allow(resolver).to receive(:build_sso_redirect_url)
                .with(group)
                .and_return(sso_url)
            end

            it 'returns the SSO URL' do
              expect(resolver).to receive(:build_sso_redirect_url).with(group)
              expect(resolve_redirect_url).to eq(sso_url)
            end

            it 'sets user_sso_return_to in session' do
              resolve_redirect_url
              expect(session[:user_sso_return_to]).to eq('/oauth/authorize?client_id=123')
            end
          end

          context 'when SSO URL is nil' do
            before do
              allow(resolver).to receive(:build_sso_redirect_url)
                .with(group)
                .and_return(nil)
            end

            it 'returns new_user_session_url' do
              expect(resolve_redirect_url).to eq('/login')
            end

            it 'does not set user_sso_return_to in session' do
              resolve_redirect_url
              expect(session[:user_sso_return_to]).to be_nil
            end
          end

          context 'when SSO URL is empty string' do
            before do
              allow(resolver).to receive(:build_sso_redirect_url)
                .with(group)
                .and_return('')
            end

            it 'returns new_user_session_url' do
              expect(resolve_redirect_url).to eq('/login')
            end

            it 'does not set user_sso_return_to in session' do
              resolve_redirect_url
              expect(session[:user_sso_return_to]).to be_nil
            end
          end
        end
      end

      context 'when found namespace is not a Group' do
        let(:user_namespace) { create(:user_namespace) }

        before do
          allow(request).to receive(:query_parameters).and_return({ 'root_namespace_id' => user_namespace.id.to_s })
        end

        it 'returns new_user_session_url' do
          expect(resolve_redirect_url).to eq('/login')
        end

        it 'does not set user_sso_return_to in session' do
          resolve_redirect_url
          expect(session[:user_sso_return_to]).to be_nil
        end
      end
    end

    context 'when namespace is not found' do
      before do
        allow(request).to receive(:query_parameters).and_return({ 'root_namespace_id' => '999999' })
      end

      it 'returns new_user_session_url' do
        expect(resolve_redirect_url).to eq('/login')
      end

      it 'does not set user_sso_return_to in session' do
        resolve_redirect_url
        expect(session[:user_sso_return_to]).to be_nil
      end
    end

    context 'with child namespace path' do
      before do
        allow(request).to receive(:query_parameters).and_return({ 'root_namespace_id' => child_group.id.to_s })
        allow(resolver).to receive(:build_sso_redirect_url)
          .with(child_group)
          .and_return('/sso-url')
      end

      it 'works with nested groups' do
        expect(resolve_redirect_url).to eq('/sso-url')
      end

      it 'sets user_sso_return_to in session' do
        resolve_redirect_url
        expect(session[:user_sso_return_to]).to eq('/oauth/authorize?client_id=123')
      end
    end

    context 'with the ChatGPT connector installation flow' do
      let_it_be(:connector_redirect_uri) { 'https://chatgpt.com/connector_platform_oauth_redirect' }
      let_it_be(:connector_application) do
        create(:oauth_application, :without_owner, redirect_uri: connector_redirect_uri)
      end

      before do
        allow(::Gitlab::Auth::OAuth::Provider).to receive(:enabled?).with('chatgpt').and_return(true)
      end

      context 'when the group enforces SSO' do
        before do
          allow(request).to receive(:query_parameters).and_return(
            { 'root_namespace_id' => group.id.to_s, 'target_flow' => 'chatgpt_siwc',
              'client_id' => connector_application.uid,
              'redirect_uri' => connector_redirect_uri }
          )
          allow(resolver).to receive(:build_sso_redirect_url).with(group).and_return('/sso-url')
        end

        it 'redirects to SSO, taking precedence over the ChatGPT flow' do
          expect(resolve_redirect_url).to eq('/sso-url')
        end
      end

      context 'when the group does not enforce SSO' do
        before do
          allow(request).to receive(:query_parameters).and_return(
            { 'root_namespace_id' => group.id.to_s, 'target_flow' => 'chatgpt_siwc',
              'client_id' => connector_application.uid,
              'redirect_uri' => connector_redirect_uri }
          )
          allow(resolver).to receive(:build_sso_redirect_url).with(group).and_return(nil)
        end

        it 'falls back to super and stores the ChatGPT provider in the session' do
          expect(resolve_redirect_url).to eq('/login')
          expect(session[::Authn::ProviderSignInRedirect::SESSION_KEY]).to eq('chatgpt')
        end
      end

      context 'when there is no root_namespace_id' do
        before do
          allow(request).to receive(:query_parameters).and_return(
            { 'target_flow' => 'chatgpt_siwc', 'client_id' => connector_application.uid,
              'redirect_uri' => connector_redirect_uri }
          )
        end

        it 'reaches super and stores the ChatGPT provider in the session' do
          expect(resolve_redirect_url).to eq('/login')
          expect(session[::Authn::ProviderSignInRedirect::SESSION_KEY]).to eq('chatgpt')
        end
      end
    end
  end

  describe '#build_sso_redirect_url' do
    subject(:build_sso_redirect_url) { resolver.send(:build_sso_redirect_url, group) }

    let(:sso_redirector) { instance_double(::RoutableActions::SsoEnforcementRedirect) }
    let(:expected_url) { "/groups/#{group.full_path}/-/saml/sso" }

    before do
      allow(request).to receive(:query_parameters).and_return({ 'root_namespace_id' => group.id.to_s })
      allow(::RoutableActions::SsoEnforcementRedirect)
        .to receive(:new)
        .with(group, group.full_path)
        .and_return(sso_redirector)

      allow(group).to receive(:enforced_sso?).and_return(true)
    end

    context 'when redirector returns SSO url' do
      before do
        allow(sso_redirector).to receive(:sso_redirect_url).and_return(expected_url)
      end

      it 'returns the SSO redirect URL' do
        expect(build_sso_redirect_url).to eq(expected_url)
      end
    end

    context 'when redirector returns nil' do
      before do
        allow(sso_redirector).to receive(:sso_redirect_url).and_return(nil)
      end

      it 'returns nil' do
        expect(build_sso_redirect_url).to be_nil
      end
    end

    context 'when group does not have enforced SSO' do
      before do
        allow(group).to receive(:enforced_sso?).and_return(false)
      end

      it 'returns nil' do
        expect(build_sso_redirect_url).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::Strategies::GeoAwareRedirectUri, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:app) { ->(_env) { [200, {}, ['OK']] } }
  let(:configured_redirect_uri) { 'https://primary.example.com/users/auth/openid_connect/callback' }

  let(:strategy) do
    OmniAuth::Strategies::OpenIDConnect.new(
      app,
      issuer: 'https://provider.example.com',
      client_options: {
        identifier: 'gitlab-client',
        secret: 'secret',
        redirect_uri: configured_redirect_uri
      }
    )
  end

  let(:env) do
    Rack::MockRequest.env_for('https://secondary.example.com/users/auth/openid_connect').tap do |env|
      env['warden'] = instance_double(Warden::Proxy, user: nil, authenticate: nil)
    end
  end

  subject(:redirect_uri) do
    strategy.instance_variable_set(:@env, env)
    strategy.send(:redirect_uri)
  end

  context 'when Geo is not enabled' do
    before do
      allow(::Gitlab::Geo).to receive(:enabled?).and_return(false)
    end

    it 'returns the configured redirect_uri' do
      expect(redirect_uri).to eq(configured_redirect_uri)
    end
  end

  context 'when Geo is enabled' do
    let_it_be(:primary_node) { create(:geo_node, :primary, url: 'https://primary.example.com') }
    let_it_be(:secondary_node) { create(:geo_node, url: 'https://secondary.example.com') }

    before do
      stub_current_geo_node(primary_node)
    end

    context 'when the request is not proxied from a secondary site' do
      it 'returns the configured redirect_uri' do
        expect(redirect_uri).to eq(configured_redirect_uri)
      end
    end

    context 'when the request is proxied from a secondary site' do
      before do
        stub_proxied_site(secondary_node)
      end

      it 'derives the redirect_uri from the originating site' do
        expect(redirect_uri).to eq('https://secondary.example.com/users/auth/openid_connect/callback')
      end

      context 'when the geo_oidc_proxied_redirect_uri feature flag is disabled' do
        before do
          stub_feature_flags(geo_oidc_proxied_redirect_uri: false)
        end

        it 'returns the configured redirect_uri' do
          expect(redirect_uri).to eq(configured_redirect_uri)
        end
      end

      context 'when the request carries an application-level redirect_uri param' do
        let(:env) do
          Rack::MockRequest.env_for(
            'https://secondary.example.com/users/auth/openid_connect?redirect_uri=https%3A%2F%2Fsecondary.example.com%2Fdashboard'
          ).tap do |env|
            env['warden'] = instance_double(Warden::Proxy, user: nil, authenticate: nil)
          end
        end

        it 'round-trips the param on the derived redirect_uri' do
          expect(redirect_uri).to eq(
            'https://secondary.example.com/users/auth/openid_connect/callback' \
              "?redirect_uri=#{CGI.escape('https://secondary.example.com/dashboard')}"
          )
        end
      end

      context 'when sites use a unified URL' do
        let_it_be(:unified_secondary) { create(:geo_node, url: 'https://primary.example.com') }

        let(:env) do
          Rack::MockRequest.env_for('https://primary.example.com/users/auth/openid_connect').tap do |env|
            env['warden'] = instance_double(Warden::Proxy, user: nil, authenticate: nil)
          end
        end

        before do
          stub_proxied_site(unified_secondary)
        end

        it 'derives a redirect_uri equal to the configured one' do
          expect(redirect_uri).to eq(configured_redirect_uri)
        end
      end
    end
  end
end

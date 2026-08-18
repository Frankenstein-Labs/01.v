# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::RefreshTokenService, feature_category: :workflow_catalog do
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, :with_oauth) }
  let_it_be(:user) { create(:user) }

  let(:new_expires_at_unix) { 1.hour.from_now.to_i }
  let(:new_access_token) do
    instance_double(OAuth2::AccessToken, token: 'new-access-token', refresh_token: 'new-refresh-token',
      expires_at: new_expires_at_unix)
  end

  let(:existing_token) { instance_double(OAuth2::AccessToken, refresh!: new_access_token) }
  let(:oauth_client) { instance_double(OAuth2::Client) }
  let(:registration) { instance_double(::Gitlab::Oauth::DynamicRegistrationClient) }

  subject(:result) do
    described_class.new(mcp_server: mcp_server, current_user: user).execute
  end

  before do
    allow(::Gitlab::Oauth::DynamicRegistrationClient).to receive(:new).and_return(registration)
    allow(OAuth2::Client).to receive(:new).and_return(oauth_client)
    allow(OAuth2::AccessToken).to receive(:new).and_return(existing_token)
    allow(registration).to receive_messages(
      discover_auth_server_url: 'https://auth.example.com',
      discover_metadata: {
        'authorization_endpoint' => 'https://auth.example.com/oauth/authorize',
        'token_endpoint' => 'https://auth.example.com/oauth/token'
      }
    )
  end

  describe '#execute' do
    context 'when the user has no token record' do
      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('No token found for this MCP server')
      end
    end

    context 'when the user has a token record but no refresh token' do
      let_it_be(:mcp_server_user) do
        create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user, refresh_token: nil)
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('No refresh token available')
      end
    end

    context 'when the user has a valid refresh token' do
      let_it_be(:mcp_server_user) do
        create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user,
          token: 'old-access-token', refresh_token: 'old-refresh-token')
      end

      it 'returns success with the new token in the payload' do
        expect(result).to be_success
        expect(result.payload[:token]).to eq('new-access-token')
      end

      it 'updates the stored access token' do
        result

        expect(mcp_server_user.reload.token).to eq('new-access-token')
      end

      it 'updates the stored refresh token when a new one is returned' do
        result

        expect(mcp_server_user.reload.refresh_token).to eq('new-refresh-token')
      end

      it 'updates expires_at from the new token' do
        result

        expect(mcp_server_user.reload.expires_at).to be_within(1.second).of(Time.zone.at(new_expires_at_unix))
      end

      context 'when the server does not return a new refresh token' do
        let(:new_access_token) do
          instance_double(OAuth2::AccessToken, token: 'new-access-token', refresh_token: nil,
            expires_at: new_expires_at_unix)
        end

        it 'retains the existing refresh token' do
          result

          expect(mcp_server_user.reload.refresh_token).to eq('old-refresh-token')
        end
      end

      context 'when the new token has no expiry' do
        let(:new_access_token) do
          instance_double(OAuth2::AccessToken, token: 'new-access-token', refresh_token: 'new-refresh-token',
            expires_at: nil)
        end

        it 'sets expires_at to nil' do
          result

          expect(mcp_server_user.reload.expires_at).to be_nil
        end
      end

      context 'when the token refresh call raises an OAuth2::Error' do
        before do
          fake_response = instance_double(Faraday::Response, headers: {}, body: '', status: 401)
          allow(existing_token).to receive(:refresh!).and_raise(
            OAuth2::Error.new(OAuth2::Response.new(fake_response))
          )
        end

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to include('Failed to refresh token')
        end

        it 'does not update the stored token' do
          result

          expect(mcp_server_user.reload.token).to eq('old-access-token')
        end
      end

      context 'when saving the refreshed token fails' do
        before do
          allow_next_found_instance_of(Ai::Catalog::McpServersUser) do |instance|
            allow(instance).to receive(:update).and_return(false)
          end
        end

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Failed to store refreshed token')
        end
      end
    end
  end
end

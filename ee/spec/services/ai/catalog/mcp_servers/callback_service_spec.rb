# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::CallbackService, feature_category: :workflow_catalog do
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, :with_oauth) }
  let_it_be(:user) { create(:user) }

  let(:code) { 'auth-code-123' }
  let(:redirect_uri) { 'https://gitlab.example.com/oauth/mcp_connectors/callback' }
  let(:expires_at_unix) { 1.hour.from_now.to_i }
  let(:access_token) do
    instance_double(OAuth2::AccessToken, token: 'access-token', refresh_token: 'refresh-token',
      expires_at: expires_at_unix)
  end

  let(:auth_code) { instance_double(OAuth2::Strategy::AuthCode, get_token: access_token) }
  let(:oauth_client) { instance_double(OAuth2::Client, auth_code: auth_code) }
  let(:registration) { instance_double(::Gitlab::Oauth::DynamicRegistrationClient) }

  let(:code_verifier) { nil }

  subject(:result) do
    described_class.new(
      mcp_server: mcp_server,
      current_user: user,
      code: code,
      redirect_uri: redirect_uri,
      code_verifier: code_verifier
    ).execute
  end

  before do
    allow(::Gitlab::Oauth::DynamicRegistrationClient).to receive(:new).and_return(registration)
    allow(OAuth2::Client).to receive(:new).and_return(oauth_client)
    allow(registration).to receive_messages(
      discover_auth_server_url: 'https://auth.example.com',
      discover_metadata: {
        'authorization_endpoint' => 'https://auth.example.com/oauth/authorize',
        'token_endpoint' => 'https://auth.example.com/oauth/token'
      }
    )
  end

  describe '#execute' do
    context 'when the user has no existing token' do
      it 'creates a new mcp_servers_user record' do
        expect { result }.to change { mcp_server.mcp_servers_users.count }.by(1)
      end

      it 'stores the access token, refresh token, and expires_at' do
        result

        mcp_server_user = mcp_server.mcp_servers_users.find_by_user_id(user.id)
        expect(mcp_server_user.token).to eq('access-token')
        expect(mcp_server_user.refresh_token).to eq('refresh-token')
        expect(mcp_server_user.expires_at).to be_within(1.second).of(Time.zone.at(expires_at_unix))
      end

      context 'when the access token has no expiry' do
        let(:access_token) do
          instance_double(OAuth2::AccessToken, token: 'access-token', refresh_token: 'refresh-token', expires_at: nil)
        end

        it 'stores nil for expires_at' do
          result

          mcp_server_user = mcp_server.mcp_servers_users.find_by_user_id(user.id)
          expect(mcp_server_user.expires_at).to be_nil
        end
      end

      it 'returns success' do
        expect(result).to be_success
      end

      it 'emits a mcp_server_oauth_token_stored audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'mcp_server_oauth_token_stored',
            author: user,
            scope: user,
            target: user,
            message: "Connected to MCP server: #{mcp_server.name}",
            additional_details: hash_including(
              mcp_server_id: mcp_server.id,
              mcp_server_name: mcp_server.name
            )
          )
        )

        result
      end

      context 'when the audit raises a StandardError' do
        let(:audit_error) { StandardError.new('audit failure') }

        before do
          allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
        end

        it 'tracks the exception with error tracking' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            audit_error,
            mcp_server_id: mcp_server.id
          )

          result
        end

        it 'still returns success' do
          allow(Gitlab::ErrorTracking).to receive(:track_exception)

          expect(result).to be_success
        end
      end
    end

    context 'when the user already has a token' do
      let_it_be(:mcp_server_user) do
        create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user)
      end

      it 'does not create a new record' do
        expect { result }.not_to change { mcp_server.mcp_servers_users.count }
      end

      it 'updates the existing tokens and expires_at' do
        result

        mcp_server_user.reload
        expect(mcp_server_user.token).to eq('access-token')
        expect(mcp_server_user.refresh_token).to eq('refresh-token')
        expect(mcp_server_user.expires_at).to be_within(1.second).of(Time.zone.at(expires_at_unix))
      end

      it 'returns success' do
        expect(result).to be_success
      end

      it 'emits a mcp_server_oauth_token_stored audit event on token refresh' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'mcp_server_oauth_token_stored')
        )

        result
      end
    end

    context 'when a code_verifier is provided (PKCE)' do
      let(:code_verifier) { 'pkce-verifier-value' }

      it 'passes the code_verifier to the token exchange' do
        expect(auth_code).to receive(:get_token).with(
          code, redirect_uri: redirect_uri, code_verifier: code_verifier
        ).and_return(access_token)

        result
      end
    end

    context 'when no code_verifier is provided' do
      it 'does not include code_verifier in the token exchange' do
        expect(auth_code).to receive(:get_token).with(
          code, redirect_uri: redirect_uri
        ).and_return(access_token)

        result
      end
    end

    context 'when token exchange fails' do
      before do
        fake_response = instance_double(Faraday::Response, headers: {}, body: '', status: 401)
        allow(auth_code).to receive(:get_token).and_raise(
          OAuth2::Error.new(OAuth2::Response.new(fake_response))
        )
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to include('Failed to connect to MCP server')
      end

      it 'does not create a mcp_servers_user record' do
        expect { result }.not_to change { mcp_server.mcp_servers_users.count }
      end
    end

    context 'when storing the token fails' do
      before do
        allow(mcp_server.mcp_servers_users).to receive(:create).and_return(
          instance_double(Ai::Catalog::McpServersUser, persisted?: false)
        )
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Failed to store token')
      end

      it 'does not emit an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        result
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::ConnectService, feature_category: :workflow_catalog do
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, :with_oauth) }

  let(:redirect_uri) { 'https://gitlab.example.com/oauth/mcp_connectors/callback' }
  let(:return_to) { '/dashboard' }
  let(:authorization_url) { 'https://auth.example.com/oauth/authorize?client_id=x&state=y' }
  let(:metadata) { { 'authorization_endpoint' => 'https://auth.example.com/oauth/authorize', 'issuer' => 'https://auth.example.com' } }
  let(:resource_metadata) { nil }
  let(:registration) { instance_double(::Gitlab::Oauth::DynamicRegistrationClient) }

  subject(:result) do
    described_class.new(mcp_server: mcp_server, redirect_uri: redirect_uri, return_to: return_to).execute
  end

  before do
    allow(::Gitlab::Oauth::DynamicRegistrationClient).to receive(:new).and_return(registration)
    allow(registration).to receive_messages(
      generate_pkce: { code_verifier: 'test-verifier', code_challenge: 'test-challenge' },
      discover_resource_metadata: resource_metadata,
      discover_metadata: metadata,
      build_authorization_url: authorization_url
    )
  end

  describe '#execute' do
    context 'when the MCP server does not use OAuth' do
      let_it_be(:mcp_server) { create(:ai_catalog_mcp_server) }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('This MCP server does not use OAuth authentication')
      end
    end

    context 'when the MCP server uses OAuth' do
      it 'returns success with the authorization URL from the registration service' do
        expect(result).to be_success
        expect(result.payload[:authorization_url]).to eq(authorization_url)
      end

      it 'passes required params including code_challenge and issuer to build_authorization_url' do
        expect(registration).to receive(:build_authorization_url).with(
          authorization_endpoint: metadata['authorization_endpoint'],
          client_id: mcp_server.oauth_client_id,
          redirect_uri: redirect_uri,
          state: a_string_matching(/.+/),
          scope: nil,
          code_challenge: 'test-challenge',
          issuer: metadata['issuer']
        ).and_return(authorization_url)

        result
      end

      context 'when the resource metadata advertises scopes_supported' do
        let(:resource_metadata) do
          { 'scopes_supported' => ['https://www.googleapis.com/auth/compute'] }
        end

        it 'passes the joined scopes to build_authorization_url' do
          expect(registration).to receive(:build_authorization_url).with(
            hash_including(scope: 'https://www.googleapis.com/auth/compute')
          ).and_return(authorization_url)

          result
        end
      end

      it 'encodes the mcp_server_id and return_to into the state parameter' do
        expect(registration).to receive(:build_authorization_url) do |**kwargs|
          decoded_state = ::Gitlab::Oauth::ClientState.from_state(kwargs[:state])
          expect(decoded_state[:mcp_server_id]).to eq(mcp_server.id)
          expect(decoded_state.return_to).to eq(return_to)
          authorization_url
        end

        result
      end

      it 'does not include code_verifier in the state parameter' do
        expect(registration).to receive(:build_authorization_url) do |**kwargs|
          decoded_state = ::Gitlab::Oauth::ClientState.from_state(kwargs[:state])
          expect(decoded_state[:code_verifier]).to be_nil
          authorization_url
        end

        result
      end

      it 'returns the code_verifier in the payload for session storage' do
        expect(result.payload[:code_verifier]).to eq('test-verifier')
      end

      context 'when the MCP server has no OAuth client registered yet' do
        let(:mcp_server) { create(:ai_catalog_mcp_server, auth_type: :oauth) }

        it 'registers the OAuth client and stores the credentials' do
          allow(registration).to receive(:register_client)
            .and_return({ client_id: 'new-client-id', client_secret: 'new-client-secret' })

          expect { result }.to change { mcp_server.reload.oauth_client_id }.to('new-client-id')
          expect(result).to be_success
        end

        context 'when the registration endpoint is protected (401/403)' do
          it 'returns an error asking to configure the client ID manually' do
            allow(registration).to receive(:register_client)
              .and_raise(::Gitlab::Oauth::DynamicRegistrationClient::ProtectedRegistrationError)

            expect(result).to be_error
            expect(result.message).to include('does not support dynamic client registration')
            expect(result.message).to include('configure the OAuth client ID')
          end
        end
      end

      context 'when metadata discovery fails' do
        before do
          allow(registration).to receive(:discover_metadata)
            .and_raise(StandardError, 'connection refused')
        end

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to include('connection refused')
        end
      end
    end
  end
end

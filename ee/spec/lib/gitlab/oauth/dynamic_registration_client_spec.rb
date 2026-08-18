# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Oauth::DynamicRegistrationClient, feature_category: :workflow_catalog do
  let(:server_url) { 'https://mcp.example.com/mcp' }
  let(:client_name) { 'GitLab Integration' }
  let(:redirect_uris) { ['https://gitlab.example.com/oauth/mcp_connectors/callback'] }

  subject(:service) do
    described_class.new(server_url: server_url, client_name: client_name, redirect_uris: redirect_uris)
  end

  describe '#discover_resource_metadata' do
    # Per RFC 9728 Section 3.1, the well-known URL is built by inserting
    # /.well-known/oauth-protected-resource between the host and path components.
    # For server_url 'https://mcp.example.com/mcp' the correct URL is:
    #   https://mcp.example.com/.well-known/oauth-protected-resource/mcp
    let(:well_known_url) { 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp' }
    let(:valid_metadata) do
      {
        resource: server_url,
        authorization_servers: ['https://auth.example.com'],
        scopes_supported: ['mcp:connect']
      }
    end

    context 'when the metadata response is valid (resource matches and authorization_servers present)' do
      before do
        stub_request(:get, well_known_url)
          .to_return(
            status: 200,
            body: valid_metadata.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the parsed resource metadata' do
        result = service.discover_resource_metadata

        expect(result['authorization_servers']).to eq(['https://auth.example.com'])
        expect(result['scopes_supported']).to eq(['mcp:connect'])
      end

      it 'fetches the path-based well-known URL (RFC 9728 §3.1)' do
        service.discover_resource_metadata

        expect(WebMock).to have_requested(:get, well_known_url)
      end
    end

    context 'when the resource field does not match the server_url (RFC 9728 §3.3)' do
      before do
        stub_request(:get, well_known_url)
          .to_return(
            status: 200,
            body: { resource: 'https://other.example.com/mcp',
                    authorization_servers: ['https://auth.example.com'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil and does not use the unvalidated metadata' do
        expect(service.discover_resource_metadata).to be_nil
      end
    end

    context 'when the metadata endpoint returns no authorization_servers' do
      before do
        stub_request(:get, well_known_url)
          .to_return(
            status: 200,
            body: { resource: server_url }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil' do
        expect(service.discover_resource_metadata).to be_nil
      end
    end

    context 'when the metadata endpoint is not found' do
      before do
        stub_request(:get, well_known_url).to_return(status: 404, body: '')
      end

      it 'returns nil' do
        expect(service.discover_resource_metadata).to be_nil
      end
    end

    context 'when the server URL has no path component' do
      let(:server_url) { 'https://mcp.example.com' }

      before do
        stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource')
          .to_return(
            status: 200,
            body: { resource: server_url, authorization_servers: ['https://auth.example.com'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'uses the path-less well-known URL and returns the metadata' do
        result = service.discover_resource_metadata

        expect(result['authorization_servers']).to eq(['https://auth.example.com'])
      end
    end

    context 'when the server URL has a non-standard port' do
      let(:server_url) { 'https://mcp.example.com:8443/mcp' }

      before do
        stub_request(:get, 'https://mcp.example.com:8443/.well-known/oauth-protected-resource/mcp')
          .to_return(status: 404, body: '')
      end

      it 'returns nil' do
        expect(service.discover_resource_metadata).to be_nil
      end
    end

    context 'when the server URL is invalid' do
      let(:server_url) { 'not a valid url' }

      it 'raises DiscoveryError' do
        expect { service.discover_resource_metadata }.to raise_error(
          described_class::DiscoveryError, /Failed to discover resource metadata/
        )
      end
    end

    context 'when the well-known URL is blocked' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'URL is blocked')
      end

      it 'raises DiscoveryError' do
        expect { service.discover_resource_metadata }.to raise_error(
          described_class::DiscoveryError, /Blocked URL/
        )
      end
    end

    context 'when the HTTP request fails' do
      before do
        stub_request(:get, well_known_url).to_raise(SocketError.new('connection refused'))
      end

      it 'raises DiscoveryError' do
        expect { service.discover_resource_metadata }.to raise_error(
          described_class::DiscoveryError, /Failed to discover resource metadata/
        )
      end
    end
  end

  describe '#discover_auth_server_url' do
    context 'when resource metadata is available' do
      before do
        allow(service).to receive(:discover_resource_metadata).and_return(
          'resource' => server_url,
          'authorization_servers' => ['https://auth.example.com']
        )
      end

      it 'returns the first authorization server from the resource metadata' do
        expect(service.discover_auth_server_url).to eq('https://auth.example.com')
      end
    end

    context 'when resource metadata is unavailable (returns nil)' do
      before do
        allow(service).to receive(:discover_resource_metadata).and_return(nil)
      end

      it 'falls back to the base URL of the server' do
        expect(service.discover_auth_server_url).to eq('https://mcp.example.com')
      end
    end

    context 'when the server URL has a non-standard port and resource metadata is unavailable' do
      let(:server_url) { 'https://mcp.example.com:8443/mcp' }

      before do
        allow(service).to receive(:discover_resource_metadata).and_return(nil)
      end

      it 'includes the port in the fallback base URL' do
        expect(service.discover_auth_server_url).to eq('https://mcp.example.com:8443')
      end
    end

    context 'when called multiple times on the same instance' do
      before do
        allow(service).to receive(:discover_resource_metadata).and_return(
          'resource' => server_url,
          'authorization_servers' => ['https://auth.example.com']
        )
      end

      it 'only performs discovery once' do
        2.times { service.discover_auth_server_url }

        expect(service).to have_received(:discover_resource_metadata).once
      end
    end

    context 'when resource metadata discovery raises DiscoveryError' do
      before do
        allow(service).to receive(:discover_resource_metadata)
          .and_raise(described_class::DiscoveryError, 'connection refused')
      end

      it 'propagates the DiscoveryError' do
        expect { service.discover_auth_server_url }.to raise_error(
          described_class::DiscoveryError, 'connection refused'
        )
      end
    end

    context 'when an unexpected StandardError occurs after resource metadata is fetched' do
      before do
        allow(service).to receive(:discover_resource_metadata).and_return(
          'resource' => server_url,
          'authorization_servers' => nil
        )
      end

      it 'wraps the error in a DiscoveryError' do
        expect { service.discover_auth_server_url }.to raise_error(
          described_class::DiscoveryError, /Failed to discover authorization server/
        )
      end
    end
  end

  describe '#discover_metadata' do
    let(:auth_server_url) { 'https://auth.example.com' }
    let(:metadata) do
      {
        'issuer' => auth_server_url,
        'authorization_endpoint' => "#{auth_server_url}/oauth/authorize",
        'token_endpoint' => "#{auth_server_url}/oauth/token",
        'registration_endpoint' => "#{auth_server_url}/oauth/register"
      }
    end

    context 'when an auth_server_url is provided' do
      before do
        stub_request(:get, "#{auth_server_url}/.well-known/oauth-authorization-server")
          .to_return(status: 200, body: metadata.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'fetches metadata from the given auth server without auto-discovery' do
        expect(service).not_to receive(:discover_auth_server_url)

        result = service.discover_metadata(auth_server_url)

        expect(result['authorization_endpoint']).to eq("#{auth_server_url}/oauth/authorize")
        expect(result['token_endpoint']).to eq("#{auth_server_url}/oauth/token")
      end
    end

    context 'when the auth_server_url normalizes to a well-known URL (RFC 8414 §3.1)' do
      using RSpec::Parameterized::TableSyntax

      where(:input_auth_server_url, :expected_well_known_url) do
        'https://auth.example.com/'         | 'https://auth.example.com/.well-known/oauth-authorization-server'
        'https://auth.example.com/tenant1'  | 'https://auth.example.com/.well-known/oauth-authorization-server/tenant1'
        'https://auth.example.com/tenant1/' | 'https://auth.example.com/.well-known/oauth-authorization-server/tenant1'
      end

      with_them do
        before do
          stub_request(:get, expected_well_known_url)
            .to_return(status: 200, body: metadata.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'fetches the correctly normalized well-known URL' do
          service.discover_metadata(input_auth_server_url)

          expect(WebMock).to have_requested(:get, expected_well_known_url)
        end
      end
    end

    context 'when the auth_server_url is invalid' do
      let(:auth_server_url) { "https://auth.example.com/\x00" }

      it 'raises DiscoveryError' do
        expect { service.discover_metadata(auth_server_url) }.to raise_error(
          described_class::DiscoveryError, /Invalid authorization server URL/
        )
      end
    end

    context 'when no auth_server_url is provided' do
      before do
        # RFC 9728 Section 3.1: path-based well-known URL for server_url 'https://mcp.example.com/mcp'
        stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
          .to_return(
            status: 200,
            body: { resource: server_url, authorization_servers: [auth_server_url] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, "#{auth_server_url}/.well-known/oauth-authorization-server")
          .to_return(status: 200, body: metadata.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'auto-discovers the auth server and fetches its metadata' do
        result = service.discover_metadata

        expect(result['authorization_endpoint']).to eq("#{auth_server_url}/oauth/authorize")
      end
    end

    context 'when the metadata endpoint returns a non-success response' do
      before do
        stub_request(:get, "#{auth_server_url}/.well-known/oauth-authorization-server")
          .to_return(status: 404, body: '')
      end

      it 'raises DiscoveryError' do
        expect { service.discover_metadata(auth_server_url) }.to raise_error(
          described_class::DiscoveryError, /Failed to discover OAuth metadata/
        )
      end
    end

    context 'when the metadata URL is blocked' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'URL is blocked')
      end

      it 'raises DiscoveryError' do
        expect { service.discover_metadata(auth_server_url) }.to raise_error(
          described_class::DiscoveryError, /Blocked URL/
        )
      end
    end

    context 'when the HTTP request fails' do
      before do
        stub_request(:get, "#{auth_server_url}/.well-known/oauth-authorization-server")
          .to_raise(SocketError, 'connection refused')
      end

      it 'raises DiscoveryError' do
        expect { service.discover_metadata(auth_server_url) }.to raise_error(
          described_class::DiscoveryError, /Failed to discover OAuth metadata/
        )
      end
    end
  end

  describe '#register_client' do
    let(:registration_endpoint) { 'https://auth.example.com/oauth/register' }
    let(:metadata) { { 'registration_endpoint' => registration_endpoint } }
    let(:registration_response) do
      { 'client_id' => 'new-client-id', 'client_secret' => 'new-client-secret' }
    end

    context 'when metadata is provided' do
      it 'does not call discover_metadata' do
        stub_request(:post, registration_endpoint)
          .to_return(status: 201, body: registration_response.to_json,
            headers: { 'Content-Type' => 'application/json' })

        expect(service).not_to receive(:discover_metadata)

        service.register_client(metadata)
      end
    end

    context 'when no metadata is provided' do
      before do
        stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
          .to_return(
            status: 200,
            body: { resource: server_url, authorization_servers: ['https://auth.example.com'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server')
          .to_return(
            status: 200,
            body: metadata.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:post, registration_endpoint)
          .to_return(status: 201, body: registration_response.to_json,
            headers: { 'Content-Type' => 'application/json' })
      end

      it 'auto-discovers metadata and registers the client' do
        result = service.register_client

        expect(result[:client_id]).to eq('new-client-id')
      end
    end

    context 'when metadata has no registration_endpoint' do
      let(:metadata) { { 'authorization_endpoint' => 'https://auth.example.com/authorize' } }

      it 'raises RegistrationError' do
        expect { service.register_client(metadata) }.to raise_error(
          described_class::RegistrationError,
          'Dynamic client registration not supported by this server'
        )
      end
    end

    context 'when registration succeeds' do
      before do
        stub_request(:post, registration_endpoint)
          .to_return(status: 201, body: registration_response.to_json,
            headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns client_id and client_secret' do
        result = service.register_client(metadata)

        expect(result[:client_id]).to eq('new-client-id')
        expect(result[:client_secret]).to eq('new-client-secret')
      end

      it 'includes the full registration response in registration_data' do
        result = service.register_client(metadata)

        expect(result[:registration_data]).to eq(registration_response)
      end

      it 'posts JSON with client_name, redirect_uris, grant_types, and response_types' do
        service.register_client(metadata)

        expect(WebMock).to have_requested(:post, registration_endpoint).with(
          body: hash_including(
            'client_name' => client_name,
            'redirect_uris' => redirect_uris,
            'grant_types' => %w[authorization_code refresh_token],
            'response_types' => %w[code],
            'token_endpoint_auth_method' => 'client_secret_post'
          ),
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      context 'when the metadata advertises scopes_supported' do
        let(:metadata) do
          {
            'registration_endpoint' => registration_endpoint,
            'scopes_supported' => %w[mcp:connect]
          }
        end

        it 'uses the server-advertised scopes in the registration payload' do
          service.register_client(metadata)

          expect(WebMock).to have_requested(:post, registration_endpoint).with(
            body: hash_including('scope' => 'mcp:connect')
          )
        end
      end

      context 'when the metadata has no scopes_supported' do
        it 'omits the scope field from the registration payload' do
          service.register_client(metadata)

          expect(WebMock).to have_requested(:post, registration_endpoint).with(
            body: ->(body) { !::Gitlab::Json.safe_parse(body).key?('scope') }
          )
        end
      end

      context 'when an explicit scope is passed to the constructor' do
        subject(:service) do
          described_class.new(
            server_url: server_url, client_name: client_name,
            redirect_uris: redirect_uris, scope: 'custom:scope'
          )
        end

        it 'uses the explicit scope instead of the server-advertised one' do
          metadata_with_scopes = metadata.merge('scopes_supported' => %w[server:scope])

          service.register_client(metadata_with_scopes)

          expect(WebMock).to have_requested(:post, registration_endpoint).with(
            body: hash_including('scope' => 'custom:scope')
          )
        end
      end
    end

    context 'when the registration endpoint returns 401' do
      before do
        stub_request(:post, registration_endpoint).to_return(status: 401, body: 'Unauthorized')
      end

      it 'raises ProtectedRegistrationError' do
        expect { service.register_client(metadata) }.to raise_error(
          described_class::ProtectedRegistrationError,
          /Dynamic client registration requires authorization/
        )
      end

      it 'ProtectedRegistrationError is a subclass of RegistrationError' do
        expect(described_class::ProtectedRegistrationError).to be < described_class::RegistrationError
      end
    end

    context 'when the registration endpoint returns 403' do
      before do
        stub_request(:post, registration_endpoint).to_return(status: 403, body: 'Forbidden')
      end

      it 'raises ProtectedRegistrationError' do
        expect { service.register_client(metadata) }.to raise_error(
          described_class::ProtectedRegistrationError
        )
      end
    end

    context 'when the registration endpoint returns another error status' do
      before do
        stub_request(:post, registration_endpoint)
          .to_return(status: 400, body: 'invalid_client_metadata')
      end

      it 'raises RegistrationError with the response body' do
        expect { service.register_client(metadata) }.to raise_error(
          described_class::RegistrationError,
          /Client registration failed: invalid_client_metadata/
        )
      end
    end

    context 'when the registration URL is blocked' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'URL is blocked')
      end

      it 'raises RegistrationError' do
        expect { service.register_client(metadata) }.to raise_error(
          described_class::RegistrationError,
          /Cannot register client.*Blocked URL/
        )
      end
    end

    context 'when the HTTP request raises' do
      before do
        stub_request(:post, registration_endpoint).to_raise(SocketError.new('connection refused'))
      end

      it 'raises RegistrationError' do
        expect { service.register_client(metadata) }.to raise_error(
          described_class::RegistrationError,
          /Client registration failed: connection refused/
        )
      end
    end

    context 'when discovery fails (no metadata provided)' do
      before do
        stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
          .to_raise(SocketError.new('connection refused'))
      end

      it 'raises RegistrationError wrapping the discovery error' do
        expect { service.register_client }.to raise_error(
          described_class::RegistrationError,
          /Cannot register client/
        )
      end
    end
  end

  describe '#build_authorization_url' do
    let(:authorization_endpoint) { 'https://auth.example.com/oauth/authorize' }
    let(:client_id) { 'my-client-id' }
    let(:redirect_uri) { redirect_uris.first }
    let(:state) { 'opaque-state-token' }

    subject(:url) do
      service.build_authorization_url(
        authorization_endpoint: authorization_endpoint,
        client_id: client_id,
        redirect_uri: redirect_uri,
        state: state
      )
    end

    it 'returns a URL pointing at the authorization endpoint' do
      expect(URI.parse(url).host).to eq('auth.example.com')
      expect(URI.parse(url).path).to eq('/oauth/authorize')
    end

    it 'includes required OAuth parameters' do
      params = URI.decode_www_form(URI.parse(url).query).to_h

      expect(params['client_id']).to eq(client_id)
      expect(params['redirect_uri']).to eq(redirect_uri)
      expect(params['response_type']).to eq('code')
      expect(params['state']).to eq(state)
    end

    it 'includes prompt=consent to ensure a refresh token is returned' do
      params = URI.decode_www_form(URI.parse(url).query).to_h

      expect(params['prompt']).to eq('consent')
    end

    it 'does not include Google-specific access_type param' do
      params = URI.decode_www_form(URI.parse(url).query).to_h

      expect(params).not_to have_key('access_type')
    end

    context 'when no scope is set on the instance' do
      it 'includes scope as nil / empty in the query' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['scope']).to be_nil.or eq('')
      end
    end

    context 'when a scope is set on the instance' do
      subject(:service) do
        described_class.new(
          server_url: server_url, client_name: client_name,
          redirect_uris: redirect_uris, scope: 'mcp:connect'
        )
      end

      it 'includes the instance scope in the URL' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['scope']).to eq('mcp:connect')
      end
    end

    context 'when a scope is passed directly to the method' do
      subject(:url) do
        service.build_authorization_url(
          authorization_endpoint: authorization_endpoint,
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
          scope: 'override:scope'
        )
      end

      it 'uses the method-level scope over the instance scope' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['scope']).to eq('override:scope')
      end
    end

    context 'when the authorization endpoint host is accounts.google.com (no issuer given)' do
      let(:authorization_endpoint) { 'https://accounts.google.com/o/oauth2/v2/auth' }

      it 'includes access_type=offline' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['access_type']).to eq('offline')
      end

      it 'still includes prompt=consent' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['prompt']).to eq('consent')
      end
    end

    context 'when the issuer is the canonical Google issuer (https://accounts.google.com)' do
      subject(:url) do
        service.build_authorization_url(
          authorization_endpoint: authorization_endpoint,
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
          issuer: 'https://accounts.google.com'
        )
      end

      it 'detects Google via issuer and uses access_type=offline' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['access_type']).to eq('offline')
      end
    end

    context 'when the issuer is the legacy schemeless Google issuer (accounts.google.com)' do
      subject(:url) do
        service.build_authorization_url(
          authorization_endpoint: authorization_endpoint,
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
          issuer: 'accounts.google.com'
        )
      end

      it 'detects Google via legacy issuer and uses access_type=offline' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['access_type']).to eq('offline')
      end
    end

    context 'when a non-Google issuer is provided alongside a google-hosted endpoint' do
      subject(:url) do
        service.build_authorization_url(
          authorization_endpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
          issuer: 'https://other.provider.example.com'
        )
      end

      it 'trusts the issuer over the endpoint host and does not add access_type' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params).not_to have_key('access_type')
      end
    end

    context 'when a code_challenge is provided' do
      subject(:url) do
        service.build_authorization_url(
          authorization_endpoint: authorization_endpoint,
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
          code_challenge: 'test-challenge'
        )
      end

      it 'includes code_challenge and code_challenge_method=S256' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params['code_challenge']).to eq('test-challenge')
        expect(params['code_challenge_method']).to eq('S256')
      end
    end

    context 'when no code_challenge is provided' do
      it 'omits code_challenge and code_challenge_method' do
        params = URI.decode_www_form(URI.parse(url).query).to_h

        expect(params).not_to have_key('code_challenge')
        expect(params).not_to have_key('code_challenge_method')
      end
    end
  end

  describe '#generate_pkce' do
    subject(:pkce) { service.generate_pkce }

    it 'returns a code_verifier and code_challenge' do
      expect(pkce[:code_verifier]).to be_a(String).and be_present
      expect(pkce[:code_challenge]).to be_a(String).and be_present
    end

    it 'produces a valid S256 challenge from the verifier' do
      expected = Base64.urlsafe_encode64(
        OpenSSL::Digest::SHA256.digest(pkce[:code_verifier]),
        padding: false
      )

      expect(pkce[:code_challenge]).to eq(expected)
    end

    it 'generates a different verifier on each call' do
      expect(service.generate_pkce[:code_verifier]).not_to eq(service.generate_pkce[:code_verifier])
    end
  end
end

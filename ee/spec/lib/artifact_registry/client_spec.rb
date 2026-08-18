# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ArtifactRegistry::Client, feature_category: :artifact_registry do
  using RSpec::Parameterized::TableSyntax

  let(:base_url) { 'https://artifact-registry.example.test' }
  let(:slug) { 'my-group' }
  let(:name) { 'my-repo' }
  let(:token) { 'ar-bootstrap-token-value' }
  let(:jwt_credential) { 'fake-jwt-header-segment.fake-jwt-payload-segment.fake-jwt-signature-segment' }
  let(:current_user) { instance_double(User) }
  let(:token_exchange) { instance_double(ArtifactRegistry::TokenExchange, token_for: token) }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  let(:client) do
    described_class.new(base_url: base_url, current_user: current_user, token_exchange: token_exchange)
  end

  let(:repository_url) { "#{base_url}/api/v1/#{slug}/repositories/#{name}" }
  let(:repositories_url) { "#{base_url}/api/v1/#{slug}/repositories" }

  let(:retry_options) do
    described_class::RETRY_OPTIONS.merge(interval: 0, interval_randomness: 0, backoff_factor: 0)
  end

  let(:next_cursor) { 'eyJpZCI6MjB9' }
  let(:prev_cursor) { 'eyJpZCI6MTB9' }

  let(:repository_response) do
    {
      'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
      'name' => name,
      'format' => 'maven',
      'kind' => 'hosted',
      'visibility' => 'private',
      'description' => 'A hosted Maven repository',
      'artifacts_count' => 12,
      'downloads_count' => 340,
      'size_bytes' => 987_654,
      'created_at' => '2026-07-01T10:00:00Z',
      'last_updated_at' => '2026-07-02T11:30:00Z',
      'created_by' => '101',
      'updated_by' => '202'
    }
  end

  shared_examples 'rejecting an unexpected success body' do |status:, body:, body_class:|
    it "raises UnavailableError for a #{status} carrying a #{body_class} body", :aggregate_failures do
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
      stub_request(http_method, request_url).to_return(status: status, body: body, headers: json_headers)

      expect { perform }.to raise_error(described_class::UnavailableError, /unexpected success response/)
      expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
        instance_of(described_class::UnavailableError),
        hash_including(status: status, body_class: body_class)
      )
    end
  end

  shared_examples 'rejecting an invalid argument before any request' do
    it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
      request = stub_ar_list(body: list_response.to_json)

      expect { perform }.to raise_error(ArgumentError)
      expect(token_exchange).not_to have_received(:token_for)
      expect(request).not_to have_been_requested
    end
  end

  shared_examples 'a keyset artifact list read' do |list_segment:|
    it 'returns an empty page for an existing repository that holds no artifacts' do
      stub_ar_list(body: [].to_json)

      expect(perform.nodes).to eq([])
    end

    context 'with the keyset query parameters' do
      it 'forwards limit and cursor' do
        request = stub_request(:get, request_url)
          .with(query: { limit: '100', cursor: 'opaque-cursor' })
          .to_return(status: 200, body: list_response.to_json, headers: json_headers)

        perform_with(limit: 100, cursor: 'opaque-cursor')

        expect(request).to have_been_requested
      end

      it 'omits the query parameters that were not supplied, leaving the read on the contract sort' do
        stub_ar_list(body: list_response.to_json)

        perform

        expect(a_request(:get, request_url).with { |req| req.uri.query.blank? }).to have_been_made
      end
    end

    context 'when parsing the Link header for cursors' do
      it 'reads the next and prev cursors from the Link header', :aggregate_failures do
        next_url = "#{request_url}?limit=20&cursor=#{next_cursor}"
        prev_url = "#{request_url}?limit=20&cursor=#{prev_cursor}"
        stub_ar_list(
          body: list_response.to_json,
          headers: json_headers.merge('Link' => %(<#{next_url}>; rel="next", <#{prev_url}>; rel="prev"))
        )

        page = perform

        expect(page.next_cursor).to eq(next_cursor)
        expect(page.prev_cursor).to eq(prev_cursor)
      end

      it 'leaves both cursors nil when the response carries no Link header', :aggregate_failures do
        stub_ar_list(body: list_response.to_json)

        page = perform

        expect(page.next_cursor).to be_nil
        expect(page.prev_cursor).to be_nil
      end
    end

    context 'when AR returns 404' do
      it 'returns nil rather than raising' do
        stub_request(:get, request_url)
          .to_return(status: 404, body: error_envelope(code: 'not_found').to_json, headers: json_headers)

        expect(perform).to be_nil
      end

      it 'returns nil even when the 404 body is empty' do
        stub_request(:get, request_url).to_return(status: 404, body: '')

        expect(perform).to be_nil
      end

      it 'logs the envelope, so a path that drifted from AR is still diagnosable' do
        stub_request(:get, request_url).to_return(
          status: 404,
          body: error_envelope(code: 'not_found', message: 'repository not found', request_id: 'req-404').to_json,
          headers: json_headers
        )

        expect(Gitlab::ErrorTracking).to receive(:log_exception)
          .with(an_instance_of(described_class::ApiError), hash_including(slug: slug)) do |error, _context|
            expect(error.status).to eq(404)
            expect(error.code).to eq('not_found')
            expect(error.request_id).to eq('req-404')
          end

        expect(perform).to be_nil
      end
    end

    context 'when AR returns a mapped error status' do
      where(:status, :error_class) do
        401 | ArtifactRegistry::Client::AuthorizationError
        403 | ArtifactRegistry::Client::AuthorizationError
        429 | ArtifactRegistry::Client::UnavailableError
        500 | ArtifactRegistry::Client::UnavailableError
        503 | ArtifactRegistry::Client::UnavailableError
        400 | ArtifactRegistry::Client::ApiError
      end

      with_them do
        it 'raises the mapped exception and preserves the envelope request_id and status', :aggregate_failures do
          stub_request(:get, request_url).to_return(
            status: status,
            body: error_envelope(request_id: 'req-list-id').to_json,
            headers: json_headers
          )

          expect { perform }.to raise_error(error_class) do |error|
            expect(error.request_id).to eq('req-list-id')
            expect(error.status).to eq(status)
          end
        end
      end
    end

    context 'when a transport failure occurs on the GET' do
      before do
        stub_const("#{described_class}::RETRY_OPTIONS", retry_options)
      end

      it 'retries the idempotent GET once and then raises UnavailableError', :aggregate_failures do
        stub_request(:get, request_url).to_timeout

        expect { perform }.to raise_error(described_class::UnavailableError)
        expect(a_request(:get, request_url)).to have_been_made.times(retry_options[:max] + 1)
      end
    end

    context 'when AR returns a success response the contract does not allow' do
      it_behaves_like 'rejecting an unexpected success body', status: 204, body: '', body_class: 'NilClass'
      it_behaves_like 'rejecting an unexpected success body', status: 200, body: '{}', body_class: 'Hash'
      it_behaves_like 'rejecting an unexpected success body', status: 200, body: '["oops"]', body_class: 'Array'
    end

    context 'when handling the credential' do
      it 'acquires it for the slug and attaches it as a Bearer header, never in the request URI',
        :aggregate_failures do
        request = stub_request(:get, request_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: list_response.to_json, headers: json_headers)

        perform

        expect(request).to have_been_requested
        expect(token_exchange).to have_received(:token_for).with(current_user, slug)
        expect(a_request(:get, request_url).with { |req| req.uri.to_s.exclude?(token) }).to have_been_made
      end

      it 'redacts a credential AR echoes in an error envelope, in both the raised and the logged error',
        :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        echoed = "rejected: Authorization: Bearer #{jwt_credential}"
        stub_request(:get, request_url)
          .to_return(status: 503, body: error_envelope(message: echoed).to_json, headers: json_headers)

        expect { perform }.to raise_error(described_class::UnavailableError) do |error|
          expect(error.message).to include('Bearer [REDACTED]')
          expect(error.message).not_to include(jwt_credential[0, 40])
        end
        expect(Gitlab::ErrorTracking).to have_received(:log_exception) do |logged, _context|
          expect(logged.message).not_to include(jwt_credential[0, 40])
        end
      end
    end

    context 'when slug or the repository name is blank or a bare dot-segment' do
      where(:slug, :name) do
        nil        | 'my-repo'
        ''         | 'my-repo'
        '.'        | 'my-repo'
        '..'       | 'my-repo'
        'my-group' | nil
        'my-group' | ''
        'my-group' | '.'
        'my-group' | '..'
      end

      with_them do
        it_behaves_like 'rejecting an invalid argument before any request'
      end
    end

    context 'when the slug and repository name contain path separators' do
      let(:slug) { 'grp/x' }
      let(:name) { 'evil/segment' }

      it 'percent-encodes each path segment so a value cannot smuggle extra path segments', :aggregate_failures do
        encoded_path = "grp%2Fx/repositories/evil%2Fsegment/#{format}/#{list_segment}"
        encoded = stub_request(:get, "#{base_url}/api/v1/#{encoded_path}")
          .to_return(status: 200, body: list_response.to_json, headers: json_headers)
        traversed = stub_request(:get, "#{base_url}/api/v1/grp/x/repositories/evil/segment/#{format}/#{list_segment}")

        perform

        expect(encoded).to have_been_requested
        expect(traversed).not_to have_been_requested
      end
    end
  end

  describe '#repository' do
    subject(:result) { client.repository(slug: slug, name: name) }

    let(:perform) { result }
    let(:http_method) { :get }
    let(:request_url) { repository_url }

    context 'when AR returns 200 with a repository body' do
      it 'issues a GET to the repository detail path and returns a Repository', :aggregate_failures do
        request = stub_ar_get(status: 200, body: repository_response.to_json)

        expect(result).to be_a(ArtifactRegistry::Repository)
        expect(result.name).to eq(name)
        expect(request).to have_been_requested
      end

      it 'attaches the credential, User-Agent, and correlation id to the request', :aggregate_failures do
        correlation_id = 'correlation-abc-123'
        request = stub_request(:get, repository_url)
          .with(headers: {
            'Authorization' => "Bearer #{token}",
            'User-Agent' => "GitLab/#{Gitlab::VERSION}",
            'X-Request-Id' => correlation_id
          })
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)

        Labkit::Correlation::CorrelationId.use_id(correlation_id) do
          expect(result).to be_a(ArtifactRegistry::Repository)
        end

        expect(request).to have_been_requested
      end

      it 'omits the correlation id header when there is no current correlation id' do
        allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return(nil)
        stub_ar_get(status: 200, body: repository_response.to_json)

        result

        expect(a_request(:get, repository_url).with { |req| !req.headers.key?('X-Request-Id') })
          .to have_been_made
      end

      it 'acquires the credential through the token exchange with the current user and slug' do
        stub_ar_get(status: 200, body: repository_response.to_json)

        result

        expect(token_exchange).to have_received(:token_for).with(current_user, slug)
      end
    end

    context 'when AR returns 404' do
      it 'returns nil' do
        stub_ar_get(status: 404, body: error_envelope(code: 'not_found').to_json)

        expect(result).to be_nil
      end

      it 'returns nil even when the 404 body is empty' do
        stub_ar_get(status: 404, body: '')

        expect(result).to be_nil
      end

      it 'returns nil even when the 404 body is malformed' do
        stub_ar_get(status: 404, body: 'bleh')

        expect(result).to be_nil
      end
    end

    context 'when AR returns 204 on a body-expecting call' do
      it_behaves_like 'rejecting an unexpected success body', status: 204, body: '', body_class: 'NilClass'
    end

    context 'when no base_url is supplied' do
      let(:client) { described_class.new(current_user: current_user, token_exchange: token_exchange) }
      let(:configured_url) { 'https://ar-from-config.example.test' }

      before do
        stub_config(artifact_registry: { api_url: configured_url })
      end

      it 'issues the request against the configured api_url' do
        request = stub_request(:get, "#{configured_url}/api/v1/#{slug}/repositories/#{name}")
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)

        result

        expect(request).to have_been_requested
      end
    end

    context 'when base_url is blank and no api_url is configured' do
      before do
        stub_config(artifact_registry: { api_url: nil })
      end

      it 'raises ArgumentError at construction' do
        expect do
          described_class.new(current_user: current_user, token_exchange: token_exchange)
        end.to raise_error(ArgumentError, /base_url is required/)
      end
    end

    context 'when base_url has no http(s) scheme' do
      it 'raises ArgumentError at construction so a config typo cannot escape the typed errors',
        :aggregate_failures do
        ['localhost:8080', 'artifact-registry.example.test', 'ftp://artifact-registry.example.test'].each do |value|
          expect do
            described_class.new(base_url: value, current_user: current_user, token_exchange: token_exchange)
          end.to raise_error(ArgumentError, /base_url must be an http\(s\) URL/)
        end
      end
    end

    context 'when the token exchange yields no credential (the step-1 default)' do
      let(:client) { described_class.new(base_url: base_url, current_user: current_user) }

      it 'raises AuthorizationError without issuing a request', :aggregate_failures do
        request = stub_ar_get(status: 200, body: repository_response.to_json)

        expect { result }.to raise_error(described_class::AuthorizationError, /no Artifact Registry credential/i)
        expect(request).not_to have_been_requested
      end
    end

    context 'when the token exchange is explicitly nil' do
      let(:client) { described_class.new(base_url: base_url, current_user: current_user, token_exchange: nil) }

      it 'falls back to the fail-closed default instead of crashing on the nil call', :aggregate_failures do
        request = stub_ar_get(status: 200, body: repository_response.to_json)

        expect { result }.to raise_error(described_class::AuthorizationError, /no Artifact Registry credential/i)
        expect(request).not_to have_been_requested
      end
    end

    context 'when slug or name is blank' do
      where(:slug, :name) do
        ''         | 'my-repo'
        nil        | 'my-repo'
        'my-group' | ''
        'my-group' | nil
      end

      with_them do
        it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
          request = stub_ar_get(status: 200, body: repository_response.to_json)

          expect { result }.to raise_error(ArgumentError)
          expect(token_exchange).not_to have_received(:token_for)
          expect(request).not_to have_been_requested
        end
      end
    end

    context 'when the slug and name contain path separators' do
      let(:slug) { 'grp/x' }
      let(:name) { 'evil/segment' }

      it 'percent-encodes each path segment so a value cannot smuggle extra path segments', :aggregate_failures do
        encoded = stub_request(:get, "#{base_url}/api/v1/grp%2Fx/repositories/evil%2Fsegment")
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)
        traversed = stub_request(:get, "#{base_url}/api/v1/grp/x/repositories/evil/segment")

        result

        expect(encoded).to have_been_requested
        expect(traversed).not_to have_been_requested
      end
    end

    context 'when a segment contains dot-segment traversal sequences' do
      let(:slug) { 'my-group' }
      let(:name) { '../../secret' }

      it 'escapes the separators so the value stays a single path segment', :aggregate_failures do
        encoded = stub_request(:get, "#{base_url}/api/v1/my-group/repositories/..%2F..%2Fsecret")
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)
        traversed = stub_request(:get, "#{base_url}/api/v1/secret")

        result

        expect(encoded).to have_been_requested
        expect(traversed).not_to have_been_requested
      end
    end

    context 'when a whole path segment is a bare dot-segment (`.` or `..`)' do
      where(:slug, :name) do
        '..'       | 'my-repo'
        '.'        | 'my-repo'
        'my-group' | '..'
        'my-group' | '.'
      end

      with_them do
        it 'rejects the segment without contacting the token exchange or AR', :aggregate_failures do
          request = stub_ar_get(status: 200, body: repository_response.to_json)

          expect { result }.to raise_error(ArgumentError)
          expect(token_exchange).not_to have_received(:token_for)
          expect(request).not_to have_been_requested
        end
      end
    end

    context 'when a success response body is absent or unparseable' do
      it 'raises UnavailableError for an empty 200 body' do
        stub_ar_get(status: 200, body: '')

        expect { result }.to raise_error(described_class::UnavailableError)
      end

      it 'raises UnavailableError for an unparseable 200 body' do
        stub_request(:get, repository_url)
          .to_return(status: 200, body: 'this-is-not-json', headers: json_headers)

        expect { result }.to raise_error(described_class::UnavailableError)
      end

      it 'raises UnavailableError for a non-object JSON 200 body' do
        stub_request(:get, repository_url)
          .to_return(status: 200, body: [].to_json, headers: json_headers)

        expect { result }.to raise_error(described_class::UnavailableError)
      end

      it 'raises UnavailableError for valid JSON sent with a non-JSON content-type' do
        stub_request(:get, repository_url)
          .to_return(status: 200, body: repository_response.to_json, headers: { 'Content-Type' => 'text/plain' })

        expect { result }.to raise_error(described_class::UnavailableError)
      end

      it 'logs the malformed response so it is distinguishable from a transport outage' do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        stub_ar_get(status: 200, body: '')

        expect { result }.to raise_error(described_class::UnavailableError)
        expect(Gitlab::ErrorTracking).to have_received(:log_exception)
      end
    end

    context 'when AR returns a mapped error status' do
      where(:status, :error_class) do
        401 | ArtifactRegistry::Client::AuthorizationError
        403 | ArtifactRegistry::Client::AuthorizationError
        429 | ArtifactRegistry::Client::UnavailableError
        500 | ArtifactRegistry::Client::UnavailableError
        502 | ArtifactRegistry::Client::UnavailableError
        503 | ArtifactRegistry::Client::UnavailableError
        400 | ArtifactRegistry::Client::ApiError
        409 | ArtifactRegistry::Client::ApiError
        422 | ArtifactRegistry::Client::ApiError
      end

      with_them do
        it 'raises the mapped exception and preserves the envelope request_id and status', :aggregate_failures do
          stub_ar_get(status: status, body: error_envelope(request_id: 'req-mapped-id').to_json)

          expect { result }.to raise_error(error_class) do |error|
            expect(error.request_id).to eq('req-mapped-id')
            expect(error.status).to eq(status)
          end
        end
      end
    end

    context 'when AR returns a 400 with an error envelope' do
      it 'raises ApiError carrying the status, code, message, and request_id', :aggregate_failures do
        body = { error: { code: 'bad_request', message: 'name is invalid', request_id: 'req-400' } }
        stub_ar_get(status: 400, body: body.to_json)

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.status).to eq(400)
          expect(error.code).to eq('bad_request')
          expect(error.message).to include('name is invalid')
          expect(error.request_id).to eq('req-400')
        end
      end

      it 'redacts a credential echoed inside the envelope message and caps its length', :aggregate_failures do
        echoed = "Request rejected: Authorization: Bearer #{jwt_credential} #{'x' * 500}"
        body = { error: { code: 'bad_request', message: echoed, request_id: 'req-400' } }
        stub_ar_get(status: 400, body: body.to_json)

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.message).not_to include(jwt_credential[0, 40])
          expect(error.message).to include('Bearer [REDACTED]')
          expect(error.message.length).to eq(described_class::MAX_ERROR_BODY_SNIPPET)
          expect(error.request_id).to eq('req-400')
        end
      end

      it 'redacts a credential echoed inside the envelope code and request_id', :aggregate_failures do
        body = { error: { code: "Bearer #{jwt_credential}", message: 'rejected', request_id: jwt_credential } }
        stub_ar_get(status: 400, body: body.to_json)

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.code).to eq('Bearer [REDACTED]')
          expect(error.request_id).to eq('[REDACTED]')
        end
      end
    end

    context 'when a mapped error response has no usable error envelope' do
      it 'raises the mapped error with a nil request_id when the body has no error object', :aggregate_failures do
        stub_ar_get(status: 401, body: { detail: 'nope' }.to_json)

        expect { result }.to raise_error(described_class::AuthorizationError) do |error|
          expect(error.request_id).to be_nil
        end
      end

      it 'keeps a String error field as the message and raises ApiError with a nil code', :aggregate_failures do
        stub_ar_get(status: 400, body: { error: 'boom' }.to_json)

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.status).to eq(400)
          expect(error.code).to be_nil
          expect(error.message).to eq('boom')
        end
      end

      it 'raises the mapped error when the error body is empty', :aggregate_failures do
        stub_ar_get(status: 422, body: '')

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.status).to eq(422)
        end
      end

      it 'omits an error object whose keys all fall outside the snippet allowlist', :aggregate_failures do
        stub_ar_get(status: 422, body: { errors: { name: ['taken'] } }.to_json)

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.status).to eq(422)
          expect(error.code).to be_nil
          # A nil message renders as the exception class name, so the body contributed nothing.
          expect(error.message).to eq(described_class::ApiError.name)
        end
      end

      context 'when an unrecognized JSON error object carries an allowlisted key' do
        where(:allowlisted_key) { %w[detail message title] }

        with_them do
          it 'snippets that value into the message' do
            stub_ar_get(status: 403, body: { allowlisted_key => 'the request was rejected' }.to_json)

            expect { result }.to raise_error(described_class::AuthorizationError, 'the request was rejected')
          end
        end
      end

      it 'keeps a credential carried under a non-allowlisted key out of the message' do
        body = { detail: 'rejected', upstream_api_key: 'sk_live_0123456789abcdef' } # gitleaks:allow
        stub_ar_get(status: 401, body: body.to_json)

        expect { result }.to raise_error(described_class::AuthorizationError, 'rejected')
      end

      it 'omits a non-String value under an allowlisted key, so a nested credential cannot reach the message' do
        body = { detail: { upstream_api_key: 'sk_live_0123456789abcdef' } } # gitleaks:allow
        stub_ar_get(status: 401, body: body.to_json)

        expect { result }.to raise_error(described_class::AuthorizationError) do |error|
          expect(error.message).to eq(described_class::AuthorizationError.name)
        end
      end

      it 'redacts a credential carried in an unrecognized JSON error object', :aggregate_failures do
        stub_ar_get(status: 401, body: { detail: "rejected Bearer #{jwt_credential}" }.to_json)

        expect { result }.to raise_error(described_class::AuthorizationError) do |error|
          expect(error.message).not_to include(jwt_credential)
          expect(error.message).to include('Bearer [REDACTED]')
        end
      end

      it 'caps an unrecognized JSON error object at MAX_ERROR_BODY_SNIPPET' do
        stub_ar_get(status: 401, body: { detail: 'x' * 500 }.to_json)

        expect { result }.to raise_error(described_class::AuthorizationError) do |error|
          expect(error.message.length).to eq(described_class::MAX_ERROR_BODY_SNIPPET)
        end
      end

      it 'snippets a non-JSON error body into the message and caps it at MAX_ERROR_BODY_SNIPPET',
        :aggregate_failures do
        html_body = "<html><body>#{'x' * 500}</body></html>"
        stub_request(:get, repository_url)
          .to_return(status: 500, body: html_body, headers: { 'Content-Type' => 'text/html' })

        expect { result }.to raise_error(described_class::UnavailableError) do |error|
          expect(error.message.length).to eq(described_class::MAX_ERROR_BODY_SNIPPET)
          expect(error.message).to start_with('<html>')
        end
      end

      it 'redacts an echoed Authorization header from the snippet', :aggregate_failures do
        echoed_body = "Request rejected: Authorization: Bearer #{jwt_credential} (invalid)"
        stub_request(:get, repository_url)
          .to_return(status: 400, body: echoed_body, headers: { 'Content-Type' => 'text/plain' })

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.message).not_to include(jwt_credential)
          expect(error.message).to include('Bearer [REDACTED]')
          expect(error.message).to start_with('Request rejected:')
        end
      end

      it 'redacts a bare JWT-shaped string from the snippet', :aggregate_failures do
        stub_request(:get, repository_url)
          .to_return(status: 400, body: "token #{jwt_credential} was rejected",
            headers: { 'Content-Type' => 'text/plain' })

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.message).not_to include(jwt_credential)
          expect(error.message).to eq('token [REDACTED] was rejected')
        end
      end

      it 'redacts before truncating, so a long body cannot leak a credential prefix' do
        stub_request(:get, repository_url)
          .to_return(status: 400, body: "Bearer #{jwt_credential} #{'x' * 500}",
            headers: { 'Content-Type' => 'text/plain' })

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.message).not_to include(jwt_credential[0, 40])
        end
      end

      it 'leaves a snippet carrying no credential untouched' do
        stub_request(:get, repository_url)
          .to_return(status: 400, body: 'repository name is invalid',
            headers: { 'Content-Type' => 'text/plain' })

        expect { result }.to raise_error(described_class::ApiError, 'repository name is invalid')
      end
    end

    context 'when an error status carries an unreadable JSON body' do
      where(:status, :error_class) do
        401 | ArtifactRegistry::Client::AuthorizationError
        403 | ArtifactRegistry::Client::AuthorizationError
        500 | ArtifactRegistry::Client::UnavailableError
      end

      with_them do
        it 'classifies the failure by its HTTP status and keeps the status on the error', :aggregate_failures do
          stub_ar_get(status: status, body: 'not json')

          expect { result }.to raise_error(error_class) do |error|
            expect(error.status).to eq(status)
            expect(error.message).to match(/unreadable response/)
          end
        end
      end
    end

    context 'when AR returns a redirect' do
      it 'surfaces the 3xx as a typed error and never contacts the Location host', :aggregate_failures do
        redirect_target = 'https://elsewhere.example.test/steal'
        stub_request(:get, repository_url)
          .to_return(status: 302, headers: { 'Location' => redirect_target })
        target = stub_request(:get, redirect_target)

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.status).to eq(302)
        end
        expect(target).not_to have_been_requested
      end
    end

    context 'when a transport failure occurs on the GET' do
      before do
        stub_request(:get, repository_url).to_timeout
      end

      it 'retries the idempotent GET once and then raises UnavailableError', :aggregate_failures do
        stub_const("#{described_class}::RETRY_OPTIONS", retry_options)

        expect { result }.to raise_error(described_class::UnavailableError)
        expect(a_request(:get, repository_url)).to have_been_made.times(retry_options[:max] + 1)
      end

      it 'logs each transport exception without leaking the credential', :aggregate_failures do
        logged = []
        allow(Gitlab::ErrorTracking).to receive(:log_exception) { |*args| logged << args }
        stub_const("#{described_class}::RETRY_OPTIONS", retry_options)

        expect { result }.to raise_error(described_class::UnavailableError)
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).exactly(retry_options[:max] + 1).times
        expect(logged.to_s).not_to include(token)
      end
    end

    context 'when the GET fails with a connection error' do
      it 'retries a connection failure and then raises UnavailableError', :aggregate_failures do
        stub_const("#{described_class}::RETRY_OPTIONS", retry_options)
        stub_request(:get, repository_url).to_raise(Faraday::ConnectionFailed)

        expect { result }.to raise_error(described_class::UnavailableError)
        expect(a_request(:get, repository_url)).to have_been_made.times(retry_options[:max] + 1)
      end
    end

    context 'when the GET fails with a TLS error' do
      before do
        stub_request(:get, repository_url).to_raise(Faraday::SSLError.new('certificate verify failed'))
      end

      it 'raises UnavailableError with a TLS-specific message and does not retry', :aggregate_failures do
        expect { result }.to raise_error(
          described_class::UnavailableError, /TLS connection failed.*certificate verify failed/
        )
        expect(a_request(:get, repository_url)).to have_been_made.once
      end
    end

    context 'when AR returns a 5xx status' do
      it 'raises UnavailableError without retrying', :aggregate_failures do
        request = stub_ar_get(status: 503, body: error_envelope(code: 'service_unavailable').to_json)

        expect { result }.to raise_error(described_class::UnavailableError)
        expect(request).to have_been_requested.once
      end

      it 'logs the server-side failure with its request context, status, and request id', :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        stub_ar_get(status: 503, body: error_envelope(request_id: 'req-5xx').to_json)

        expect { result }.to raise_error(described_class::UnavailableError)
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
          instance_of(described_class::UnavailableError),
          hash_including(url: base_url, slug: slug, status: 503, request_id: 'req-5xx')
        )
      end
    end
  end

  describe '#repositories' do
    let(:perform) { client.repositories(slug: slug) }
    let(:http_method) { :get }
    let(:request_url) { repositories_url }

    let(:other_repository_response) do
      repository_response.merge(
        'id' => 'b2c3d4e5-0000-0000-0000-000000000000',
        'name' => 'other-repo',
        'created_by' => '303',
        'updated_by' => '404'
      )
    end

    let(:repositories_response) { [repository_response, other_repository_response] }

    context 'when AR returns a 200 with a JSON array of repositories' do
      it 'parses the array into Repository value objects on the page', :aggregate_failures do
        request = stub_ar_list(body: repositories_response.to_json)
        page = client.repositories(slug: slug)

        expect(request).to have_been_requested
        expect(page.nodes).to all(be_a(ArtifactRegistry::Repository))
        expect(page.nodes.map(&:name)).to eq(%w[my-repo other-repo])
      end

      it 'resolves a populated page from a single request with no per-element follow-up', :aggregate_failures do
        list = stub_ar_list(body: repositories_response.to_json)
        detail = stub_request(:get, "#{base_url}/api/v1/#{slug}/repositories/my-repo")

        client.repositories(slug: slug)

        expect(list).to have_been_requested.once
        expect(detail).not_to have_been_requested
      end

      it 'passes created_by and updated_by through as the raw opaque strings', :aggregate_failures do
        stub_ar_list(body: repositories_response.to_json)
        first = client.repositories(slug: slug).nodes.first

        expect(first.created_by).to eq('101')
        expect(first.updated_by).to eq('202')
      end
    end

    context 'with query parameters' do
      it 'forwards format, kind, sort, order, limit, and cursor as query parameters' do
        request = stub_request(:get, repositories_url)
          .with(query: {
            format: 'maven', kind: 'hosted', sort: 'name', order: 'asc', limit: '50', cursor: 'opaque-cursor'
          })
          .to_return(status: 200, body: repositories_response.to_json, headers: json_headers)

        client.repositories(
          slug: slug, format: 'maven', kind: 'hosted', sort: 'name', order: 'asc', limit: 50, cursor: 'opaque-cursor'
        )

        expect(request).to have_been_requested
      end

      it 'omits the query parameters that were not supplied' do
        stub_ar_list(body: repositories_response.to_json)

        client.repositories(slug: slug)

        expect(a_request(:get, repositories_url).with { |req| req.uri.query.blank? }).to have_been_made
      end

      it 'forwards a cursor verbatim on a follow-up call' do
        request = stub_request(:get, repositories_url)
          .with(query: { cursor: next_cursor })
          .to_return(status: 200, body: repositories_response.to_json, headers: json_headers)

        client.repositories(slug: slug, cursor: next_cursor)

        expect(request).to have_been_requested
      end
    end

    context 'when parsing the Link header for cursors (RFC 8288)' do
      def stub_list_with_link(link)
        stub_ar_list(body: repositories_response.to_json, headers: json_headers.merge('Link' => link))
      end

      it 'reads the next and prev cursors from the Link header', :aggregate_failures do
        next_url = "#{base_url}/api/v1/#{slug}/repositories?limit=20&cursor=#{next_cursor}"
        prev_url = "#{base_url}/api/v1/#{slug}/repositories?limit=20&cursor=#{prev_cursor}"
        stub_list_with_link(%(<#{next_url}>; rel="next", <#{prev_url}>; rel="prev"))

        page = client.repositories(slug: slug)

        expect(page.next_cursor).to eq(next_cursor)
        expect(page.prev_cursor).to eq(prev_cursor)
      end

      it 'returns a nil prev cursor and logs nothing on the first page (Link carries only rel="next")',
        :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        stub_list_with_link(%(<#{base_url}/api/v1/#{slug}/repositories?cursor=#{next_cursor}>; rel="next"))

        page = client.repositories(slug: slug)

        expect(page.next_cursor).to eq(next_cursor)
        expect(page.prev_cursor).to be_nil
        expect(Gitlab::ErrorTracking).not_to have_received(:log_exception)
      end

      it 'returns a nil next cursor and logs nothing on the final page (Link carries only rel="prev")',
        :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        stub_list_with_link(%(<#{base_url}/api/v1/#{slug}/repositories?cursor=#{prev_cursor}>; rel="prev"))

        page = client.repositories(slug: slug)

        expect(page.next_cursor).to be_nil
        expect(page.prev_cursor).to eq(prev_cursor)
        expect(Gitlab::ErrorTracking).not_to have_received(:log_exception)
      end

      it 'returns nil cursors and logs nothing when the response carries no Link header', :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        stub_ar_list(body: repositories_response.to_json)

        page = client.repositories(slug: slug)

        expect(page.next_cursor).to be_nil
        expect(page.prev_cursor).to be_nil
        expect(Gitlab::ErrorTracking).not_to have_received(:log_exception)
      end

      it 'returns nil cursors and logs when a link URI is malformed', :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        stub_list_with_link('<https://ar/a b?cursor=x>; rel="next"')

        page = client.repositories(slug: slug)

        expect(page.next_cursor).to be_nil
        expect(page.prev_cursor).to be_nil
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
          instance_of(URI::InvalidURIError), hash_including(url: base_url, slug: slug)
        )
      end

      it 'returns a nil next cursor and logs when the next link carries no cursor', :aggregate_failures do
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
        stub_list_with_link(%(<#{repositories_url}?limit=20>; rel="next"))

        page = client.repositories(slug: slug)

        expect(page.next_cursor).to be_nil
        expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
          instance_of(described_class::Error), hash_including(url: base_url, slug: slug)
        )
      end

      context 'when the parser drops every rel the client reads' do
        shared_examples 'a Link header the parser yields no usable rel from' do
          it 'returns nil cursors and logs the dropped header', :aggregate_failures do
            allow(Gitlab::ErrorTracking).to receive(:log_exception)
            stub_list_with_link(link)

            page = client.repositories(slug: slug)

            expect(page.next_cursor).to be_nil
            expect(page.prev_cursor).to be_nil
            expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
              instance_of(described_class::Error), hash_including(url: base_url, slug: slug)
            )
          end
        end

        context 'when the only rel is the "previous" synonym of "prev"' do
          let(:link) { %(<#{repositories_url}?cursor=#{prev_cursor}>; rel="previous") }

          it_behaves_like 'a Link header the parser yields no usable rel from'
        end

        context 'when the link URI contains a comma, which the parser splits on' do
          let(:link) { %(<#{repositories_url}?cursor=a,b>; rel="next") }

          it_behaves_like 'a Link header the parser yields no usable rel from'
        end

        context 'when the link URI is longer than the parser accepts' do
          let(:link) { %(<#{repositories_url}?cursor=#{'x' * 520}>; rel="next") }

          it_behaves_like 'a Link header the parser yields no usable rel from'
        end
      end
    end

    context 'when AR returns a success response the contract does not allow' do
      it_behaves_like 'rejecting an unexpected success body', status: 204, body: '', body_class: 'NilClass'
      it_behaves_like 'rejecting an unexpected success body', status: 200, body: '{}', body_class: 'Hash'
      it_behaves_like 'rejecting an unexpected success body', status: 200, body: '["oops"]', body_class: 'Array'
    end

    context 'when attaching the credential through the shared request primitive' do
      it 'attaches the acquired credential as an Authorization: Bearer header' do
        request = stub_request(:get, repositories_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 200, body: repositories_response.to_json, headers: json_headers)

        client.repositories(slug: slug)

        expect(request).to have_been_requested
      end

      it 'acquires the credential through the token exchange with the current user and slug' do
        stub_ar_list(body: repositories_response.to_json)

        client.repositories(slug: slug)

        expect(token_exchange).to have_received(:token_for).with(current_user, slug)
      end
    end

    context 'when slug is blank or a bare dot-segment' do
      where(:slug) { [nil, '', '.', '..'] }

      with_them do
        it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
          request = stub_ar_list(body: repositories_response.to_json)

          expect { client.repositories(slug: slug) }.to raise_error(ArgumentError)
          expect(token_exchange).not_to have_received(:token_for)
          expect(request).not_to have_been_requested
        end
      end
    end

    context 'when AR returns 404 (the slug did not resolve to a namespace)' do
      before do
        stub_request(:get, repositories_url)
          .to_return(
            status: 404,
            body: error_envelope(code: 'not_found', message: 'namespace not found', request_id: 'req-404').to_json,
            headers: json_headers
          )
      end

      # AR answers 404 both for a namespace that does not exist and for one the caller may not
      # see, so the absence is reported the way #repository reports it rather than raised.
      it 'returns nil rather than raising' do
        expect(client.repositories(slug: slug)).to be_nil
      end

      it 'logs the envelope, so a slug that drifted from AR is still diagnosable' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception)
          .with(an_instance_of(described_class::ApiError), hash_including(slug: slug)) do |error, _context|
            expect(error.status).to eq(404)
            expect(error.code).to eq('not_found')
            expect(error.request_id).to eq('req-404')
          end

        client.repositories(slug: slug)
      end

      it 'returns nil even when the 404 body is empty' do
        stub_request(:get, repositories_url).to_return(status: 404, body: '')

        expect(client.repositories(slug: slug)).to be_nil
      end
    end

    context 'when the slug contains path separators' do
      let(:slug) { 'grp/x' }

      it 'percent-encodes the slug segment so it cannot smuggle extra path segments', :aggregate_failures do
        encoded = stub_request(:get, "#{base_url}/api/v1/grp%2Fx/repositories")
          .to_return(status: 200, body: repositories_response.to_json, headers: json_headers)
        traversed = stub_request(:get, "#{base_url}/api/v1/grp/x/repositories")

        client.repositories(slug: slug)

        expect(encoded).to have_been_requested
        expect(traversed).not_to have_been_requested
      end
    end
  end

  describe '#packages' do
    let(:format) { 'maven' }
    let(:http_method) { :get }
    let(:request_url) { "#{repository_url}/#{format}/packages" }
    let(:perform) { perform_with }

    let(:maven_package_response) do
      {
        'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
        'group_id' => 'com.example.tools',
        'artifact_id' => 'payment-core',
        'last_downloaded_at' => '2026-07-03T09:15:00Z'
      }
    end

    let(:other_maven_package_response) do
      maven_package_response.merge('id' => 'b2c3d4e5-0000-0000-0000-000000000000', 'artifact_id' => 'payment-api')
    end

    let(:list_response) { [maven_package_response, other_maven_package_response] }

    def perform_with(**arguments)
      client.packages(slug: slug, repository_name: name, format: format, **arguments)
    end

    it_behaves_like 'a keyset artifact list read', list_segment: 'packages'

    context 'when the repository format is maven' do
      it 'reads under the maven segment and returns MavenPackage rows on a Page', :aggregate_failures do
        request = stub_ar_list(body: list_response.to_json)

        page = perform

        expect(request).to have_been_requested
        expect(page).to be_a(ArtifactRegistry::Page)
        expect(page.nodes).to all(be_a(ArtifactRegistry::MavenPackage))
        expect(page.nodes.map(&:id)).to eq(
          %w[a1b2c3d4-0000-0000-0000-000000000000 b2c3d4e5-0000-0000-0000-000000000000]
        )
        expect(page.nodes.map(&:group_id)).to eq(%w[com.example.tools com.example.tools])
        expect(page.nodes.map(&:artifact_id)).to eq(%w[payment-core payment-api])
      end
    end

    context 'when the repository format is npm' do
      let(:format) { 'npm' }

      let(:npm_package_response) do
        {
          'id' => 'c3d4e5f6-0000-0000-0000-000000000000',
          'name' => '@acme/ui-components',
          'scope' => '@acme',
          'versions_count' => 7,
          'tags_count' => 2,
          'last_downloaded_at' => '2026-07-03T09:15:00Z'
        }
      end

      let(:unscoped_npm_package_response) do
        npm_package_response.merge(
          'id' => 'd4e5f6a7-0000-0000-0000-000000000000',
          'name' => 'ui-components',
          'scope' => nil,
          'versions_count' => 1
        )
      end

      let(:list_response) { [npm_package_response, unscoped_npm_package_response] }

      it 'reads under the npm segment and returns NpmPackage rows carrying name, scope, and the count',
        :aggregate_failures do
        request = stub_ar_list(body: list_response.to_json)

        page = perform

        expect(request).to have_been_requested
        expect(page).to be_a(ArtifactRegistry::Page)
        expect(page.nodes).to all(be_a(ArtifactRegistry::NpmPackage))
        expect(page.nodes.map(&:id)).to eq(
          %w[c3d4e5f6-0000-0000-0000-000000000000 d4e5f6a7-0000-0000-0000-000000000000]
        )
        expect(page.nodes.map(&:name)).to eq(['@acme/ui-components', 'ui-components'])
        expect(page.nodes.map(&:scope)).to eq(['@acme', nil])
        expect(page.nodes.map(&:versions_count)).to eq([7, 1])
      end
    end

    context 'when the format is not one the packages endpoint serves' do
      where(:format) { [nil, '', 'docker', 'oci', 'not-a-format'] }

      with_them do
        it_behaves_like 'rejecting an invalid argument before any request'
      end
    end
  end

  describe '#images' do
    let(:format) { 'docker' }
    let(:http_method) { :get }
    let(:request_url) { "#{repository_url}/#{format}/images" }
    let(:perform) { perform_with }

    let(:image_response) do
      {
        'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
        'name' => 'api-gateway',
        'last_downloaded_at' => '2026-07-03T09:15:00Z'
      }
    end

    let(:other_image_response) do
      image_response.merge('id' => 'b2c3d4e5-0000-0000-0000-000000000000', 'name' => 'billing-worker')
    end

    let(:list_response) { [image_response, other_image_response] }

    def perform_with(**arguments)
      client.images(slug: slug, repository_name: name, format: format, **arguments)
    end

    it_behaves_like 'a keyset artifact list read', list_segment: 'images'

    context 'when the repository is a container repository' do
      where(:format) { %w[docker oci] }

      with_them do
        it 'reads under the repository format segment and returns Image rows on a Page',
          :aggregate_failures do
          request = stub_ar_list(body: list_response.to_json)

          page = perform

          expect(request).to have_been_requested
          expect(page).to be_a(ArtifactRegistry::Page)
          expect(page.nodes).to all(be_a(ArtifactRegistry::Image))
          expect(page.nodes.map(&:id)).to eq(
            %w[a1b2c3d4-0000-0000-0000-000000000000 b2c3d4e5-0000-0000-0000-000000000000]
          )
          expect(page.nodes.map(&:name)).to eq(%w[api-gateway billing-worker])
        end
      end
    end

    context 'when the format is not one the images endpoint serves' do
      where(:format) { [nil, '', 'maven', 'npm', 'not-a-format'] }

      with_them do
        it_behaves_like 'rejecting an invalid argument before any request'
      end
    end
  end

  describe '#create_repository' do
    let(:perform) { client.create_repository(slug: slug, name: name, format: 'maven') }
    let(:http_method) { :post }
    let(:request_url) { repositories_url }

    context 'when AR returns 201 with the created repository' do
      it 'POSTs the full body, attaches the Bearer credential, and returns the created Repository',
        :aggregate_failures do
        request = stub_request(:post, repositories_url)
          .with(
            body: {
              name: name,
              format: 'maven',
              kind: 'hosted',
              visibility: 'private',
              description: 'A hosted Maven repository'
            },
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 201, body: repository_response.to_json, headers: json_headers)

        result = client.create_repository(
          slug: slug,
          name: name,
          format: 'maven',
          kind: 'hosted',
          visibility: 'private',
          description: 'A hosted Maven repository'
        )

        expect(result).to be_a(ArtifactRegistry::Repository)
        expect(result.name).to eq(name)
        expect(request).to have_been_requested
      end

      it 'omits the optional fields the caller did not provide' do
        request = stub_request(:post, repositories_url)
          .with(body: { name: name, format: 'maven' })
          .to_return(status: 201, body: repository_response.to_json, headers: json_headers)

        client.create_repository(slug: slug, name: name, format: 'maven')

        expect(request).to have_been_requested
      end
    end

    context 'when the slug contains a path separator' do
      let(:slug) { 'grp/x' }

      it 'percent-encodes the slug segment so it cannot smuggle extra path segments', :aggregate_failures do
        encoded = stub_request(:post, "#{base_url}/api/v1/grp%2Fx/repositories")
          .to_return(status: 201, body: repository_response.to_json, headers: json_headers)
        traversed = stub_request(:post, "#{base_url}/api/v1/grp/x/repositories")

        client.create_repository(slug: slug, name: name, format: 'maven')

        expect(encoded).to have_been_requested
        expect(traversed).not_to have_been_requested
      end
    end

    context 'when slug is blank or a bare dot-segment' do
      where(:slug) { [nil, '..'] }

      with_them do
        it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
          expect { client.create_repository(slug: slug, name: name, format: 'maven') }
            .to raise_error(ArgumentError)
          expect(token_exchange).not_to have_received(:token_for)
        end
      end
    end

    context 'when name is a bare dot-segment' do
      where(:name) { ['.', '..'] }

      with_them do
        it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
          request = stub_request(:post, repositories_url)

          expect { client.create_repository(slug: slug, name: name, format: 'maven') }
            .to raise_error(ArgumentError, /must not be a bare/)
          expect(token_exchange).not_to have_received(:token_for)
          expect(request).not_to have_been_requested
        end
      end
    end

    context 'when name contains dot segments without being one' do
      let(:name) { '../evil' }

      it 'sends the name through in the body rather than rejecting it' do
        request = stub_request(:post, repositories_url)
          .with(body: { name: name, format: 'maven' })
          .to_return(status: 201, body: repository_response.to_json, headers: json_headers)

        client.create_repository(slug: slug, name: name, format: 'maven')

        expect(request).to have_been_requested
      end
    end

    context 'when a required body field is blank' do
      where(:name, :format) do
        ''         | 'maven'
        nil        | 'maven'
        'my-repo'  | ''
        'my-repo'  | nil
      end

      with_them do
        it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
          request = stub_request(:post, repositories_url)

          expect { client.create_repository(slug: slug, name: name, format: format) }
            .to raise_error(ArgumentError, /is required/)
          expect(token_exchange).not_to have_received(:token_for)
          expect(request).not_to have_been_requested
        end
      end
    end

    context 'when AR returns a success response the contract does not allow' do
      it_behaves_like 'rejecting an unexpected success body', status: 204, body: '', body_class: 'NilClass'
      it_behaves_like 'rejecting an unexpected success body', status: 201, body: '[]', body_class: 'Array'
    end

    context 'when AR returns a mutation validation error' do
      it 'raises ApiError carrying the envelope code, message, status, and request_id', :aggregate_failures do
        stub_request(:post, repositories_url)
          .to_return(
            status: 422,
            body: error_envelope(code: 'unprocessable', message: 'name is taken', request_id: 'req-create').to_json,
            headers: json_headers
          )

        expect { client.create_repository(slug: slug, name: name, format: 'maven') }
          .to raise_error(described_class::ApiError) do |error|
            expect(error.status).to eq(422)
            expect(error.code).to eq('unprocessable')
            expect(error.message).to include('name is taken')
            expect(error.request_id).to eq('req-create')
          end
      end
    end

    context 'when AR returns 404 (the slug did not resolve to a namespace at AR)' do
      it 'raises ApiError rather than returning nil', :aggregate_failures do
        stub_request(:post, repositories_url)
          .to_return(status: 404, body: error_envelope(code: 'not_found').to_json, headers: json_headers)

        expect { client.create_repository(slug: slug, name: name, format: 'maven') }
          .to raise_error(described_class::ApiError) do |error|
            expect(error.status).to eq(404)
          end
      end
    end

    context 'when a transport failure occurs on the POST' do
      it 'does not retry and issues the POST exactly once', :aggregate_failures do
        stub_request(:post, repositories_url).to_timeout

        expect { client.create_repository(slug: slug, name: name, format: 'maven') }
          .to raise_error(described_class::UnavailableError)
        expect(a_request(:post, repositories_url)).to have_been_made.once
      end
    end
  end

  describe '#update_repository' do
    let(:perform) { client.update_repository(slug: slug, name: name, visibility: 'public') }
    let(:http_method) { :patch }
    let(:request_url) { repository_url }

    context 'when AR returns 200 with the updated repository' do
      it 'PATCHes only the mutable fields, attaches the Bearer credential, and returns the updated Repository',
        :aggregate_failures do
        request = stub_request(:patch, repository_url)
          .with(
            body: { visibility: 'public', description: 'Now public' },
            headers: { 'Authorization' => "Bearer #{token}" }
          )
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)

        result = client.update_repository(slug: slug, name: name, visibility: 'public', description: 'Now public')

        expect(result).to be_a(ArtifactRegistry::Repository)
        expect(request).to have_been_requested
      end

      it 'sends only the mutable fields the caller provided' do
        request = stub_request(:patch, repository_url)
          .with(body: { visibility: 'public' })
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)

        client.update_repository(slug: slug, name: name, visibility: 'public')

        expect(request).to have_been_requested
      end

      it 'sends an explicit nil description as JSON null rather than omitting it' do
        request = stub_request(:patch, repository_url)
          .with(body: '{"description":null}')
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)

        client.update_repository(slug: slug, name: name, description: nil)

        expect(request).to have_been_requested
      end
    end

    context 'when the caller provides no mutable field' do
      it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
        request = stub_request(:patch, repository_url)

        expect { client.update_repository(slug: slug, name: name) }
          .to raise_error(ArgumentError, /at least one mutable field is required/)
        expect(token_exchange).not_to have_received(:token_for)
        expect(request).not_to have_been_requested
      end
    end

    context 'when AR returns a success response the contract does not allow' do
      it_behaves_like 'rejecting an unexpected success body', status: 204, body: '', body_class: 'NilClass'
      it_behaves_like 'rejecting an unexpected success body', status: 200, body: '"nope"', body_class: 'String'
    end

    context 'when the name contains path traversal characters' do
      let(:name) { '../evil' }

      it 'percent-encodes the name segment so it cannot traverse', :aggregate_failures do
        encoded = stub_request(:patch, "#{base_url}/api/v1/#{slug}/repositories/..%2Fevil")
          .to_return(status: 200, body: repository_response.to_json, headers: json_headers)
        traversed = stub_request(:patch, "#{base_url}/api/v1/#{slug}/evil")

        client.update_repository(slug: slug, name: name, visibility: 'public')

        expect(encoded).to have_been_requested
        expect(traversed).not_to have_been_requested
      end
    end

    context 'when slug or name is blank or a bare dot-segment' do
      where(:slug, :name) do
        ''         | 'my-repo'
        'my-group' | '..'
      end

      with_them do
        it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
          expect { client.update_repository(slug: slug, name: name, visibility: 'public') }
            .to raise_error(ArgumentError)
          expect(token_exchange).not_to have_received(:token_for)
        end
      end
    end

    context 'when AR returns 404' do
      it 'raises ApiError (a genuine not-found), unlike the idempotent delete', :aggregate_failures do
        stub_ar_patch(status: 404, body: error_envelope(code: 'not_found', request_id: 'req-404').to_json)

        expect { client.update_repository(slug: slug, name: name, visibility: 'public') }
          .to raise_error(described_class::ApiError) do |error|
            expect(error.status).to eq(404)
            expect(error.request_id).to eq('req-404')
          end
      end
    end

    context 'when AR returns a mutation validation error' do
      it 'raises ApiError carrying the envelope', :aggregate_failures do
        stub_ar_patch(status: 422, body: error_envelope(code: 'unprocessable', message: 'invalid update').to_json)

        expect { client.update_repository(slug: slug, name: name, description: 'x') }
          .to raise_error(described_class::ApiError) do |error|
            expect(error.status).to eq(422)
            expect(error.message).to include('invalid update')
          end
      end
    end

    context 'when a transport failure occurs on the PATCH' do
      it 'does not retry and issues the PATCH exactly once', :aggregate_failures do
        stub_request(:patch, repository_url).to_timeout

        expect { client.update_repository(slug: slug, name: name, visibility: 'public') }
          .to raise_error(described_class::UnavailableError)
        expect(a_request(:patch, repository_url)).to have_been_made.once
      end
    end
  end

  describe '#delete_repository' do
    subject(:result) { client.delete_repository(slug: slug, name: name) }

    context 'when AR returns 204' do
      it 'issues a DELETE with the Bearer credential and returns true', :aggregate_failures do
        request = stub_request(:delete, repository_url)
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204, body: '', headers: json_headers)

        expect(result).to be(true)
        expect(request).to have_been_requested
      end
    end

    context 'when AR returns 404 (idempotent delete)' do
      it 'returns true when the envelope confirms the not-found' do
        stub_ar_delete(status: 404, body: error_envelope(code: 'not_found').to_json)

        expect(result).to be(true)
      end

      it 'raises ApiError when the 404 body is empty', :aggregate_failures do
        stub_ar_delete(status: 404, body: '')

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.status).to eq(404)
          expect(error.code).to be_nil
        end
      end

      it 'raises ApiError when an intermediary returns an HTML 404 with no error envelope' do
        stub_request(:delete, repository_url)
          .to_return(status: 404, body: '<html>404 Not Found</html>', headers: { 'Content-Type' => 'text/html' })

        expect { result }.to raise_error(described_class::ApiError)
      end
    end

    context 'when AR returns 409 because the repository still has artifacts' do
      it 'raises ApiError rather than treating it as a successful delete', :aggregate_failures do
        stub_ar_delete(status: 409, body: error_envelope(code: 'conflict', message: 'not empty').to_json)

        expect { result }.to raise_error(described_class::ApiError) do |error|
          expect(error.status).to eq(409)
          expect(error.message).to include('not empty')
        end
      end
    end

    context 'when the name contains a path separator' do
      let(:name) { 'evil/segment' }

      it 'percent-encodes the name segment so it cannot smuggle extra path segments', :aggregate_failures do
        encoded = stub_request(:delete, "#{base_url}/api/v1/#{slug}/repositories/evil%2Fsegment")
          .to_return(status: 204, body: '', headers: json_headers)
        traversed = stub_request(:delete, "#{base_url}/api/v1/#{slug}/evil/segment")

        result

        expect(encoded).to have_been_requested
        expect(traversed).not_to have_been_requested
      end
    end

    context 'when slug or name is blank or a bare dot-segment' do
      where(:slug, :name) do
        ''         | 'my-repo'
        'my-group' | '..'
      end

      with_them do
        it 'raises ArgumentError without contacting the token exchange or AR', :aggregate_failures do
          expect { result }.to raise_error(ArgumentError)
          expect(token_exchange).not_to have_received(:token_for)
        end
      end
    end

    context 'when a transport failure occurs on the DELETE' do
      before do
        stub_const("#{described_class}::RETRY_OPTIONS", retry_options)
      end

      it 'retries the idempotent DELETE once and then raises UnavailableError', :aggregate_failures do
        stub_request(:delete, repository_url).to_timeout

        expect { result }.to raise_error(described_class::UnavailableError)
        expect(a_request(:delete, repository_url)).to have_been_made.times(retry_options[:max] + 1)
      end

      it 'returns true when the retry sees a 404 after the first attempt already deleted the repository',
        :aggregate_failures do
        stub_request(:delete, repository_url)
          .to_timeout.then
          .to_return(status: 404, body: error_envelope(code: 'not_found').to_json, headers: json_headers)

        expect(result).to be(true)
        expect(a_request(:delete, repository_url)).to have_been_made.twice
      end
    end
  end

  def stub_ar_get(status:, body: '')
    stub_request(:get, repository_url).to_return(status: status, body: body, headers: json_headers)
  end

  def stub_ar_patch(status:, body: '')
    stub_request(:patch, repository_url).to_return(status: status, body: body, headers: json_headers)
  end

  def stub_ar_delete(status:, body: '')
    stub_request(:delete, repository_url).to_return(status: status, body: body, headers: json_headers)
  end

  def stub_ar_list(body:, headers: json_headers)
    stub_request(:get, request_url).to_return(status: 200, body: body, headers: headers)
  end

  def error_envelope(code: 'error_code', message: 'something went wrong', request_id: 'req-envelope-id')
    { error: { code: code, message: message, request_id: request_id } }
  end
end

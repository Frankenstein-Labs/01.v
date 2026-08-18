# frozen_string_literal: true

RSpec.shared_context 'for check upstream service for maven packages' do
  def stub_upstream_request(upstream, status: 200, raise_error: false)
    request = stub_request(:head, upstream.url_for(path)).with(headers: upstream.headers)

    if raise_error
      request.to_raise(Gitlab::HTTP::BlockedUrlError)
    else
      request.to_return(status: status, body: 'test')
    end
  end

  def stub_upstream_redirect(upstream, redirect_to:, final_status: 200, redirect_status: 302)
    # Initial request (same host as the upstream) carries the upstream credentials
    stub_request(:head, upstream.url_for(path))
      .with(headers: upstream.headers)
      .to_return(status: redirect_status, headers: { 'Location' => redirect_to })

    # Follow-up request to a different host: credential headers are stripped,
    # mirroring Go net/http (and Workhorse) cross-host redirect behavior.
    stub_cross_host_redirect_follow(redirect_to, upstream: upstream, status: final_status, body: 'test')
  end

  def stub_upstream_chained_redirects(upstream, redirect_chain:, final_status: 200)
    # First request to the upstream carries credentials
    stub_request(:head, upstream.url_for(path))
      .with(headers: upstream.headers)
      .to_return(status: 302, headers: { 'Location' => redirect_chain.first })

    # Intermediate redirects (cross-host): credentials stripped
    redirect_chain.each_cons(2) do |current_url, next_url|
      stub_cross_host_redirect_follow(current_url, upstream: upstream, status: 302,
        headers: { 'Location' => next_url })
    end

    # Final request (cross-host): credentials stripped
    stub_cross_host_redirect_follow(redirect_chain.last, upstream: upstream, status: final_status, body: 'test')
  end

  # Stubs a cross-host redirect follow-up, asserting the credential headers
  # (Authorization, Cookie, ...) are NOT forwarded. Any remaining non-credential
  # headers must still be present.
  def stub_cross_host_redirect_follow(url, upstream:, **to_return_options)
    credential_headers = VirtualRegistries::Upstreams::Remote::CrossHostCredentialFilter::CREDENTIAL_HEADERS
    forwarded_headers = upstream.headers.reject { |name, _| credential_headers.include?(name.to_s.downcase) }

    request = stub_request(:head, url)
    request = request.with(headers: forwarded_headers) if forwarded_headers.present?
    request = request.with do |req|
      actual = (req.headers || {}).transform_keys { |name| name.to_s.downcase }
      credential_headers.none? { |name| actual.key?(name) }
    end
    request.to_return(**to_return_options)
  end

  def stub_upstream_same_host_redirect(upstream, redirect_to:, final_status: 200, redirect_status: 302)
    stub_request(:head, upstream.url_for(path))
      .with(headers: upstream.headers)
      .to_return(status: redirect_status, headers: { 'Location' => redirect_to })

    stub_same_host_redirect_follow(redirect_to, upstream: upstream, status: final_status, body: 'test')
  end

  # Stubs a same-host redirect follow-up, asserting the credential headers ARE
  # still forwarded (Go net/http keeps credentials on same-host / subdomain hops).
  def stub_same_host_redirect_follow(url, upstream:, **to_return_options)
    stub_request(:head, url)
      .with(headers: upstream.headers)
      .to_return(**to_return_options)
  end
end

RSpec.shared_context 'for check upstream service for container images' do
  def stub_upstream_request(upstream, status: 200, raise_error: false, scope: 'repository:test:pull')
    url = upstream.url_for(path)

    # Step 1: Auth discovery - HEAD request returns 401 with WWW-Authenticate header
    stub_request(:head, url)
    .to_return(
      status: 401,
      headers: {
        'www-authenticate' => 'Bearer realm="https://auth.example.com/token",service="registry.example.com",scope="repository:test:pull"'
      }
    )

    # Step 2: Token exchange - GET request to auth service returns bearer token
    stub_request(:get, "https://auth.example.com/token")
      .with(query: { "service" => "registry.example.com", "scope" => scope })
      .to_return(
        status: 200,
        body: '{"token": "fake_bearer_token_123"}'
      )

    # Step 3: Authenticated request - HEAD request with bearer token
    expected_headers = upstream.headers(path).merge(VirtualRegistries::Container::Upstream::REGISTRY_ACCEPT_HEADERS)
    request = stub_request(:head, url).with(headers: expected_headers)

    if raise_error
      request.to_raise(Gitlab::HTTP::BlockedUrlError)
    else
      request.to_return(status: status, body: 'test')
    end
  end
end

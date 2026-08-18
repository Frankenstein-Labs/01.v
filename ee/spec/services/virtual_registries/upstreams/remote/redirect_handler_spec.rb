# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Remote::RedirectHandler, :aggregate_failures, feature_category: :virtual_registry do
  let(:headers) { { 'Authorization' => 'Bearer token' } }
  let(:timeout) { 5 }
  let(:redirect_count) { 0 }
  let(:source_url) { 'https://example.com/v2/group/image/blobs/sha256:abc' }

  subject(:handler) do
    described_class.new(headers: headers, timeout: timeout, url: source_url, redirect_count: redirect_count)
  end

  describe '#redirect?' do
    using RSpec::Parameterized::TableSyntax

    where(:status_code, :expected_result) do
      200 | false
      201 | false
      204 | false
      301 | true
      302 | true
      303 | true
      307 | true
      308 | true
      400 | false
      404 | false
      500 | false
    end

    with_them do
      let(:response) { instance_double(Typhoeus::Response, code: status_code) }

      it { expect(handler.redirect?(response)).to eq(expected_result) }
    end
  end

  describe '#build_follow_request' do
    let(:redirect_url) { 'https://example.com/redirected/path' }
    let(:resolved_ip) { '93.184.216.34' }
    let(:resolved_uri) { Addressable::URI.parse("https://#{resolved_ip}/redirected/path") }
    let(:validation_result) { Gitlab::HTTP_V2::UrlBlocker::Result.new(resolved_uri, 'example.com', false) }

    let(:response_code) { 302 }
    let(:response_headers) { Typhoeus::Response::Header.new('Location' => redirect_url) }
    let(:response) do
      instance_double(Typhoeus::Response, code: response_code, headers: response_headers)
    end

    shared_context 'with stubbed url validation and DNS pinning' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!).and_return(validation_result)
        allow(VirtualRegistries::Upstreams::Remote::PinnedRequestBuilder)
          .to receive(:build_resolve_slist) { |host, port, ip| "slist:#{host}:#{port}:#{ip}" }
      end
    end

    context 'when the Location header is lower-cased (HTTP/2 upstream)' do
      let(:response_code) { 307 }
      let(:response_headers) { Typhoeus::Response::Header.new('location' => redirect_url) }

      include_context 'with stubbed url validation and DNS pinning'

      it 'still follows the redirect (case-insensitive Location lookup)' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request).to be_a(Typhoeus::Request)
        expect(request.base_url).to eq(redirect_url)
      end
    end

    context 'when the Location header is duplicated (Array value)' do
      let(:response_headers) do
        Typhoeus::Response::Header.new('Location' => ['https://example.com/first', 'https://example.com/second'])
      end

      before do
        allow(VirtualRegistries::Upstreams::Remote::PinnedRequestBuilder)
          .to receive(:build_resolve_slist) { |host, port, ip| "slist:#{host}:#{port}:#{ip}" }
      end

      it 'follows the last value without raising on the Array' do
        expect(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!)
          .with('https://example.com/second', anything)
          .and_return(validation_result)

        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request).to be_a(Typhoeus::Request)
      end
    end

    context 'when redirect URL is valid external URL' do
      include_context 'with stubbed url validation and DNS pinning'

      it 'returns a Typhoeus::Request using the original hostname URL' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request).to be_a(Typhoeus::Request)
        expect(request.base_url).to eq(redirect_url)
        expect(request.options[:method]).to eq(:head)
        expect(request.options[:followlocation]).to be(false)
        expect(request.options[:timeout]).to eq(timeout)
        expect(request.options[:headers]).to include(headers)
      end

      it 'pins resolved IP via resolve: option when DNS rebinding protection replaced hostname' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request.options[:resolve]).to eq('slist:example.com:443:93.184.216.34')
      end

      it 'does not set Host header' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request.options[:headers]).not_to have_key('Host')
      end

      context 'when redirect URL uses http scheme' do
        let(:redirect_url) { 'http://example.com/redirected/path' }
        let(:resolved_uri) { Addressable::URI.parse("http://#{resolved_ip}/redirected/path") }

        it 'pins resolved IP with port 80' do
          request = handler.build_follow_request(response) { |_resp, _handler| nil }

          expect(request.options[:resolve]).to eq('slist:example.com:80:93.184.216.34')
        end
      end

      context 'when hostname was not replaced' do
        let(:validation_result) do
          Gitlab::HTTP_V2::UrlBlocker::Result.new(Addressable::URI.parse(redirect_url), nil, false)
        end

        it 'does not set resolve option' do
          request = handler.build_follow_request(response) { |_resp, _handler| nil }

          expect(request.options).not_to have_key(:resolve)
        end
      end

      it 'passes incremented redirect handler to callback' do
        callback_called = false
        next_handler_redirect_count = nil

        request = handler.build_follow_request(response) do |_resp, next_handler|
          callback_called = true
          next_handler_redirect_count = next_handler.send(:redirect_count)
        end

        request.on_complete.each do |callback|
          callback.call(instance_double(Typhoeus::Response, code: 200))
        end

        expect(callback_called).to be(true)
        expect(next_handler_redirect_count).to eq(1)
      end
    end

    context 'with credential headers on a cross-host redirect' do
      let(:headers) { { 'Authorization' => 'Bearer token', 'Cookie' => 'a=b', 'Accept' => 'application/json' } }
      let(:redirect_url) { 'https://blob-store.r2.cloudflarestorage.com/signed/path?sig=xyz' }
      let(:resolved_uri) { Addressable::URI.parse("https://#{resolved_ip}/signed/path?sig=xyz") }
      let(:validation_result) do
        Gitlab::HTTP_V2::UrlBlocker::Result.new(resolved_uri, 'blob-store.r2.cloudflarestorage.com', false)
      end

      include_context 'with stubbed url validation and DNS pinning'

      it 'strips credential headers but keeps non-credential headers' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request.options[:headers]).not_to have_key('Authorization')
        expect(request.options[:headers]).not_to have_key('Cookie')
        expect(request.options[:headers]).to include('Accept' => 'application/json')
      end

      it 'propagates the stripped headers to the next handler' do
        next_handler = nil
        request = handler.build_follow_request(response) { |_resp, handler| next_handler = handler }
        request.on_complete.each { |cb| cb.call(instance_double(Typhoeus::Response, code: 200)) }

        expect(next_handler.send(:headers)).not_to have_key('Authorization')
      end
    end

    context 'when the redirect target shares a suffix with the source but is not a subdomain' do
      using RSpec::Parameterized::TableSyntax

      let(:headers) { { 'Authorization' => 'Bearer token', 'Cookie' => 'a=b', 'Accept' => 'application/json' } }

      where(:redirect_url) do
        [
          'https://example.com.attacker.com/path',
          'https://evil-example.com/path',
          'https://notexample.com/path'
        ]
      end

      with_them do
        let(:resolved_uri) { Addressable::URI.parse("https://#{resolved_ip}/path") }
        let(:validation_result) do
          Gitlab::HTTP_V2::UrlBlocker::Result.new(resolved_uri, Addressable::URI.parse(redirect_url).host, false)
        end

        include_context 'with stubbed url validation and DNS pinning'

        it 'strips credential headers but keeps non-credential headers' do
          request = handler.build_follow_request(response) { |_resp, _handler| nil }

          expect(request.options[:headers]).not_to have_key('Authorization')
          expect(request.options[:headers]).not_to have_key('Cookie')
          expect(request.options[:headers]).to include('Accept' => 'application/json')
        end
      end
    end

    context 'with credential headers on a same-host or subdomain redirect' do
      include_context 'with stubbed url validation and DNS pinning'

      context 'when the redirect stays on the same host' do
        let(:redirect_url) { 'https://example.com/other/path' }

        it 'keeps the credential headers' do
          request = handler.build_follow_request(response) { |_resp, _handler| nil }

          expect(request.options[:headers]).to include('Authorization' => 'Bearer token')
        end
      end

      context 'when the redirect targets a subdomain of the source host' do
        let(:redirect_url) { 'https://cdn.example.com/other/path' }
        let(:resolved_uri) { Addressable::URI.parse("https://#{resolved_ip}/other/path") }
        let(:validation_result) do
          Gitlab::HTTP_V2::UrlBlocker::Result.new(resolved_uri, 'cdn.example.com', false)
        end

        it 'keeps the credential headers' do
          request = handler.build_follow_request(response) { |_resp, _handler| nil }

          expect(request.options[:headers]).to include('Authorization' => 'Bearer token')
        end
      end
    end

    context 'when the redirect target is an internal address' do
      using RSpec::Parameterized::TableSyntax

      where(:case_name, :redirect_url) do
        'localhost'         | 'http://localhost:3000/internal'
        'loopback'          | 'http://127.0.0.1:3333/internal'
        'IPv6 loopback'     | 'http://[::1]:3333/internal'
        '10.x private'      | 'http://10.0.0.1/internal'
        '172.16.x private'  | 'http://172.16.0.1/internal'
        '192.168.x private' | 'http://192.168.1.1/internal'
      end

      with_them do
        it 'returns nil' do
          expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
        end
      end
    end

    context 'when redirect URL is link-local address (AWS metadata)' do
      let(:redirect_url) { 'http://169.254.169.254/latest/meta-data/' }

      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!)
          .with(redirect_url, anything)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'Requests to the link local network are not allowed')
      end

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when max redirects exceeded' do
      let(:redirect_count) { described_class::MAX_REDIRECTS }

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when redirect count is one less than max' do
      let(:redirect_count) { described_class::MAX_REDIRECTS - 1 }

      include_context 'with stubbed url validation and DNS pinning'

      it 'returns a request' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request).to be_a(Typhoeus::Request)
      end
    end

    context 'when Location header is missing' do
      let(:response_headers) { Typhoeus::Response::Header.new({}) }

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when the Location header is an empty string' do
      let(:response_headers) { Typhoeus::Response::Header.new('Location' => '') }

      it 'returns nil without stripping credentials or building a request' do
        expect(VirtualRegistries::Upstreams::Remote::CrossHostCredentialFilter).not_to receive(:filter_headers)
        expect(VirtualRegistries::Upstreams::Remote::PinnedRequestBuilder).not_to receive(:build)

        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when headers are nil' do
      let(:response_headers) { nil }

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when the Location header is relative' do
      let(:response_code) { 307 }
      let(:response_headers) { Typhoeus::Response::Header.new('Location' => '/blobs/real') }

      it 'does not follow it (relative Locations are not resolved on this path)' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end
  end

  describe 'constants' do
    it 'has MAX_REDIRECTS set to 5' do
      expect(described_class::MAX_REDIRECTS).to eq(5)
    end

    it 'has correct REDIRECT_STATUS_CODES' do
      expect(described_class::REDIRECT_STATUS_CODES).to contain_exactly(301, 302, 303, 307, 308)
    end
  end
end

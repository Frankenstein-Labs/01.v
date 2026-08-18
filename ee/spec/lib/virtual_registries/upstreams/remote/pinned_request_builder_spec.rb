# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Remote::PinnedRequestBuilder, feature_category: :virtual_registry do
  describe '.build' do
    let(:url) { 'https://example.com/path' }
    let(:headers) { { 'Authorization' => 'Bearer token' } }
    let(:timeout) { 5 }
    let(:resolved_ip) { '93.184.216.34' }
    let(:resolved_uri) { Addressable::URI.parse("https://#{resolved_ip}/path") }
    let(:validation_result) { Gitlab::HTTP_V2::UrlBlocker::Result.new(resolved_uri, 'example.com', false) }

    subject(:request) { described_class.build(url, headers: headers, timeout: timeout) }

    context 'when the URL validates successfully' do
      # Stub the slist builder to return a sentinel string so assertions can
      # verify the host/port/ip we pin without depending on FFI internals.
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!).and_return(validation_result)
        allow(described_class).to receive(:build_resolve_slist) do |host, port, ip|
          "slist:#{host}:#{port}:#{ip}"
        end
      end

      it { is_expected.to be_a(Typhoeus::Request) }

      it 'configures the request as a HEAD that does not follow redirects' do
        expect(request.options).to include(
          method: :head,
          followlocation: false,
          timeout: timeout,
          headers: include(headers)
        )
      end

      it 'does not set a Host header' do
        expect(request.options[:headers]).not_to have_key('Host')
      end

      context 'when DNS rebinding protection replaced the hostname with the resolved IP' do
        let(:uri) { Addressable::URI.parse(request.base_url) }

        it 'keeps the original hostname in the request URL for TLS SNI and cert verification' do
          expect(uri).to have_attributes(
            scheme: 'https',
            host: 'example.com'
          )
        end

        it 'pins hostname:port to the resolved IP via CURLOPT_RESOLVE' do
          expect(request.options[:resolve]).to eq('slist:example.com:443:93.184.216.34')
        end

        context 'when the URL is http' do
          let(:url) { 'http://example.com/path' }
          let(:resolved_uri) { Addressable::URI.parse("http://#{resolved_ip}/path") }

          it 'pins using port 80' do
            expect(request.options[:resolve]).to eq('slist:example.com:80:93.184.216.34')
          end
        end

        context 'when the URL has an explicit non-default port' do
          let(:url) { 'https://example.com:8443/path' }
          let(:resolved_uri) { Addressable::URI.parse("https://#{resolved_ip}:8443/path") }

          it 'pins using the explicit port' do
            expect(request.options[:resolve]).to eq('slist:example.com:8443:93.184.216.34')
          end
        end
      end

      context 'when the hostname was not replaced (already an IP or rebinding protection not triggered)' do
        let(:validation_result) { Gitlab::HTTP_V2::UrlBlocker::Result.new(Addressable::URI.parse(url), nil, false) }

        it 'does not set the resolve option' do
          expect(request.options).not_to have_key(:resolve)
        end

        it 'passes the validated URI through unchanged' do
          expect(request.base_url).to eq(url)
        end
      end
    end

    context 'when the URL is blocked by UrlBlocker' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'blocked')
      end

      it { is_expected.to be_nil }
    end

    context 'with blocked addresses' do
      before do
        stub_application_setting(
          allow_local_requests_from_web_hooks_and_services: false,
          outbound_local_requests_whitelist: []
        )
      end

      using RSpec::Parameterized::TableSyntax

      where(:blocked_url) do
        [
          'http://localhost:3000/internal',
          'http://127.0.0.1:3333/internal',
          'http://[::1]:3333/internal',
          'http://10.0.0.1/internal',
          'http://172.16.0.1/internal',
          'http://192.168.1.1/internal'
        ]
      end

      with_them do
        let(:url) { blocked_url }

        it { is_expected.to be_nil }
      end
    end

    context 'when honoring instance outbound-local-requests settings' do
      using RSpec::Parameterized::TableSyntax

      let(:url) { 'http://10.0.0.1/internal' }

      where(:case_name, :app_settings, :expected_matcher) do
        'toggle on'              | { allow_local_requests_from_web_hooks_and_services: true } | be_a(Typhoeus::Request)
        'host in allowlist'      | { outbound_local_requests_whitelist: ['10.0.0.1'] }        | be_a(Typhoeus::Request)
        'neither permits (deny)' | {}                                                         | be_nil
      end

      with_them do
        before do
          stub_application_setting(app_settings)
        end

        it { is_expected.to expected_matcher }
      end
    end

    context 'for dns_rebind_protection guard' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!).and_return(validation_result)
      end

      it 'keeps dns_rebind_protection enabled' do
        described_class.build(url, headers: headers, timeout: timeout)

        expect(Gitlab::HTTP_V2::UrlBlocker).to have_received(:validate_url_with_proxy!)
          .with(url, hash_including(dns_rebind_protection: true))
      end
    end

    # Contract test: drive the real Ethon option path to guard against
    # regressions where the builder produces an option shape Ethon rejects
    # (e.g. Array<String> for :resolve, which raised Ethon::Errors::InvalidValue
    # at runtime and was missed by every stubbed / WebMock-based test).
    context 'for Ethon option-acceptance contract' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate_url_with_proxy!).and_return(validation_result)
      end

      it 'produces a resolve option that Ethon accepts without raising' do
        easy = Ethon::Easy.new

        expect do
          easy.http_request(
            request.base_url,
            request.options[:method],
            request.options.except(:method)
          )
        end.not_to raise_error
      ensure
        easy&.reset
      end

      it 'builds the resolve value as an FFI pointer (what CURLOPT_RESOLVE requires)' do
        expect(request.options[:resolve]).to be_a(FFI::Pointer)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Remote::CredentialSafeHeadRequest, :aggregate_failures, feature_category: :virtual_registry do
  let(:url) { 'https://registry.example.com/v2/group/image/blobs/sha256:abc' }
  let(:headers) { { 'Authorization' => 'Bearer token', 'Accept' => 'application/json' } }
  let(:timeout) { 5 }

  subject(:head) { described_class.head(url: url, headers: headers, timeout: timeout) }

  describe '.head' do
    context 'when the upstream responds without redirecting' do
      before do
        stub_request(:head, url).to_return(status: 200, headers: { 'etag' => 'v1' })
      end

      it 'returns the response and sends the credentials once' do
        expect(head.code).to eq(200)
        expect(a_request(:head, url).with(headers: { 'Authorization' => 'Bearer token' })).to have_been_made.once
      end
    end

    context 'when the redirect stays on the same host' do
      let(:target_url) { 'https://registry.example.com/blobs/real' }

      before do
        stub_request(:head, url).to_return(status: 307, headers: { 'Location' => target_url })
        stub_request(:head, target_url).to_return(status: 200, headers: { 'etag' => 'v1' })
      end

      it 'follows the redirect and keeps the credentials' do
        expect(head.code).to eq(200)
        expect(a_request(:head, target_url).with(headers: { 'Authorization' => 'Bearer token' })).to have_been_made
      end
    end

    context 'when the redirect targets a subdomain of the source host' do
      let(:target_url) { 'https://cdn.registry.example.com/blobs/real' }

      before do
        stub_request(:head, url).to_return(status: 302, headers: { 'Location' => target_url })
        stub_request(:head, target_url).to_return(status: 200)
      end

      it 'keeps the credentials' do
        head

        expect(a_request(:head, target_url).with(headers: { 'Authorization' => 'Bearer token' }))
          .to have_been_made.once
      end
    end

    context 'when the redirect crosses to a different host' do
      let(:target_url) { 'https://blob-store.r2.cloudflarestorage.com/signed/path?sig=xyz' }

      before do
        stub_request(:head, url).to_return(status: 307, headers: { 'Location' => target_url })
        stub_request(:head, target_url).to_return(status: 200, headers: { 'etag' => 'v1' })
      end

      it 'drops the credentials but keeps non-credential headers' do
        expect(head.code).to eq(200)

        expect(
          a_request(:head, target_url).with { |req| req.headers.key?('Authorization') }
        ).not_to have_been_made
        expect(
          a_request(:head, target_url).with(headers: { 'Accept' => 'application/json' })
        ).to have_been_made
      end
    end

    context 'when the redirect uses a relative Location' do
      let(:resolved_url) { 'https://registry.example.com/blobs/real' }

      before do
        stub_request(:head, url).to_return(status: 302, headers: { 'Location' => '/blobs/real' })
        stub_request(:head, resolved_url).to_return(status: 200)
      end

      it 'resolves it against the source URL and keeps the credentials (same host)' do
        head

        expect(a_request(:head, resolved_url).with(headers: { 'Authorization' => 'Bearer token' }))
          .to have_been_made.once
      end
    end

    context 'when the upstream redirects more than MAX_REDIRECTS times' do
      before do
        stub_request(:head, url).to_return(status: 302, headers: { 'Location' => url })
      end

      it 'stops following and raises RedirectionTooDeep so the caller can serve a stale cache entry' do
        expect { head }.to raise_error(Gitlab::HTTP::RedirectionTooDeep)
        expect(a_request(:head, url)).to have_been_made.times(described_class::MAX_REDIRECTS + 1)
      end
    end

    context 'with a multi-hop redirect chain (host -> subdomain -> other host)' do
      let(:headers) do
        {
          'Authorization' => 'Bearer token',
          'Accept' => 'application/json',
          'If-None-Match' => '"etag-123"'
        }
      end

      let(:subdomain_url) { 'https://cdn.registry.example.com/hop-b' }
      let(:cross_host_url) { 'https://blob-store.r2.cloudflarestorage.com/hop-c?sig=xyz' }

      before do
        stub_request(:head, url).to_return(status: 307, headers: { 'Location' => subdomain_url })
        stub_request(:head, subdomain_url).to_return(status: 307, headers: { 'Location' => cross_host_url })
        stub_request(:head, cross_host_url).to_return(status: 200, headers: { 'etag' => 'v1' })
      end

      it 'keeps credentials on the subdomain hop and drops them on the cross-host hop' do
        expect(head.code).to eq(200)

        expect(a_request(:head, subdomain_url).with(headers: { 'Authorization' => 'Bearer token' }))
          .to have_been_made.once
        expect(a_request(:head, cross_host_url).with { |req| req.headers.key?('Authorization') })
          .not_to have_been_made
      end

      it 'carries non-credential headers (Accept, If-None-Match) across every hop' do
        head

        expect(
          a_request(:head, cross_host_url)
            .with(headers: { 'Accept' => 'application/json', 'If-None-Match' => '"etag-123"' })
        ).to have_been_made.once
      end
    end

    context 'when the upstream returns a duplicated Location header' do
      let(:first_url) { 'https://registry.example.com/blobs/first' }
      let(:last_url) { 'https://registry.example.com/blobs/last' }

      before do
        stub_request(:head, url).to_return(status: 307, headers: { 'Location' => [first_url, last_url] })
        stub_request(:head, last_url).to_return(status: 200, headers: { 'etag' => 'v1' })
      end

      it 'follows the last Location value' do
        expect(head.code).to eq(200)
        expect(a_request(:head, last_url)).to have_been_made.once
        expect(a_request(:head, first_url)).not_to have_been_made
      end
    end

    context 'when the redirect is unfollowable' do
      using RSpec::Parameterized::TableSyntax

      where(:case_name, :location_headers) do
        'no Location header'    | {}
        'unparseable Location'  | { 'Location' => 'http://exa mple.com/x' }
        'Ruby-URI-invalid'      | { 'Location' => 'http://[:::]/x' }
        'invalid byte sequence' | { 'Location' => "https://exa\xFFmple.com/x" }
      end

      with_them do
        before do
          stub_request(:head, url).to_return(status: 302, headers: location_headers)
        end

        it 'returns the redirect response without following' do
          expect(head.code).to eq(302)
          expect(a_request(:head, url)).to have_been_made.once
        end
      end
    end

    context 'when a later hop raises a network error' do
      let(:cross_host_url) { 'https://blob-store.r2.cloudflarestorage.com/hop-2' }

      before do
        stub_request(:head, url).to_return(status: 307, headers: { 'Location' => cross_host_url })
        stub_request(:head, cross_host_url).to_raise(Errno::ECONNRESET)
      end

      it 'propagates the error from the later hop' do
        expect { head }.to raise_error(Errno::ECONNRESET)
      end
    end

    context 'when a redirect targets an internal address (SSRF)' do
      let(:internal_url) { 'http://127.0.0.1:8080/internal' }

      before do
        stub_request(:head, url).to_return(status: 307, headers: { 'Location' => internal_url })
      end

      it 'refuses to follow the blocked redirect' do
        expect { head }.to raise_error(Gitlab::HTTP_V2::BlockedUrlError)
        expect(a_request(:head, internal_url)).not_to have_been_made
      end
    end
  end
end

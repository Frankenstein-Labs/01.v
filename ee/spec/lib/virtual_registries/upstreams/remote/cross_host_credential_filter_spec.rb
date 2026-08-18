# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Remote::CrossHostCredentialFilter, :aggregate_failures, feature_category: :virtual_registry do
  describe '.filter_headers' do
    let(:headers) do
      {
        'Authorization' => 'Bearer token',
        'Cookie' => 'a=b',
        'Cookie2' => '$Version="1"',
        'Accept' => 'application/json'
      }
    end

    let(:source_url) { 'https://registry.example.com/v2/group/image/blobs/sha256:abc' }

    subject(:filtered) { described_class.filter_headers(headers, source_url: source_url, target_url: target_url) }

    context 'when the redirect stays on the same host' do
      let(:target_url) { 'https://registry.example.com/other/path' }

      it 'keeps every header' do
        expect(filtered).to eq(headers)
      end
    end

    context 'when the redirect targets a subdomain of the source host' do
      let(:target_url) { 'https://cdn.registry.example.com/other/path' }

      it 'keeps every header' do
        expect(filtered).to eq(headers)
      end
    end

    context 'when the redirect crosses to a different host' do
      let(:target_url) { 'https://blob-store.r2.cloudflarestorage.com/signed/path?sig=xyz' }

      it 'drops every credential header but keeps the rest' do
        described_class::CREDENTIAL_HEADERS.each do |header|
          expect(filtered.keys.map { |k| k.to_s.downcase }).not_to include(header)
        end
        expect(filtered).to include('Accept' => 'application/json')
      end
    end

    context 'when credential headers use symbol keys (Maven/npm upstreams)' do
      let(:headers) { { Authorization: 'Bearer token', Accept: 'application/json' } }
      let(:target_url) { 'https://blob-store.example.org/signed/path' }

      it 'still drops them case-insensitively' do
        expect(filtered).to eq({ Accept: 'application/json' })
      end
    end

    context 'when a host cannot be determined' do
      let(:source_url) { nil }
      let(:target_url) { 'https://registry.example.com/path' }

      it 'drops credential headers (fails closed)' do
        expect(filtered).not_to have_key('Authorization')
      end
    end

    context 'when the target URL has an invalid byte sequence' do
      let(:target_url) { "https://exa\xFFmple.com/path" }

      it 'drops credential headers (fails closed) instead of raising' do
        expect(filtered).not_to have_key('Authorization')
      end
    end
  end

  describe '.same_or_subdomain_host?' do
    using RSpec::Parameterized::TableSyntax

    where(:source_url, :target_url, :expected) do
      'https://example.com/a'      | 'https://example.com/b'              | true
      'https://example.com/a'      | 'https://cdn.example.com/b'          | true
      'https://example.com/a'      | 'https://a.b.example.com/b'          | true
      'https://EXAMPLE.com/a'      | 'https://example.COM/b'              | true
      'https://example.com/a'        | 'https://example.com./b'              | true
      'https://Bücher.example.com/a' | 'https://xn--bcher-kva.example.com/b' | true
      'https://example.com/a'      | 'https://other.com/b'                | false
      'https://example.com/a'      | 'https://example.com.attacker.com/b' | false
      'https://example.com/a'      | 'https://evil-example.com/b'         | false
      'https://example.com/a'      | 'https://notexample.com/b'           | false
      'https://example.com/a'      | '/relative/path'                     | false
      nil                          | 'https://example.com/b'              | false
    end

    with_them do
      it { expect(described_class.same_or_subdomain_host?(source_url, target_url)).to eq(expected) }
    end
  end

  describe '.host_for' do
    it 'returns the normalized (downcased) host for a valid URL' do
      expect(described_class.host_for('https://Registry.Example.COM/path')).to eq('registry.example.com')
    end

    it 'strips a trailing-dot FQDN so it matches its dotless form' do
      expect(described_class.host_for('https://cdn.example.com./path')).to eq('cdn.example.com')
    end

    it 'punycode-normalizes an IDN host so both encodings compare equal' do
      expect(described_class.host_for('https://Bücher.example.com/path')).to eq('xn--bcher-kva.example.com')
    end

    it 'returns nil for a relative path (no host)' do
      expect(described_class.host_for('/relative/path')).to be_nil
    end

    it 'returns nil for non-string input' do
      expect(described_class.host_for(nil)).to be_nil
    end

    it 'returns nil for a URL with an invalid byte sequence' do
      expect(described_class.host_for("https://exa\xFFmple.com/path")).to be_nil
    end
  end
end

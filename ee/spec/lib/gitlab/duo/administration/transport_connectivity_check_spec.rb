# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Administration::TransportConnectivityCheck, feature_category: :"self-hosted_models" do
  let(:ai_gateway_url) { 'https://ai-gw.example.com' }
  let(:duo_agent_platform_url) { 'dap.example.com:443' }
  let(:grpc_secure) { true }

  let(:tcp_socket) { instance_double(Socket, close: nil) }
  let(:ssl_socket) do
    instance_double(
      OpenSSL::SSL::SSLSocket, :hostname= => nil, :sync_close= => nil,
      connect: nil, post_connection_check: nil, peer_cert: peer_cert, close: nil
    )
  end

  let(:peer_cert) do
    instance_double(
      OpenSSL::X509::Certificate,
      subject: instance_double(OpenSSL::X509::Name, to_s: 'CN=ai-gw'),
      issuer: instance_double(OpenSSL::X509::Name, to_s: 'CN=Internal CA')
    )
  end

  subject(:results) { described_class.new.execute }

  before do
    allow(Gitlab::AiGateway).to receive(:self_hosted_url).and_return(ai_gateway_url)
    allow(Gitlab::DuoWorkflow::Client).to receive_messages(
      self_hosted_url: duo_agent_platform_url, secure?: grpc_secure
    )
    allow(Gitlab::X509::Certificate).to receive_messages(ca_certs_bundle: '', load_ca_certs_bundle: [])

    allow(Socket).to receive(:tcp).and_return(tcp_socket)
    allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl_socket)
  end

  describe '#execute' do
    context 'when both endpoints complete a verified TLS handshake' do
      it 'returns a trusted result for each endpoint', :aggregate_failures do
        expect(results.map(&:name)).to match_array(['AI Gateway', 'GitLab Duo Agent Platform (gRPC)'])
        expect(results).to all(have_attributes(status: :ok, tls: true, tls_verified: true))
        expect(results.first).to have_attributes(cert_subject: 'CN=ai-gw', cert_issuer: 'CN=Internal CA')
      end

      it 'verifies the certificate against the presented hostname' do
        results

        expect(ssl_socket).to have_received(:hostname=).with('ai-gw.example.com')
        expect(ssl_socket).to have_received(:post_connection_check).with('ai-gw.example.com')
      end
    end

    context 'with a single endpoint' do
      let(:duo_agent_platform_url) { nil }

      subject(:result) { described_class.new.execute.first }

      context 'when the certificate cannot be verified against trusted CAs' do
        before do
          call_count = 0
          allow(ssl_socket).to receive(:connect) do
            call_count += 1
            raise OpenSSL::SSL::SSLError, 'certificate verify failed' if call_count == 1
          end
        end

        it 'reaches the endpoint but marks TLS as untrusted', :aggregate_failures do
          expect(result).to have_attributes(status: :ok, tls_verified: false, cert_subject: 'CN=ai-gw')
          expect(ssl_socket).not_to have_received(:post_connection_check)
        end
      end

      context 'when the TLS handshake fails outright' do
        before do
          allow(ssl_socket).to receive(:connect).and_raise(
            OpenSSL::SSL::SSLError.new('SSL_connect returned=1 WRONG_VERSION_NUMBER')
          )
        end

        it 'returns an error result flagged as a TLS mismatch', :aggregate_failures do
          expect(result.status).to eq(:error)
          expect(result.tls_mismatch?).to be(true)
        end
      end

      context 'when the TCP connection is refused' do
        before do
          allow(Socket).to receive(:tcp).and_raise(Errno::ECONNREFUSED)
        end

        it 'returns an error result that is not a TLS mismatch', :aggregate_failures do
          expect(result.status).to eq(:error)
          expect(result.error).to be_a(Errno::ECONNREFUSED)
          expect(result.tls_mismatch?).to be(false)
        end
      end
    end

    context 'when the gRPC endpoint is insecure' do
      let(:ai_gateway_url) { nil }
      let(:grpc_secure) { false }

      it 'checks TCP reachability without a TLS handshake', :aggregate_failures do
        expect(results.first).to have_attributes(name: 'GitLab Duo Agent Platform (gRPC)', status: :ok, tls: false)
        expect(OpenSSL::SSL::SSLSocket).not_to have_received(:new)
      end
    end

    context 'when no endpoints are configured' do
      let(:ai_gateway_url) { nil }
      let(:duo_agent_platform_url) { nil }

      it 'returns an empty list' do
        expect(results).to be_empty
      end
    end

    context 'when the AI Gateway URL is malformed' do
      let(:ai_gateway_url) { 'http://[invalid' }
      let(:duo_agent_platform_url) { nil }

      it 'skips the endpoint instead of raising' do
        expect(results).to be_empty
      end
    end
  end

  describe '#proxy_environment' do
    subject(:proxy_environment) { described_class.new.proxy_environment }

    context 'when proxy variables are set' do
      before do
        stub_env('HTTPS_PROXY', 'http://proxy.example.com:8080')
        stub_env('NO_PROXY', 'internal.example.com')
        stub_env('grpc_proxy', 'http://grpc-proxy.example.com:8080')
        stub_env('no_grpc_proxy', 'dap.internal.example.com')
      end

      it 'returns only the variables that are set, including the gRPC-specific ones' do
        expect(proxy_environment).to include(
          'HTTPS_PROXY' => 'http://proxy.example.com:8080',
          'NO_PROXY' => 'internal.example.com',
          'grpc_proxy' => 'http://grpc-proxy.example.com:8080',
          'no_grpc_proxy' => 'dap.internal.example.com'
        )
      end
    end

    context 'when no proxy variables are set' do
      before do
        %w[HTTP_PROXY http_proxy HTTPS_PROXY https_proxy NO_PROXY no_proxy grpc_proxy no_grpc_proxy]
          .each { |name| stub_env(name, '') }
      end

      it 'returns an empty hash' do
        expect(proxy_environment).to eq({})
      end
    end
  end
end

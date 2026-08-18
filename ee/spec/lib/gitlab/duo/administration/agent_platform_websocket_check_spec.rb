# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Administration::AgentPlatformWebsocketCheck, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }

  let(:base_url) { 'http://gitlab.example.com' }
  let(:ws_url) { 'http://gitlab.example.com/api/v4/ai/duo_workflows/ws' }
  let(:token) { 'test-token' }
  let(:response_lines) { ["HTTP/1.1 101 Switching Protocols\r\n", "Upgrade: websocket\r\n", "\r\n"] }
  let(:socket) { instance_double(TCPSocket, write: nil, close: nil, wait_readable: true) }

  let(:oauth_token) { instance_double(OauthAccessToken, plaintext_token: token) }
  let(:context_service) { instance_double(Ai::DuoWorkflows::WorkflowContextGenerationService) }

  subject(:result) { described_class.new(user).execute }

  before do
    stub_config_setting(url: base_url)

    allow(Ai::DuoWorkflows::WorkflowContextGenerationService).to receive(:new).and_return(context_service)
    allow(context_service).to receive(:generate_oauth_token)
      .and_return(ServiceResponse.success(payload: { oauth_access_token: oauth_token }))

    allow(Socket).to receive(:tcp).and_return(socket)
    allow(socket).to receive(:gets).and_return(*response_lines)
  end

  describe '#execute' do
    context 'when the upgrade handshake succeeds' do
      it 'returns an ok result with the parsed status and headers', :aggregate_failures do
        expect(result).to have_attributes(
          status: :ok,
          http_status: 101,
          url: ws_url,
          headers: { 'Upgrade' => 'websocket' }
        )
        expect(result.ok?).to be(true)
        expect(result.response_time_ms).to be_a(Numeric)
      end

      it 'sends an authenticated WebSocket upgrade handshake' do
        result

        expect(socket).to have_received(:write).with(
          a_string_including('Upgrade: websocket', 'Connection: Upgrade', "Authorization: Bearer #{token}")
        )
      end
    end

    context 'when the endpoint rejects the connection' do
      let(:response_lines) { ["HTTP/1.1 403 Forbidden\r\n", "\r\n"] }

      it 'classifies the result as rejected' do
        expect(result).to have_attributes(status: :rejected, http_status: 403)
      end
    end

    context 'when the connection is not upgraded' do
      let(:response_lines) { ["HTTP/1.1 200 OK\r\n", "\r\n"] }

      it 'classifies the result as not upgraded' do
        expect(result).to have_attributes(status: :not_upgraded, http_status: 200)
      end
    end

    context 'with an HTTPS instance URL' do
      let(:base_url) { 'https://gitlab.example.com' }
      let(:ws_url) { 'https://gitlab.example.com/api/v4/ai/duo_workflows/ws' }
      let(:ssl_socket) { instance_double(OpenSSL::SSL::SSLSocket, write: nil, close: nil, wait_readable: true) }

      before do
        allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl_socket)
        allow(ssl_socket).to receive(:hostname=)
        allow(ssl_socket).to receive(:sync_close=)
        allow(ssl_socket).to receive(:gets).and_return(*response_lines)
      end

      context 'when the certificate is trusted' do
        before do
          allow(ssl_socket).to receive(:connect).and_return(ssl_socket)
        end

        it 'verifies the certificate and returns an ok result' do
          expect(result).to have_attributes(status: :ok, tls_verified: true)
        end
      end

      context 'when the certificate is not trusted' do
        before do
          call_count = 0
          allow(ssl_socket).to receive(:connect) do
            call_count += 1
            raise OpenSSL::SSL::SSLError, 'certificate verify failed' if call_count == 1

            ssl_socket
          end
        end

        it 'falls back to an unverified connection and records it', :aggregate_failures do
          expect(result).to have_attributes(status: :ok, tls_verified: false)
        end
      end
    end

    context 'when the socket cannot connect' do
      before do
        allow(Socket).to receive(:tcp).and_raise(Errno::ECONNREFUSED.new('Connection refused'))
      end

      it 'returns an error result capturing the exception', :aggregate_failures do
        expect(result.status).to eq(:error)
        expect(result.error).to be_a(Errno::ECONNREFUSED)
        expect(result.ok?).to be(false)
      end
    end

    context 'when the server does not respond before the read timeout' do
      before do
        allow(socket).to receive(:wait_readable).and_return(false)
      end

      it 'returns an error result indicating a timeout' do
        expect(result.status).to eq(:error)
        expect(result.error).to be_a(Timeout::Error)
      end
    end

    context 'when the token cannot be generated' do
      before do
        allow(context_service).to receive(:generate_oauth_token)
          .and_return(ServiceResponse.error(message: 'no seat'))
      end

      it 'returns an error result and never opens a socket', :aggregate_failures do
        expect(result.status).to eq(:error)
        expect(result.error.message).to eq('no seat')
        expect(Socket).not_to have_received(:tcp)
      end
    end
  end
end

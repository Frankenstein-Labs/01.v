# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::GcpClient, feature_category: :secret_detection do
  using RSpec::Parameterized::TableSyntax

  let(:client) { described_class.new }
  let(:response) { instance_double(Net::HTTPResponse) }
  let(:valid_access_token) { "ya29.a0ARrdaM8yqkBv2Xl3z_#{'A' * 100}" }

  describe '#verify_token' do
    context 'with valid token format' do
      before do
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
      end

      it 'accepts a valid OAuth access token format' do
        allow(response).to receive_messages(code: '200', body: '{}')
        expect(client.verify_token(valid_access_token).active?).to be true
      end

      context 'with different response scenarios' do
        where(:code, :body, :expected_status_check) do
          '200' | '{"email": "test@test.com"}' | :active?
          '400' | '{"error": "invalid"}'       | :inactive?
          '401' | '{"error": "unauthorized"}'  | :inactive?
          '404' | 'Not Found'                  | :unknown?
          '200' | ''                           | :active?
        end

        with_them do
          before do
            allow(response).to receive_messages(code: code, body: body)
          end

          it 'handles response correctly' do
            result = client.verify_token(valid_access_token)
            expect(result.send(expected_status_check)).to be true
          end
        end
      end

      context 'with rate limiting and service errors' do
        where(:code, :error_class, :error_pattern) do
          '429' | described_class::RateLimitError | /rate limited/
          '500' | described_class::NetworkError   | /service error/
          '502' | described_class::NetworkError   | /service error/
          '503' | described_class::NetworkError   | /service error/
          '504' | described_class::NetworkError   | /service error/
        end

        with_them do
          before do
            allow(response).to receive(:code).and_return(code)
          end

          it 'raises appropriate error' do
            expect { client.verify_token(valid_access_token) }
              .to raise_error(error_class, error_pattern)
          end
        end
      end

      context 'with network errors' do
        it 'raises NetworkError on timeout' do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(Net::ReadTimeout.new('timeout'))

          expect { client.verify_token(valid_access_token) }
            .to raise_error(described_class::NetworkError)
        end

        it 'raises NetworkError on standard error' do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(StandardError.new('unexpected'))

          expect { client.verify_token(valid_access_token) }
            .to raise_error(described_class::NetworkError, /Unexpected error/)
        end
      end

      context 'with response error' do
        before do
          allow(response).to receive_messages(code: '200', body: '{}')
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
          allow(client).to receive(:analyze_gcp_response)
            .and_raise(described_class::ResponseError.new('Invalid response format'))
        end

        it 'returns unknown status' do
          result = client.verify_token(valid_access_token)
          expect(result.unknown?).to be true
          expect(result.metadata[:partner]).to eq('GCP')
        end
      end

      it 'URL encodes token in request' do
        token = "ya29.a0ARrdaM8yqkBv2Xl3z_test-token#{'A' * 80}"
        allow(response).to receive_messages(code: '200', body: '{}')

        client.verify_token(token)

        expected_url = "#{described_class::TOKENINFO_ENDPOINT}?access_token=#{CGI.escape(token)}"
        expect(Integrations::Clients::HTTP).to have_received(:get)
          .with(expected_url, hash_including(:headers))
      end
    end

    context 'with token formats tokeninfo cannot verify' do
      where(:token) do
        [
          ["AIza#{'A' * 35}"], # API key
          ["GOCSPX-#{'a' * 22}"] # Client secret
        ]
      end

      with_them do
        it 'returns unknown status without API call', :aggregate_failures do
          expect(Integrations::Clients::HTTP).not_to receive(:get)

          result = client.verify_token(token)
          expect(result.unknown?).to be true
        end
      end
    end

    context 'with invalid token format' do
      where(:token) do
        ['AIzaSyD', 'ya29.short', 'GOCSPX', 'invalid', '', nil]
      end

      with_them do
        it 'returns unknown status without API call' do
          expect(Integrations::Clients::HTTP).not_to receive(:get)

          result = client.verify_token(token)
          expect(result.unknown?).to be true
        end
      end
    end
  end
end

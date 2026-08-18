# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::PostmanClient, feature_category: :secret_detection do
  using RSpec::Parameterized::TableSyntax

  let(:client) { described_class.new }
  let(:response) { instance_double(Net::HTTPResponse) }
  let(:valid_api_key) { "PMAK-#{SecureRandom.hex(12)}-#{SecureRandom.hex(17)}" }

  describe '#verify_token' do
    context 'with valid token format' do
      before do
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
      end

      context 'with different response scenarios' do
        where(:code, :expected_status_check) do
          '200' | :active?
          '401' | :inactive?
          '404' | :unknown?
          '200' | :active?
        end

        with_them do
          before do
            allow(response).to receive_messages(code: code)
          end

          it 'handles response correctly' do
            result = client.verify_token(valid_api_key)
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
            expect { client.verify_token(valid_api_key) }
              .to raise_error(error_class, error_pattern)
          end
        end
      end

      context 'with network errors' do
        it 'raises NetworkError on timeout' do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(Net::ReadTimeout.new('timeout'))

          expect { client.verify_token(valid_api_key) }
            .to raise_error(described_class::NetworkError)
        end

        it 'raises NetworkError on connection refused' do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(Errno::ECONNREFUSED.new('connection refused'))

          expect { client.verify_token(valid_api_key) }
            .to raise_error(described_class::NetworkError)
        end

        it 'raises NetworkError on standard error' do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(StandardError.new('unexpected'))

          expect { client.verify_token(valid_api_key) }
            .to raise_error(described_class::NetworkError, /Unexpected error/)
        end
      end

      context 'with response error' do
        before do
          allow(response).to receive_messages(code: '200', body: '{}')
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
          allow(client).to receive(:analyze_postman_response)
            .and_raise(described_class::ResponseError.new('Invalid response format'))
        end

        it 'returns unknown status' do
          result = client.verify_token(valid_api_key)
          expect(result.unknown?).to be true
          expect(result.metadata[:partner]).to eq('POSTMAN')
          expect(result.metadata[:verified_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
        end
      end

      it 'sends token in X-API-Key header' do
        allow(response).to receive_messages(code: '200', body: '{}')

        client.verify_token(valid_api_key)

        expect(Integrations::Clients::HTTP).to have_received(:get)
          .with(
            described_class::API_ENDPOINT,
            headers: hash_including(
              'X-API-Key' => valid_api_key,
              'Accept' => 'application/json'
            )
          )
      end

      it 'includes partner name in metadata' do
        allow(response).to receive_messages(code: '200', body: '{}')

        result = client.verify_token(valid_api_key)

        expect(result.metadata[:partner]).to eq('POSTMAN')
        expect(result.metadata[:verified_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end
    end

    context 'with invalid token format' do
      where(:token) do
        [
          ['PMAK-invalid'], # Too short
          ['PMAK-1234567890abcdef-toolong'], # Wrong structure
          ['invalid-token'],                        # No PMAK prefix
          [''],                                     # Empty string
          [nil],                                    # Nil value
          ['PMAK-UPPERCASE-LETTERS'],             # Uppercase letters (should be lowercase hex)
          ['PMAK-123456789012345678901234-1234']  # Wrong segment lengths
        ]
      end

      with_them do
        it 'returns unknown status without API call' do
          expect(Integrations::Clients::HTTP).not_to receive(:get)

          result = client.verify_token(token)
          expect(result.unknown?).to be true
        end
      end
    end

    context 'with valid Postman token formats' do
      where(:token) do
        [
          ["PMAK-#{SecureRandom.hex(12)}-#{SecureRandom.hex(17)}"],
          ["PMAK-abcdef1234567890abcdef12-abcdef1234567890abcdef1234567890ab"],
          ["PMAK-000000000000000000000000-0000000000000000000000000000000000"]
        ]
      end

      with_them do
        it 'accepts valid Postman API key formats' do
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
          allow(response).to receive_messages(code: '200', body: '{}')

          expect(client.verify_token(token).active?).to be true
        end
      end
    end

    context 'with rate limit considerations' do
      before do
        allow(response).to receive(:code).and_return('429')
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
      end

      it 'raises RateLimitError for 429 responses' do
        expect { client.verify_token(valid_api_key) }
          .to raise_error(described_class::RateLimitError, /Postman API rate limited/)
      end

      it 'includes response code in rate limit error message' do
        expect { client.verify_token(valid_api_key) }
          .to raise_error(described_class::RateLimitError, /429/)
      end
    end

    context 'with unexpected response codes' do
      before do
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        allow(response).to receive_messages(code: code, body: '{}')
      end

      where(:code) do
        %w[400 403 405 422 301 302]
      end

      with_them do
        it 'returns unknown status for unexpected response codes' do
          result = client.verify_token(valid_api_key)
          expect(result.unknown?).to be true
        end
      end
    end

    context 'with retryable errors' do
      it 'propagates RateLimitError for worker retry handling' do
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        allow(response).to receive(:code).and_return('429')

        expect { client.verify_token(valid_api_key) }
          .to raise_error(described_class::RateLimitError)
      end

      it 'propagates NetworkError for worker retry handling' do
        allow(Integrations::Clients::HTTP).to receive(:get)
          .and_raise(Net::ReadTimeout.new('timeout'))

        expect { client.verify_token(valid_api_key) }
          .to raise_error(described_class::NetworkError)
      end
    end
  end
end

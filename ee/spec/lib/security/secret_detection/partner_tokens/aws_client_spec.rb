# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::AwsClient, feature_category: :secret_detection do
  let(:client) { described_class.new }
  let(:valid_access_key) { 'AKIAIOSFODNN7EXAMPLE' }
  let(:response) { instance_double(Net::HTTPResponse) }

  describe '#verify_token' do
    context 'with valid AWS access key format' do
      using RSpec::Parameterized::TableSyntax

      where(:error_code, :expected_active) do
        'SignatureDoesNotMatch'  | true
        'InvalidSignature'       | true
        'InvalidAccessKeyId'     | false
      end

      with_them do
        let(:xml_response) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <ErrorResponse>
              <Error>
                <Code>#{error_code}</Code>
                <Message>Error message</Message>
              </Error>
            </ErrorResponse>
          XML
        end

        before do
          allow(response).to receive_messages(code: '403', body: xml_response)
          allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
        end

        it 'handles AWS error response correctly' do
          result = client.verify_token(valid_access_key)

          expect(result.active?).to eq(expected_active)
          expect(result.metadata[:partner]).to eq('AWS')
          expect(result.metadata[:verified_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
        end
      end

      context 'with rate limiting' do
        using RSpec::Parameterized::TableSyntax

        where(:status_code, :error_class) do
          429 | described_class::RateLimitError
          503 | described_class::RateLimitError
          500 | described_class::NetworkError
          502 | described_class::NetworkError
          504 | described_class::NetworkError
        end

        with_them do
          before do
            allow(response).to receive(:code).and_return(status_code.to_s)
            allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
          end

          it 'raises appropriate error' do
            expect { client.verify_token(valid_access_key) }
              .to raise_error(error_class, /#{status_code}/)
          end
        end
      end

      context 'with network errors' do
        it 'raises NetworkError on timeout' do
          allow(Integrations::Clients::HTTP).to receive(:post)
            .and_raise(Gitlab::HTTP::HTTP_TIMEOUT_ERRORS.first.new('timeout'))

          expect { client.verify_token(valid_access_key) }
            .to raise_error(described_class::NetworkError, /timeout/)
        end

        it 'raises NetworkError on standard error' do
          allow(Integrations::Clients::HTTP).to receive(:post)
            .and_raise(StandardError.new('unexpected'))

          expect { client.verify_token(valid_access_key) }
            .to raise_error(described_class::NetworkError, /unexpected/)
        end
      end

      context 'with unexpected 200 response' do
        before do
          allow(response).to receive_messages(code: '200', body: '')
          allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
        end

        it 'returns active status' do
          result = client.verify_token(valid_access_key)

          expect(result.active?).to be true
          expect(result.metadata[:partner]).to eq('AWS')
        end
      end

      context 'with unexpected AWS response codes' do
        before do
          allow(response).to receive_messages(code: '400', body: 'Bad Request')
          allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
        end

        it 'returns unknown response for unexpected status code' do
          result = client.verify_token(valid_access_key)

          expect(result.unknown?).to be true
          expect(result.metadata[:partner]).to eq('AWS')
        end
      end

      context 'with blank XML response body' do
        before do
          allow(response).to receive_messages(code: '403', body: '')
          allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
        end

        it 'handles blank XML response gracefully' do
          result = client.verify_token(valid_access_key)

          expect(result.inactive?).to be true
          expect(result.metadata[:partner]).to eq('AWS')
          expect(result.metadata[:verified_at]).to be_present
        end
      end

      context 'with nil XML response body' do
        before do
          allow(response).to receive_messages(code: '403', body: nil)
          allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
        end

        it 'handles nil XML response gracefully' do
          result = client.verify_token(valid_access_key)

          expect(result.inactive?).to be true
          expect(result.metadata[:partner]).to eq('AWS')
        end
      end

      context 'when response parsing fails' do
        before do
          allow(response).to receive_messages(code: '403', body: 'invalid xml')
          allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
        end

        it 'returns unknown response' do
          result = client.verify_token(valid_access_key)

          expect(result.unknown?).to be true
          expect(result.metadata[:partner]).to eq('AWS')
        end
      end
    end

    context 'with invalid AWS access key format' do
      using RSpec::Parameterized::TableSyntax

      where(:key, :description) do
        'AWSKEY1234567890'      | 'wrong prefix'
        'AKIA123456789012345'   | 'too short'
        'AKIA12345678901234567' | 'too long'
        'AKIA123456789012345a'  | 'lowercase letter'
        'AKIA12345678901234!'   | 'special character'
        ''                      | 'empty'
        nil                     | 'nil'
      end

      with_them do
        before do
          allow(Integrations::Clients::HTTP).to receive(:post)
        end

        it "rejects #{description}" do
          result = client.verify_token(key)

          expect(result.unknown?).to be true
          expect(result.metadata[:partner]).to eq('AWS')
        end

        it "doesn't make HTTP request for #{description}" do
          client.verify_token(key)
          expect(Integrations::Clients::HTTP).not_to have_received(:post)
        end
      end
    end
  end
end

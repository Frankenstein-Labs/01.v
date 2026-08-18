# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::OpenaiClient, feature_category: :secret_detection do
  let(:client) { described_class.new }
  let(:valid_token) { "sk-proj-#{'a' * 40}" }
  let(:response) { instance_double(Net::HTTPResponse) }

  it_behaves_like 'a partner token client',
    http_method: :get,
    malformed_tokens: ['sk-abc', 'sk-proj-short', "sk-proj-#{'a' * 39}", "sk-proj-#{'a' * 191}", '', nil]

  describe '#verify_token' do
    using RSpec::Parameterized::TableSyntax

    context 'with vendor status mapping' do
      where(:status_code, :body, :predicate) do
        200 | '{}' | :active?
        401 | '{"error":{"code":"invalid_api_key"}}' | :inactive?
        401 | '{}' | :unknown?
        404 | '{}' | :unknown?
      end

      with_them do
        before do
          allow(response).to receive_messages(code: status_code.to_s, body: body)
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        end

        it 'classifies the token' do
          expect(client.verify_token(valid_token).public_send(predicate)).to be(true)
        end
      end
    end

    context 'with a 401 that is not an invalid key' do
      before do
        allow(response).to receive_messages(
          code: '401',
          body: '{"error":{"message":"Your account is not part of an organization",' \
            '"type":"invalid_request_error","code":null}}'
        )
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
      end

      # OpenAI returns 401 for an organization mismatch, an account with no
      # organization, and an IP outside the allowlist. The key is live in all
      # three, so it must never be reported as dead.
      it 'returns unknown, never inactive' do
        result = client.verify_token(valid_token)

        expect(result.unknown?).to be(true)
        expect(result.inactive?).to be(false)
      end
    end

    context 'with rate limiting and service errors' do
      where(:status_code, :error_class) do
        429 | described_class::RateLimitError
        500 | described_class::NetworkError
        504 | described_class::NetworkError
      end

      with_them do
        before do
          allow(response).to receive_messages(code: status_code.to_s, body: '')
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        end

        it 'raises the appropriate error' do
          expect { client.verify_token(valid_token) }.to raise_error(error_class, /#{status_code}/)
        end
      end
    end
  end
end

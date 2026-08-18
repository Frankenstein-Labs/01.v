# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::StripeClient, feature_category: :secret_detection do
  let(:client) { described_class.new }
  let(:valid_token) { "sk_live_#{'a' * 99}" }
  let(:response) { instance_double(Net::HTTPResponse) }

  it_behaves_like 'a partner token client',
    http_method: :get,
    malformed_tokens: ['sk_test_abc', 'pk_live_abc', "sk_live_#{'a' * 24}", '', nil]

  describe '#verify_token' do
    using RSpec::Parameterized::TableSyntax

    context 'with vendor status mapping' do
      where(:status_code, :predicate) do
        200 | :active?
        401 | :inactive?
      end

      with_them do
        before do
          allow(response).to receive_messages(code: status_code.to_s, body: '{}')
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        end

        it 'classifies the token' do
          expect(client.verify_token(valid_token).public_send(predicate)).to be(true)
        end
      end
    end

    it 'authenticates with the key as HTTP Basic username' do
      allow(response).to receive_messages(code: '200', body: '{}')
      expected = "Basic #{Base64.strict_encode64("#{valid_token}:")}"
      expect(Integrations::Clients::HTTP).to receive(:get)
        .with(described_class::API_ENDPOINT, headers: hash_including('Authorization' => expected))
        .and_return(response)

      client.verify_token(valid_token)
    end

    context 'with rate limiting and service errors' do
      where(:status_code, :error_class) do
        429 | described_class::RateLimitError
        500 | described_class::NetworkError
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

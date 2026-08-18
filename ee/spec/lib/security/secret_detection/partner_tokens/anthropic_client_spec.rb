# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::AnthropicClient, feature_category: :secret_detection do
  let(:client) { described_class.new }
  let(:valid_token) { "sk-ant-api03-#{'a' * 95}" }
  let(:response) { instance_double(Net::HTTPResponse) }

  it_behaves_like 'a partner token client',
    http_method: :get,
    malformed_tokens: ['sk-ant', 'sk-xxx-abc', "sk-ant-api03-#{'a' * 94}", '', nil]

  describe '#verify_token' do
    using RSpec::Parameterized::TableSyntax

    context 'with vendor status mapping' do
      where(:status_code, :predicate, :reason) do
        200 | :active?   | 'the key authenticated'
        401 | :inactive? | 'authentication_error'
        403 | :unknown?  | 'permission_error, key may be live but scoped (unknown-never-inactive)'
        400 | :unknown?  | 'unmapped on a read-only endpoint (unknown-never-inactive)'
      end

      with_them do
        before do
          allow(response).to receive_messages(code: status_code.to_s, body: '{}')
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        end

        it "classifies the token when #{params[:reason]}" do
          expect(client.verify_token(valid_token).public_send(predicate)).to be(true)
        end
      end
    end

    context 'with rate limiting and service errors' do
      where(:status_code, :error_class) do
        429 | described_class::RateLimitError
        500 | described_class::NetworkError
        529 | described_class::NetworkError
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

    it 'sends the token in the x-api-key header with a version' do
      allow(response).to receive_messages(code: '200', body: '{}')
      expect(Integrations::Clients::HTTP).to receive(:get)
        .with(
          described_class::API_ENDPOINT,
          headers: hash_including('x-api-key' => valid_token, 'anthropic-version' => described_class::API_VERSION)
        )
        .and_return(response)

      client.verify_token(valid_token)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::GithubClient, feature_category: :secret_detection do
  let(:client) { described_class.new }
  let(:valid_token) { "ghp_#{'a' * 36}" }
  let(:response) { instance_double(Net::HTTPResponse) }

  it_behaves_like 'a partner token client',
    http_method: :get,
    malformed_tokens: ['github_pat_x', 'ghp_short', '', nil]

  describe '#verify_token' do
    using RSpec::Parameterized::TableSyntax

    context 'with vendor status mapping' do
      where(:status_code, :predicate) do
        200 | :active?
        401 | :inactive?
      end

      with_them do
        before do
          allow(response).to receive(:code).and_return(status_code.to_s)
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        end

        it 'returns the appropriate status' do
          expect(client.verify_token(valid_token).public_send(predicate)).to be(true)
        end
      end
    end

    context 'with rate limiting' do
      where(:status_code, :error_class) do
        403 | described_class::RateLimitError
        429 | described_class::RateLimitError
        500 | described_class::NetworkError
        503 | described_class::NetworkError
      end

      with_them do
        before do
          allow(response).to receive(:code).and_return(status_code.to_s)
          allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
        end

        it 'raises the appropriate error' do
          expect { client.verify_token(valid_token) }.to raise_error(error_class, /#{status_code}/)
        end
      end
    end

    it 'sends the token as a Bearer credential' do
      allow(response).to receive(:code).and_return('200')
      expect(Integrations::Clients::HTTP).to receive(:get)
        .with(described_class::API_ENDPOINT, headers: hash_including('Authorization' => "Bearer #{valid_token}"))
        .and_return(response)

      client.verify_token(valid_token)
    end
  end
end

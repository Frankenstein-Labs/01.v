# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::BaseClient, feature_category: :secret_detection do
  let(:client) { described_class.new }
  let(:uri) { URI.parse('https://example.com/api') }
  let(:response) { instance_double(Net::HTTPResponse, body: '{"test": "data"}', code: '200') }

  describe '#verify_partner_token' do
    it 'raises NotImplementedError' do
      expect { client.verify_partner_token('test-token') }
        .to raise_error(NotImplementedError, 'Subclasses must implement verify_partner_token')
    end
  end

  describe '#valid_format?' do
    it 'raises NotImplementedError' do
      expect { client.valid_format?('test-token') }
        .to raise_error(NotImplementedError, 'Subclasses must implement valid_format?')
    end
  end

  describe 'TokenStatus' do
    using RSpec::Parameterized::TableSyntax

    where(:status_value, :is_active, :is_inactive, :is_unknown) do
      :active   | true  | false | false
      :inactive | false | true  | false
      :unknown  | false | false | true
    end

    with_them do
      let(:status) { described_class::TokenStatus.new(status: status_value) }

      it 'returns expected activity status' do
        expect(status.active?).to eq(is_active)
        expect(status.inactive?).to eq(is_inactive)
        expect(status.unknown?).to eq(is_unknown)
      end
    end
  end

  describe '#make_request' do
    subject(:make_request) { client.send(:make_request, uri) }

    context 'when request is successful' do
      before do
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
      end

      it 'returns response' do
        expect(make_request).to eq(response)
      end
    end

    context 'when handling errors' do
      context 'when timeout errors occur' do
        [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Gitlab::HTTP_V2::ReadTotalTimeout].each do |error_class|
          context "with #{error_class}" do
            before do
              allow(Integrations::Clients::HTTP).to receive(:get)
                .and_raise(error_class.new('timeout'))
            end

            it 'raises NetworkError' do
              expect { make_request }.to raise_error(described_class::NetworkError, /Request timeout/)
            end
          end
        end
      end

      context 'when connection errors occur' do
        [Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError].each do |error_class|
          context "with #{error_class}" do
            before do
              allow(Integrations::Clients::HTTP).to receive(:get)
                .and_raise(error_class.new('connection failed'))
            end

            it 'raises NetworkError' do
              expect { make_request }.to raise_error(described_class::NetworkError, /Connection error/)
            end
          end
        end
      end

      context 'with Net::HTTPError' do
        before do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(Net::HTTPError.new('http error', nil))
        end

        it 'raises NetworkError' do
          expect { make_request }.to raise_error(described_class::NetworkError, /HTTP error/)
        end
      end

      context 'with StandardError' do
        before do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(StandardError.new('unexpected'))
        end

        it 'raises NetworkError' do
          expect { make_request }.to raise_error(described_class::NetworkError, /Unexpected error/)
        end
      end
    end

    context 'with POST request' do
      let(:headers) { { 'Content-Type' => 'application/json' } }
      let(:body) { '{"key": "value"}' }

      before do
        allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
      end

      it 'makes POST request with body and headers' do
        client.send(:make_request, uri, method: :post, headers: headers, body: body)

        expect(Integrations::Clients::HTTP).to have_received(:post)
          .with(uri, body: body, headers: headers)
      end
    end
  end

  describe '#parse_json_response' do
    using RSpec::Parameterized::TableSyntax

    where(:body, :expected) do
      '{"test": "data"}' | { 'test' => 'data' }
      ''                 | {}
      nil                | {}
    end

    with_them do
      let(:response) { instance_double(Net::HTTPResponse, body: body) }

      it 'returns expected result' do
        expect(client.send(:parse_json_response, response)).to eq(expected)
      end
    end

    context 'with invalid JSON' do
      let(:response) { instance_double(Net::HTTPResponse, body: 'invalid{') }

      it 'raises ResponseError' do
        expect { client.send(:parse_json_response, response) }
          .to raise_error(described_class::ResponseError, /Invalid JSON response/)
      end
    end
  end

  describe '#parse_xml_response' do
    context 'with valid XML' do
      let(:response) { instance_double(Net::HTTPResponse, body: '<?xml version="1.0"?><root><test>data</test></root>') }

      it 'parses XML' do
        result = client.send(:parse_xml_response, response)
        expect(result).to be_a(Nokogiri::XML::Document)
        expect(result.xpath('//test').text).to eq('data')
      end
    end

    context 'with empty body' do
      let(:response) { instance_double(Net::HTTPResponse, body: '') }

      it 'returns empty hash' do
        expect(client.send(:parse_xml_response, response).to_s).to eq(Nokogiri::XML('<empty/>').to_s)
      end
    end

    context 'with invalid XML' do
      let(:response) { instance_double(Net::HTTPResponse, body: '<invalid><xml>') }

      it 'raises ResponseError' do
        expect { client.send(:parse_xml_response, response) }
          .to raise_error(described_class::ResponseError, /Invalid XML response/)
      end
    end
  end

  describe 'response helpers' do
    using RSpec::Parameterized::TableSyntax

    where(:status, :expected_method) do
      :active   | :active?
      :inactive | :inactive?
      :unknown  | :unknown?
    end

    with_them do
      it "creates #{params[:status]} TokenStatus with basic metadata" do
        result = client.send(:token_response, status)

        expect(result.send(expected_method)).to be true
        expect(result.metadata[:partner]).to eq('BASE')
        expect(result.metadata[:verified_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end
    end
  end

  describe 'metrics recording' do
    let(:token_value) { 'test-token' }

    before do
      allow(client).to receive_messages(valid_format?: true,
        verify_partner_token: client.send(:token_response, :active))
    end

    it 'records API duration on successful verification' do
      expect(Gitlab::Metrics::SecretDetection::PartnerTokens)
        .to receive(:observe_api_duration)
        .with(instance_of(Float), hash_including(partner: anything))

      client.verify_token(token_value)
    end

    it 'records successful API requests' do
      expect(Gitlab::Metrics::SecretDetection::PartnerTokens)
        .to receive(:increment_api_requests)
        .with(partner: anything, status: 'success')

      client.verify_token(token_value)
    end

    context 'when network error occurs' do
      before do
        allow(client).to receive(:verify_partner_token)
          .and_raise(described_class::NetworkError, 'Connection failed')
      end

      it 'records network error metric' do
        expect(Gitlab::Metrics::SecretDetection::PartnerTokens)
          .to receive(:increment_network_errors)
          .with(partner: anything, error_class: 'NetworkError')

        expect { client.verify_token(token_value) }
          .to raise_error(described_class::NetworkError)
      end

      it 'records failed API request' do
        expect(Gitlab::Metrics::SecretDetection::PartnerTokens)
          .to receive(:increment_api_requests)
          .with(partner: anything, status: 'failure', error_type: 'network_error')

        expect { client.verify_token(token_value) }
          .to raise_error(described_class::NetworkError)
      end
    end

    context 'when rate limit is hit' do
      before do
        allow(client).to receive(:verify_partner_token)
          .and_raise(described_class::RateLimitError, 'Rate limited')
      end

      it 'records rate limit failure' do
        expect(Gitlab::Metrics::SecretDetection::PartnerTokens)
          .to receive(:increment_api_requests)
          .with(partner: anything, status: 'failure', error_type: 'rate_limit')

        expect { client.verify_token(token_value) }
          .to raise_error(described_class::RateLimitError)
      end
    end

    context 'when response error occurs' do
      before do
        allow(client).to receive(:verify_partner_token)
          .and_raise(described_class::ResponseError, 'Invalid response')
      end

      it 'records response error' do
        expect(Gitlab::Metrics::SecretDetection::PartnerTokens)
          .to receive(:increment_api_requests)
          .with(partner: anything, status: 'failure', error_type: 'response_error')

        client.verify_token(token_value)
      end

      it 'returns unknown token status' do
        result = client.verify_token(token_value)
        expect(result.status).to eq(:unknown)
      end
    end
  end
end

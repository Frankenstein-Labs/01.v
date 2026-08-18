# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Destinations::HttpStreamDestination, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type' }
  let(:destination) { create(:audit_events_instance_external_streaming_destination, :http) }
  let(:http_destination) { described_class.new(event_type, audit_event, destination) }

  describe '#stream' do
    subject(:stream) { http_destination.stream }

    let(:request_body) { http_destination.send(:request_body) }
    let(:request_headers) { http_destination.send(:build_headers) }

    context 'when URL is valid' do
      before do
        allow(Gitlab::HTTP).to receive(:post)
      end

      it 'makes HTTP post request with correct parameters' do
        expect(Gitlab::HTTP).to receive(:post).with(
          destination.config["url"],
          body: request_body,
          headers: request_headers,
          open_timeout: 8.seconds,
          read_timeout: 8.seconds,
          write_timeout: 8.seconds
        )
        stream
      end
    end

    context 'when URL is invalid' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_raise(URI::InvalidURIError.new('Invalid URL'))
      end

      it 'raises the exception to be handled by the caller' do
        expect { stream }.to raise_error(URI::InvalidURIError, 'Invalid URL')
      end
    end

    context 'when an HTTP error occurs' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_raise(Gitlab::HTTP_V2::BlockedUrlError.new('URL is blocked'))
      end

      it 'raises the exception to be handled by the caller' do
        expect { stream }.to raise_error(Gitlab::HTTP_V2::BlockedUrlError, 'URL is blocked')
      end
    end
  end

  describe '#stream_batch' do
    let(:batch_destination) { described_class.for_batch(destination) }
    let(:event_bodies) do
      [
        { 'id' => '1', 'event_type' => 'type_a', 'foo' => 'bar' },
        { 'id' => '2', 'event_type' => 'type_b', 'baz' => 'qux' }
      ]
    end

    it 'posts a JSON array body and omits the per-request event-type header', :aggregate_failures do
      expect(Gitlab::HTTP).to receive(:post).with(
        destination.config["url"],
        body: Gitlab::Json::LimitedEncoder.encode(event_bodies, limit: described_class::REQUEST_BODY_SIZE_LIMIT),
        headers: destination.headers_hash,
        open_timeout: 8.seconds,
        read_timeout: 8.seconds,
        write_timeout: 8.seconds
      ) do |_url, headers:, **|
        expect(headers).not_to have_key(described_class::EVENT_TYPE_HEADER_KEY)
        expect(headers).to have_key(described_class::STREAMING_TOKEN_HEADER_KEY)
      end

      batch_destination.stream_batch(event_bodies)
    end
  end

  describe '#build_headers' do
    subject(:headers) { http_destination.send(:build_headers) }

    context 'when config includes headers' do
      let(:custom_value) { 'Custom-Value' }
      let(:config_headers) { { 'X-Custom-Header' => custom_value } }

      before do
        destination.config["headers"] = {
          'X-Custom-Header' => {
            'value' => custom_value,
            'active' => true
          }
        }
      end

      it 'includes configured headers, streaming token and event type', :aggregate_failures do
        expect(headers).to include(config_headers)
        expect(headers[described_class::EVENT_TYPE_HEADER_KEY]).to eq(event_type)
        expect(headers[described_class::STREAMING_TOKEN_HEADER_KEY]).to eq(destination.secret_token)
      end

      context 'when header is explicitly inactive' do
        before do
          destination.config["headers"]['X-Custom-Header']['active'] = false
        end

        it 'excludes inactive headers but includes required headers' do
          expect(headers).not_to include(config_headers)
          expect(headers[described_class::EVENT_TYPE_HEADER_KEY]).to eq(event_type)
          expect(headers[described_class::STREAMING_TOKEN_HEADER_KEY]).to eq(destination.secret_token)
        end
      end

      context 'when multiple valid headers are configured' do
        before do
          destination.config["headers"] = {
            'X-Custom-Header-1' => {
              'value' => 'Value-1',
              'active' => true
            },
            'X-Custom-Header-2' => {
              'value' => 'Value-2',
              'active' => true
            }
          }
        end

        it 'includes all active headers' do
          expect(headers).to include(
            'X-Custom-Header-1' => 'Value-1',
            'X-Custom-Header-2' => 'Value-2'
          )
        end
      end
    end

    context 'when config has no headers' do
      before do
        destination.config['headers'] = nil
      end

      it 'includes event type header and streaming token' do
        expect(headers).to include(
          described_class::EVENT_TYPE_HEADER_KEY => event_type,
          described_class::STREAMING_TOKEN_HEADER_KEY => destination.secret_token
        )
      end
    end

    context 'when event type is empty' do
      let(:event_type) { '' }

      it 'does not include event type header but includes streaming token' do
        expect(headers).not_to include(described_class::EVENT_TYPE_HEADER_KEY)
        expect(headers).to include(described_class::STREAMING_TOKEN_HEADER_KEY => destination.secret_token)
      end
    end
  end
end

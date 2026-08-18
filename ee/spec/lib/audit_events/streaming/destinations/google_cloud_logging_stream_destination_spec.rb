# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type' }
  let(:destination) { create(:audit_events_instance_external_streaming_destination, :gcp) }
  let(:google_cloud_destination) { described_class.new(event_type, audit_event, destination) }

  describe '#stream' do
    let(:gcp_logger) { instance_double(AuditEvents::GoogleCloud::LoggingService::Logger) }

    before do
      allow(AuditEvents::GoogleCloud::LoggingService::Logger).to receive(:new).and_return(gcp_logger)
    end

    it 'logs the audit event to Google Cloud Logging' do
      expect(gcp_logger).to receive(:log).with(
        destination.config["clientEmail"],
        destination.secret_token,
        google_cloud_destination.send(:json_payload)
      )

      google_cloud_destination.stream
    end

    context 'when an error occurs' do
      before do
        allow(gcp_logger).to receive(:log).and_raise(StandardError.new('GCP error'))
      end

      it 'raises the exception to be handled by the caller' do
        expect { google_cloud_destination.stream }.to raise_error(StandardError, 'GCP error')
      end
    end
  end

  describe '#json_payload' do
    subject(:json_payload) { google_cloud_destination.send(:json_payload) }

    it 'returns a JSON string with the correct structure' do
      payload = Gitlab::Json.parse(json_payload)

      expect(payload).to be_a(Hash)
      expect(payload['entries']).to be_an(Array)
      expect(payload['entries'].first).to include(
        'logName',
        'resource',
        'severity',
        'jsonPayload'
      )
    end
  end

  describe '#log_entry' do
    subject(:log_entry) { google_cloud_destination.send(:log_entry) }

    it 'returns a hash with the correct structure' do
      expect(log_entry).to include(
        'logName' => a_kind_of(String),
        'resource' => { 'type' => 'global' },
        'severity' => 'INFO',
        'jsonPayload' => a_kind_of(Hash)
      )
    end

    context 'when request_body contains invalid JSON' do
      before do
        allow(google_cloud_destination).to receive(:request_body).and_return('invalid json {')
      end

      it 'raises an error for truly invalid JSON' do
        expect { log_entry }.to raise_error(JSON::ParserError)
      end
    end

    context 'when request_body exceeds safe_parse limits' do
      before do
        # Mock safe_parse to raise limit error, but parse succeeds
        allow(::Gitlab::Json).to receive(:safe_parse).and_raise(JSON::ParserError.new('limit exceeded'))
        allow(::Gitlab::Json).to receive(:parse).and_return({ 'large_event' => 'data' })
      end

      it 'falls back to parse to preserve audit data' do
        expect(log_entry['jsonPayload']).to eq({ 'large_event' => 'data' })
      end
    end

    context 'when request_body is valid JSON' do
      it 'parses the JSON correctly' do
        expect(log_entry['jsonPayload']).to be_a(Hash)
        expect(log_entry['jsonPayload']).to include('id', 'author_name')
      end
    end
  end

  describe '#full_log_path' do
    subject(:full_log_path) { google_cloud_destination.send(:full_log_path) }

    it 'returns the correct log path' do
      path = "projects/#{destination.config['googleProjectIdName']}/logs/#{destination.config['logIdName']}"
      expect(full_log_path).to eq(path)
    end
  end

  describe '#stream_batch' do
    let(:batch_destination) { described_class.for_batch(destination) }
    let(:gcp_logger) { instance_double(AuditEvents::GoogleCloud::LoggingService::Logger) }
    let(:event_bodies) do
      [
        { 'id' => '10', 'event_type' => 'type_a' },
        { 'id' => '11', 'event_type' => 'type_b' }
      ]
    end

    before do
      allow(AuditEvents::GoogleCloud::LoggingService::Logger).to receive(:new).and_return(gcp_logger)
    end

    it 'logs all events as a multi-entry payload', :aggregate_failures do
      expect(gcp_logger).to receive(:log) do |_email, _token, payload|
        entries = ::Gitlab::Json.parse(payload)['entries']
        expect(entries.size).to eq(2)
        expect(entries.map { |e| e['jsonPayload']['id'] }).to contain_exactly('10', '11')
      end

      batch_destination.stream_batch(event_bodies)
    end
  end
end

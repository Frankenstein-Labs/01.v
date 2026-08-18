# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Destinations::BaseStreamDestination, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type' }
  let(:destination) { create(:audit_events_instance_external_streaming_destination, :http) }
  let(:base_destination) { described_class.new(event_type, audit_event, destination) }

  describe '#stream' do
    it 'raises NotImplementedError' do
      expect { base_destination.stream }.to raise_error(NotImplementedError)
    end
  end

  describe '#stream_batch' do
    it 'raises NotImplementedError' do
      expect { base_destination.stream_batch([]) }.to raise_error(NotImplementedError)
    end
  end

  describe '#request_body' do
    subject(:request_body) { base_destination.send(:request_body) }

    it 'returns json with required fields', :aggregate_failures do
      body = Gitlab::Json.parse(request_body)

      expect(body['event_type']).to eq(event_type)
      expect(body['id']).to eq(audit_event.id)
    end

    context 'when built in batch mode (no audit event)' do
      let(:base_destination) { described_class.for_batch(destination) }

      it 'raises ArgumentError' do
        expect { request_body }.to raise_error(ArgumentError, /requires a per-event instance/)
      end
    end

    context 'when the audit event has a blank database id' do
      before do
        allow(audit_event).to receive(:id).and_return(nil)
      end

      let(:uuid_format) { /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/ }

      context 'and it does not respond to stream_id' do
        before do
          allow(audit_event).to receive(:respond_to?).and_call_original
          allow(audit_event).to receive(:respond_to?).with(:stream_id).and_return(false)
        end

        it 'falls back to a generated UUID' do
          expect(Gitlab::Json.parse(request_body)['id']).to match(uuid_format)
        end
      end

      context 'and its stream_id is blank' do
        before do
          allow(audit_event).to receive(:stream_id).and_return(nil)
        end

        it 'falls back to a generated UUID' do
          expect(Gitlab::Json.parse(request_body)['id']).to match(uuid_format)
        end
      end

      context 'and its stream_id is present' do
        before do
          allow(audit_event).to receive(:stream_id).and_return('upstream-stream-id')
        end

        it 'uses the upstream stream_id' do
          expect(Gitlab::Json.parse(request_body)['id']).to eq('upstream-stream-id')
        end
      end
    end
  end
end

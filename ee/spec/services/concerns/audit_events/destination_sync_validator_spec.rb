# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::DestinationSyncValidator, feature_category: :audit_events do
  let(:test_class) { Class.new { include AuditEvents::DestinationSyncValidator } }
  let(:helper) { test_class.new }

  describe '#should_sync_http?' do
    context 'with legacy destination (external audit event destination)' do
      let(:legacy_destination) { instance_double(AuditEvents::ExternalAuditEventDestination) }
      let(:stream_destination) { instance_double(AuditEvents::Group::ExternalStreamingDestination) }

      before do
        allow(legacy_destination).to receive_messages(
          instance_level?: false,
          stream_destination_id: 123,
          stream_destination: stream_destination
        )
        allow(stream_destination).to receive(:http?).and_return(true)
      end

      it 'returns true when all conditions are met' do
        expect(helper.should_sync_http?(legacy_destination)).to be_truthy
      end

      it 'returns false for non-HTTP streaming destinations' do
        allow(stream_destination).to receive(:http?).and_return(false)
        expect(helper.should_sync_http?(legacy_destination)).to be_falsey
      end

      it 'returns false when stream_destination_id is nil' do
        allow(legacy_destination).to receive(:stream_destination_id).and_return(nil)
        expect(helper.should_sync_http?(legacy_destination)).to be_falsey
      end
    end

    context 'with streaming destination' do
      let(:streaming_destination) { instance_double(AuditEvents::Group::ExternalStreamingDestination) }

      before do
        allow(streaming_destination).to receive_messages(
          instance_level?: false,
          legacy_destination_ref: 123,
          http?: true
        )
      end

      it 'returns true when all conditions are met' do
        expect(helper.should_sync_http?(streaming_destination)).to be_truthy
      end

      it 'returns false for non-HTTP destinations' do
        allow(streaming_destination).to receive(:http?).and_return(false)
        expect(helper.should_sync_http?(streaming_destination)).to be_falsey
      end

      it 'returns false when legacy_destination_ref is nil' do
        allow(streaming_destination).to receive(:legacy_destination_ref).and_return(nil)
        expect(helper.should_sync_http?(streaming_destination)).to be_falsey
      end
    end
  end
end

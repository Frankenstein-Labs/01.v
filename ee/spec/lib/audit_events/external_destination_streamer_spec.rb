# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::ExternalDestinationStreamer, feature_category: :audit_events do
  let_it_be(:group) { create(:group) }
  let_it_be(:event) { create(:audit_event, :group_event, entity_id: group.id) }

  let(:streamer) { described_class.new('audit_operation', event) }
  let(:request_body) { { id: event.id, event_type: 'audit_operation' }.to_json }

  before do
    stub_licensed_features(external_audit_events: true)
    freeze_time

    allow_next_instance_of(::AuditEvents::GoogleCloud::Authentication) do |instance|
      allow(instance).to receive(:generate_access_token).and_return("sample-token")
    end

    stub_request(:post, /.*/).to_return(status: 200, body: "", headers: {})
    stub_request(:put, /.*/).to_return(status: 200, body: "", headers: {})

    allow_any_instance_of(Aws::S3::Client) do |instance|
      allow(instance).to receive(:put_object).and_return(nil)
    end

    allow_next_instance_of(AuditEvents::GoogleCloud::LoggingService::Logger) do |instance|
      allow(instance).to receive(:log).and_return(nil)
    end
  end

  describe '#stream_to_destinations' do
    subject(:stream_to_destinations) { streamer.stream_to_destinations }

    context 'when no external streaming destinations are present' do
      it_behaves_like 'external destination streamer'

      it 'only uses the streamers with feature flag enabled' do
        allow(streamer.send(:streamers)).to receive(:any?).and_return(true)
        allow_next_instance_of(AuditEvents::Streaming::Group::Streamer) do |instance|
          allow(instance).to receive(:execute)
        end
        allow_next_instance_of(AuditEvents::Streaming::Instance::Streamer) do |instance|
          allow(instance).to receive(:execute)
        end

        expect(streamer).to receive(:streamers).at_least(:once).and_call_original
        stream_to_destinations
      end
    end

    context 'when external streaming destinations are present' do
      before do
        create(:audit_events_group_external_streaming_destination, :http,
          group: group)
        create(:audit_events_instance_external_streaming_destination, :gcp)
        create(:audit_events_instance_external_streaming_destination, :aws)
      end

      it 'streams to all external streaming destinations' do
        expect_next_instance_of(AuditEvents::Streaming::Group::Streamer) do |instance|
          expect(instance).to receive(:execute)
        end
        expect_next_instance_of(AuditEvents::Streaming::Instance::Streamer) do |instance|
          expect(instance).to receive(:execute)
        end

        stream_to_destinations
      end

      it 'makes correct number of external calls' do
        destination_classes = AuditEvents::Streaming::BaseStreamer::STREAMER_DESTINATIONS.values
        destination_classes.each do |dest_class|
          expect_next_instance_of(dest_class) do |instance|
            expect(instance).to receive(:stream).once
          end
        end

        expect_next_instance_of(AuditEvents::Streaming::Group::Streamer) do |streamer|
          expect(streamer).to receive(:execute).once.and_call_original
          allow(streamer).to receive(:streamable?).and_return(true)
        end

        expect_next_instance_of(AuditEvents::Streaming::Instance::Streamer) do |streamer|
          expect(streamer).to receive(:execute).once.and_call_original
          allow(streamer).to receive(:streamable?).and_return(true)
        end

        stream_to_destinations
      end

      it 'only uses the streamers with feature flag enabled' do
        allow(streamer.send(:streamers)).to receive(:any?).and_return(true)

        expect(streamer).to receive(:streamers).at_least(:once).and_call_original

        stream_to_destinations
      end
    end
  end

  describe '#streamable?' do
    subject(:streamable) { streamer.streamable? }

    context 'when none of the external streaming destinations are present' do
      it { is_expected.to be_falsey }

      it 'only checks streamers with feature flag enabled' do
        expect(streamer).to receive(:streamers).at_least(:once).and_call_original

        streamable
      end
    end

    context 'when external streaming destinations are present' do
      before do
        create(:audit_events_group_external_streaming_destination, :http,
          group: group)
        create(:audit_events_instance_external_streaming_destination, :gcp)
      end

      it { is_expected.to be_truthy }

      it 'only checks streamers with feature flag enabled' do
        allow_next_instance_of(AuditEvents::Streaming::Group::Streamer) do |instance|
          allow(instance).to receive(:streamable?).and_return(true)
        end

        expect(streamer).to receive(:streamers).at_least(:once).and_call_original

        streamable
      end
    end

    context 'when destinations exist but all have non-matching event type filters' do
      let(:streamer) { described_class.new('event_type_filters_created', event) }

      before do
        group_destination = create(:audit_events_group_external_streaming_destination, :http, group: group)
        create(:audit_events_group_event_type_filters,
          external_streaming_destination: group_destination,
          audit_event_type: 'event_type_filters_deleted')

        instance_destination = create(:audit_events_instance_external_streaming_destination, :gcp)
        create(:audit_events_instance_event_type_filters,
          external_streaming_destination: instance_destination,
          audit_event_type: 'event_type_filters_deleted')
      end

      it { is_expected.to be_falsey }
    end

    context 'when at least one destination has a matching event type filter' do
      let(:streamer) { described_class.new('event_type_filters_created', event) }

      before do
        group_destination = create(:audit_events_group_external_streaming_destination, :http, group: group)
        create(:audit_events_group_event_type_filters,
          external_streaming_destination: group_destination,
          audit_event_type: 'event_type_filters_created')
      end

      it { is_expected.to be_truthy }
    end

    context 'when only one destination type is present' do
      using RSpec::Parameterized::TableSyntax

      where(:factory, :trait, :is_group_destination) do
        :audit_events_group_external_streaming_destination | :aws | true
        :audit_events_group_external_streaming_destination | :gcp | true
        :audit_events_group_external_streaming_destination | :http | true
        :audit_events_instance_external_streaming_destination | :aws | false
        :audit_events_instance_external_streaming_destination | :gcp | false
        :audit_events_instance_external_streaming_destination | :http | false
      end

      with_them do
        before do
          if is_group_destination
            create(factory, trait, group: event.entity)
          else
            create(factory, trait)
          end

          allow(event).to receive(:root_group_entity).and_return(group)
        end

        it { is_expected.to be_truthy }

        it 'correctly sets up streamable state' do
          if is_group_destination
            expect(group.external_audit_event_streaming_destinations).to be_present
            expect(group.external_audit_event_streaming_destinations.first).to be_active
          end

          expect(streamer.streamable?).to be true
        end
      end
    end
  end
end

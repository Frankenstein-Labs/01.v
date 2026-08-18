# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AiAuditEventStreamingWorker, feature_category: :audit_events do
  let_it_be(:project) { create(:project) }
  let_it_be(:ai_audit_event) { create(:audit_events_ai_audit_event, target_project: project) }

  let(:worker) { described_class.new }
  let(:payload) { ai_audit_event.streaming_json }

  describe 'worker configuration' do
    it 'uses default (low) urgency' do
      expect(described_class.get_urgency).to eq(:low)
    end

    it 'does not defer on database health signal' do
      expect(described_class.database_health_check_attrs).to be_nil
    end
  end

  describe '#perform' do
    subject(:perform) { worker.perform(payload) }

    it 'delegates to ExternalDestinationStreamer with the rebuilt event' do
      expect_next_instance_of(::AuditEvents::ExternalDestinationStreamer,
        ai_audit_event.event_name, kind_of(::AuditEvents::AiAuditEvent)) do |streamer|
        expect(streamer).to receive(:stream_to_destinations)
      end

      perform
    end

    it 'rebuilds the AI audit event with the streamed columns' do
      received_event = nil
      allow(::AuditEvents::ExternalDestinationStreamer).to receive(:new) do |_event_name, event|
        received_event = event
        instance_double(::AuditEvents::ExternalDestinationStreamer, stream_to_destinations: nil, streamable?: false)
      end

      perform

      expect(received_event).to be_a(::AuditEvents::AiAuditEvent)
      expect(received_event.cloud_event_id).to eq(ai_audit_event.cloud_event_id)
      expect(received_event.event_name).to eq(ai_audit_event.event_name)
      expect(received_event.project_id).to eq(ai_audit_event.project_id)
    end

    it 'masks the rebuilt record `id` to cloud_event_id for stable streaming' do
      received_event = nil
      allow(::AuditEvents::ExternalDestinationStreamer).to receive(:new) do |_event_name, event|
        received_event = event
        instance_double(::AuditEvents::ExternalDestinationStreamer, stream_to_destinations: nil, streamable?: false)
      end

      perform

      expect(received_event.id).to eq(ai_audit_event.cloud_event_id)
      expect(received_event.id).not_to be_blank
    end

    context 'when SilentMode is enabled' do
      before do
        allow(::Gitlab::SilentMode).to receive(:enabled?).and_return(true)
      end

      it 'does not call the external destination streamer' do
        expect(::AuditEvents::ExternalDestinationStreamer).not_to receive(:new)

        perform
      end
    end

    context 'when the payload is invalid JSON' do
      let(:payload) { 'not-json' }

      it 'tracks the exception and does not raise' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(kind_of(JSON::ParserError))
        expect(::AuditEvents::ExternalDestinationStreamer).not_to receive(:new)

        expect { perform }.not_to raise_error
      end
    end

    context 'when the payload contains a root_group_entity_id' do
      let_it_be(:root_group) { create(:group) }
      let(:payload) do
        ::Gitlab::Json.safe_parse(ai_audit_event.streaming_json)
          .merge('root_group_entity_id' => root_group.id)
          .to_json
      end

      it 'preserves root_group_entity_id on the rebuilt event' do
        received_event = nil
        allow(::AuditEvents::ExternalDestinationStreamer).to receive(:new) do |_event_name, event|
          received_event = event
          instance_double(::AuditEvents::ExternalDestinationStreamer, stream_to_destinations: nil, streamable?: false)
        end

        perform

        expect(received_event.root_group_entity_id).to eq(root_group.id)
      end
    end

    context 'with Prometheus metrics' do
      let(:streamer_double) do
        instance_double(::AuditEvents::ExternalDestinationStreamer, stream_to_destinations: nil, streamable?: true)
      end

      before do
        allow(::AuditEvents::ExternalDestinationStreamer).to receive(:new).and_return(streamer_double)
      end

      it 'increments STREAMING_COUNTER with status: :success and streamable: true on success' do
        allow(streamer_double).to receive(:streamable?).and_return(true)

        expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
          streamable: true,
          status: :success
        )

        perform
      end

      it 'increments STREAMING_COUNTER with streamable: false when streamer is not streamable' do
        allow(streamer_double).to receive(:streamable?).and_return(false)

        expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
          streamable: false,
          status: :success
        )

        perform
      end

      context 'when perform raises a StandardError' do
        before do
          allow(streamer_double).to receive(:stream_to_destinations).and_raise(StandardError, 'something broke')
        end

        it 'increments STREAMING_COUNTER with status: :error and the real streamable value' do
          expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
            streamable: true,
            status: :error
          )

          expect { perform }.to raise_error(StandardError, 'something broke')
        end

        it 're-raises the error after incrementing the counter' do
          allow(described_class::STREAMING_COUNTER).to receive(:increment)

          expect { perform }.to raise_error(StandardError, 'something broke')
        end
      end

      context 'when build_audit_event returns nil (invalid JSON payload)' do
        let(:payload) { 'not-valid-json' }

        it 'does not increment STREAMING_COUNTER' do
          allow(::Gitlab::ErrorTracking).to receive(:track_exception)

          expect(described_class::STREAMING_COUNTER).not_to receive(:increment)

          perform
        end
      end
    end

    context 'with internal event tracking', :clean_gitlab_redis_shared_state do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: root_group) }
      let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
      let_it_be(:ai_audit_event) { create(:audit_events_ai_audit_event, target_project: project_in_subgroup) }

      let(:streamer_double) do
        instance_double(::AuditEvents::ExternalDestinationStreamer, stream_to_destinations: nil, streamable?: true)
      end

      before do
        allow(::AuditEvents::ExternalDestinationStreamer).to receive(:new).and_return(streamer_double)
      end

      it 'fires the streaming event with the project and its top-level group and counts the group' do
        expect { perform }
          .to trigger_internal_events('stream_ai_audit_event_to_external_destination')
          .with(project: project_in_subgroup, namespace: root_group)
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_namespace_id_from_stream_ai_audit_event_to_external_destination_weekly',
            'redis_hll_counters.count_distinct_namespace_id_from_stream_ai_audit_event_to_external_destination_monthly'
          ).by(1)
      end

      context 'when the project belongs to a personal namespace' do
        let_it_be(:ai_audit_event) { create(:audit_events_ai_audit_event, target_project: project) }

        it 'does not fire the streaming event without a top-level group' do
          expect { perform }.not_to trigger_internal_events('stream_ai_audit_event_to_external_destination')
        end
      end

      context 'when no destination is streamable' do
        before do
          allow(streamer_double).to receive(:streamable?).and_return(false)
        end

        it 'does not fire the streaming event' do
          expect { perform }.not_to trigger_internal_events('stream_ai_audit_event_to_external_destination')
        end
      end

      context 'when streaming raises an error' do
        before do
          allow(streamer_double).to receive(:stream_to_destinations).and_raise(StandardError, 'boom')
        end

        it 'does not fire the streaming event' do
          expect do
            expect { perform }.to raise_error(StandardError, 'boom')
          end.not_to trigger_internal_events('stream_ai_audit_event_to_external_destination')
        end
      end

      context 'when the audit event belongs to a group' do
        let_it_be(:ai_audit_event) do
          create(:audit_events_ai_audit_event, project_id: nil, namespace_id: subgroup.id)
        end

        it 'fires the streaming event with the top-level group as namespace and no project' do
          expect { perform }
            .to trigger_internal_events('stream_ai_audit_event_to_external_destination')
            .with(project: nil, namespace: root_group)
        end
      end
    end

    context 'with circuit breaker integration' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project_in_group) { create(:project, group: group) }
      let_it_be(:ai_audit_event) do
        create(:audit_events_ai_audit_event, target_project: project_in_group)
      end

      let_it_be(:destination) do
        create(:audit_events_group_external_streaming_destination, group: group)
      end

      before do
        stub_licensed_features(external_audit_events: true)
      end

      context 'when the destination circuit breaker is open' do
        before do
          allow(AuditEvents::Streaming::CircuitBreaker)
            .to receive(:reject_open).with([destination]).and_return([])
        end

        it 'does not instantiate the HTTP stream destination' do
          expect(AuditEvents::Streaming::Destinations::HttpStreamDestination).not_to receive(:new)

          perform
        end

        it 'fires the streaming event even though no destination receives the event (attempt semantics)' do
          expect { perform }
            .to trigger_internal_events('stream_ai_audit_event_to_external_destination')
            .with(project: project_in_group, namespace: group)
        end
      end

      context 'when streaming fails with a connection error' do
        let(:error) { Errno::ECONNREFUSED.new('test connection refused') }

        before do
          allow(AuditEvents::Streaming::Destinations::HttpStreamDestination)
            .to receive(:new).and_wrap_original do |original, *args|
              instance = original.call(*args)
              allow(instance).to receive(:stream).and_raise(error)
              instance
            end
          allow(Gitlab::ErrorTracking).to receive(:log_exception)
        end

        it 'records a circuit breaker failure for the destination' do
          expect(AuditEvents::Streaming::CircuitBreaker).to receive(:record_failure).with(destination)

          perform
        end

        it 'fires the streaming event even though delivery failed (attempt semantics)' do
          expect { perform }
            .to trigger_internal_events('stream_ai_audit_event_to_external_destination')
            .with(project: project_in_group, namespace: group)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::EnqueueService, feature_category: :audit_events do
  let_it_be(:group) { create(:group) }
  let_it_be(:audit_event) { create(:audit_events_group_audit_event, group_id: group.id) }

  let(:event_name) { 'audit_operation' }

  describe '#execute' do
    context 'when use_json is true' do
      subject(:service) do
        described_class.new(audit_event, event_name: event_name, use_json: true, model_class: audit_event.class.name)
      end

      it 'enqueues the worker with the serialized event payload' do
        expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async) do |name, id, json|
          expect(name).to eq(event_name)
          expect(id).to be_nil
          expect(json).to eq(::Gitlab::Json.generate(audit_event, methods: [:root_group_entity_id, :stream_id]))
        end

        service.execute
      end

      it 'includes root_group_entity_id in the payload' do
        expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async) do |_name, _id, json|
          expect(::Gitlab::Json.safe_parse(json)).to include('root_group_entity_id' => audit_event.root_group_entity_id)
        end

        service.execute
      end

      context 'when the event is not persisted (stream-only)' do
        let(:audit_event) { build(:audit_events_group_audit_event, id: nil, group_id: group.id) }

        it 'assigns a stable stream_id once and carries it in the payload' do
          expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async) do |_name, _id, json|
            expect(::Gitlab::Json.safe_parse(json)).to include('stream_id' => audit_event.stream_id)
          end

          service.execute

          expect(audit_event.stream_id).to be_present
        end

        it 'does not overwrite an existing stream_id' do
          audit_event.stream_id = 'existing-uuid'

          service.execute

          expect(audit_event.stream_id).to eq('existing-uuid')
        end
      end
    end

    context 'when use_json is false' do
      context 'with a model_class' do
        subject(:service) do
          described_class.new(
            audit_event,
            event_name: event_name,
            use_json: false,
            model_class: audit_event.class.name
          )
        end

        it 'enqueues the worker with the event id and model class' do
          expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
            .with(event_name, audit_event.id, nil, 'AuditEvents::GroupAuditEvent')

          service.execute
        end
      end

      context 'without a model_class (legacy ::AuditEvent path)' do
        subject(:service) { described_class.new(audit_event, event_name: event_name, use_json: false) }

        it 'enqueues the worker with only the event id' do
          expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
            .with(event_name, audit_event.id, nil)

          service.execute
        end
      end
    end
  end

  describe 'NATS routing' do
    subject(:service) do
      described_class.new(audit_event, event_name: event_name, use_json: true, model_class: audit_event.class.name)
    end

    let(:nats_client) { instance_double(Gitlab::Nats::Client) }

    context 'when NATS is not configured' do
      before do
        allow(Gitlab::Nats).to receive(:configured?).and_return(false)
      end

      it 'enqueues via Sidekiq' do
        expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)

        service.execute
      end
    end

    context 'when NATS is configured' do
      before do
        allow(Gitlab::Nats).to receive_messages(configured?: true, client: nats_client)
      end

      context 'when the application setting is disabled' do
        before do
          stub_application_setting(use_nats_for_audit_streaming: false)
        end

        it 'enqueues via Sidekiq and does not publish to NATS' do
          expect(nats_client).not_to receive(:publish)
          expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)

          service.execute
        end
      end

      context 'when the application setting is enabled' do
        before do
          stub_application_setting(use_nats_for_audit_streaming: true)
        end

        context 'when the feature flag is disabled for the root group' do
          before do
            stub_feature_flags(audit_event_streaming_via_nats: false)
          end

          it 'enqueues via Sidekiq and does not publish to NATS' do
            expect(nats_client).not_to receive(:publish)
            expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)

            service.execute
          end
        end

        context 'when the feature flag is enabled for the root group' do
          before do
            stub_feature_flags(audit_event_streaming_via_nats: group)
          end

          let(:expected_subject) do
            ::AuditEvents::Streaming::NatsPartitioning.subject_for(group.id)
          end

          it 'publishes to the partitioned NATS subject and skips Sidekiq' do
            expect(nats_client).to receive(:publish).with(
              expected_subject,
              kind_of(String),
              message_id: audit_event.id.to_s,
              timeout: described_class::PUBLISH_TIMEOUT
            )
            expect(::AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)

            service.execute
          end

          it 'publishes the versioned payload envelope' do
            expect(nats_client).to receive(:publish) do |_subject, payload, **|
              parsed = ::Gitlab::Json.safe_parse(payload)

              expect(parsed).to include(
                'schema_version' => described_class::PAYLOAD_SCHEMA_VERSION,
                'id' => audit_event.id.to_s,
                'event_name' => event_name,
                'group_id' => group.id,
                'persisted' => true,
                'model_class' => audit_event.class.name,
                'namespace_ancestor_ids' => kind_of(Array),
                'project_namespace' => false
              )
              expect(parsed).to have_key('published_at')
              expect(parsed['event']).to include('root_group_entity_id' => group.id)
            end

            service.execute
          end

          it 'records a publish with no fallback' do
            allow(nats_client).to receive(:publish)

            expect(::Gitlab::Metrics::AuditEventStreamingSlis).to receive(:record_publish).with(fallback: false)

            service.execute
          end

          context 'when the event is project-namespace-scoped' do
            let_it_be(:project) { create(:project, group: group) }
            let_it_be(:audit_event) do
              create(:audit_events_project_audit_event, target_project: project)
            end

            it 'marks the payload as project_namespace with the ancestor ids' do
              expect(nats_client).to receive(:publish) do |_subject, payload, **|
                parsed = ::Gitlab::Json.safe_parse(payload)

                expect(parsed).to include('project_namespace' => true)
                expect(parsed['namespace_ancestor_ids'])
                  .to include(project.project_namespace.id, group.id)
              end

              service.execute
            end
          end

          context 'when the publish fails' do
            before do
              allow(nats_client).to receive(:publish).and_raise(StandardError, 'nats down')
            end

            it 'logs the exception and falls back to Sidekiq' do
              expect(::Gitlab::ErrorTracking).to receive(:log_exception)
                .with(kind_of(StandardError), hash_including(event_name: event_name))
              expect(::AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)

              service.execute
            end

            it 'records a fallback publish metric' do
              expect(::Gitlab::Metrics::AuditEventStreamingSlis).to receive(:record_publish).with(fallback: true)

              service.execute
            end
          end

          context 'when the event has no root group (instance-scoped)' do
            let(:audit_event) { build(:audit_events_instance_audit_event, id: nil) }

            subject(:service) do
              described_class.new(audit_event, event_name: event_name, use_json: true,
                model_class: audit_event.class.name)
            end

            before do
              stub_feature_flags(audit_event_streaming_via_nats: true)
            end

            it 'publishes to the partition for instance-scoped events' do
              expect(nats_client).to receive(:publish).with(
                ::AuditEvents::Streaming::NatsPartitioning.subject_for(nil),
                kind_of(String),
                message_id: kind_of(String),
                timeout: described_class::PUBLISH_TIMEOUT
              ) do |_subject, _payload, message_id:, **|
                # The stable stream_id is minted during execute and used as
                # the NATS message ID.
                expect(message_id).to eq(audit_event.stream_id)
              end

              service.execute

              expect(audit_event.stream_id).to be_present
            end

            it 'sends empty namespace_ancestor_ids when there is no streamable namespace' do
              expect(nats_client).to receive(:publish) do |_subject, payload, **|
                parsed = ::Gitlab::Json.safe_parse(payload)

                expect(parsed).to include(
                  'namespace_ancestor_ids' => [],
                  'project_namespace' => false
                )
              end

              service.execute
            end
          end
        end
      end
    end
  end

  describe '#stable_id' do
    context 'when the event is persisted' do
      subject(:service) { described_class.new(audit_event, event_name: event_name) }

      it 'returns the database id as a string and does not assign a stream_id' do
        expect(service.stable_id).to eq(audit_event.id.to_s)
        expect(audit_event.stream_id).to be_nil
      end
    end

    context 'when the event is not persisted' do
      let(:audit_event) { build(:audit_events_group_audit_event, id: nil, group_id: group.id) }

      subject(:service) { described_class.new(audit_event, event_name: event_name) }

      it 'mints a UUID once and returns it consistently' do
        first = service.stable_id

        expect(first).to be_present
        expect(service.stable_id).to eq(first)
        expect(audit_event.stream_id).to eq(first)
      end
    end

    describe 'database id uniqueness invariant' do
      # Database IDs are only safe to use as deduplication keys (e.g. the
      # NATS Nats-Msg-Id header) because every streaming-path audit event
      # table draws its id from the single `audit_events_id_seq` sequence
      # (see 20260603075738_use_audit_events_id_seq_for_scoped_audit_events.rb).
      #
      # If this spec fails, IDs from different audit event tables can collide
      # within the JetStream deduplication window and audit events would be
      # silently dropped as duplicates. Do not change the expectation; instead
      # revisit the stable ID scheme in EnqueueService (e.g. namespace the ID
      # per table) before changing the sequence layout.
      let(:streaming_models) do
        [
          ::AuditEvent,
          ::AuditEvents::GroupAuditEvent,
          ::AuditEvents::ProjectAuditEvent,
          ::AuditEvents::UserAuditEvent,
          ::AuditEvents::InstanceAuditEvent
        ]
      end

      it 'has every streaming-path audit event table drawing ids from audit_events_id_seq' do
        streaming_models.each do |model|
          id_column = model.connection.columns(model.table_name).find { |column| column.name == 'id' }

          expect(id_column.default_function).to eq("nextval('audit_events_id_seq'::regclass)"),
            "#{model.table_name}.id no longer defaults to audit_events_id_seq " \
              "(got: #{id_column.default_function.inspect}). EnqueueService#stable_id relies on a " \
              "single shared sequence for collision-free deduplication keys."
        end
      end
    end
  end
end

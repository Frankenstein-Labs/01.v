# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::ProcessAuditEventsWorker, feature_category: :audit_events do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }

  let(:event_id_one) { SecureRandom.uuid }
  let(:event_id_two) { SecureRandom.uuid }
  let(:event_time_one) { DateTime.parse('2026-01-01T00:00:00Z') }
  let(:event_time_two) { DateTime.parse('2026-01-01T00:00:01Z') }

  let(:serialized_events) do
    [
      {
        'cloud_event_id' => event_id_one,
        'event_name' => 'ai_llm_input_sent',
        'created_at' => event_time_one.iso8601,
        'author_id' => user.id,
        'project_id' => project.id,
        'namespace_id' => nil,
        'ip_address' => nil,
        'workflow_id' => workflow.id,
        'details' => { 'model' => 'claude-3' }
      },
      {
        'cloud_event_id' => event_id_two,
        'event_name' => 'ai_llm_response_received',
        'created_at' => event_time_two.iso8601,
        'author_id' => user.id,
        'project_id' => project.id,
        'namespace_id' => nil,
        'ip_address' => nil,
        'workflow_id' => workflow.id,
        'details' => {}
      }
    ]
  end

  subject(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [serialized_events] }

    before do
      # Storage is opt-in, so enable it here; otherwise the worker returns early
      # and the idempotency check no longer exercises the dedup path.
      project.project_setting.update!(ai_audit_events_storage_enabled: true)
    end
  end

  describe '#perform' do
    context 'when ClickHouse is not globally enabled for analytics' do
      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        project.project_setting.update!(ai_audit_events_storage_enabled: true)
      end

      it 'persists records to Postgres' do
        expect { worker.perform(serialized_events) }
          .to change { ::AuditEvents::AiAuditEvent.count }.by(2)

        persisted = ::AuditEvents::AiAuditEvent.where(cloud_event_id: [event_id_one, event_id_two])
        expect(persisted.pluck(:cloud_event_id)).to contain_exactly(event_id_one, event_id_two)
        expect(persisted.pluck(:event_name))
          .to contain_exactly('ai_llm_input_sent', 'ai_llm_response_received')
        expect(persisted.pluck(:workflow_id).uniq).to eq([workflow.id])
        expect(persisted.pluck(:author_id).uniq).to eq([user.id])
      end

      it 'deduplicates retried batches via the unique index' do
        worker.perform(serialized_events)

        expect { worker.perform(serialized_events) }
          .not_to change { ::AuditEvents::AiAuditEvent.count }
      end

      it 'increments STORED_COUNTER with store: :postgresql by the event count' do
        expect(described_class::STORED_COUNTER)
          .to receive(:increment).with({ store: :postgresql }, 2)

        worker.perform(serialized_events)
      end

      it 'increments PG_FALLBACK_COUNTER by the event count' do
        allow(described_class::STORED_COUNTER).to receive(:increment)

        expect(described_class::PG_FALLBACK_COUNTER)
          .to receive(:increment).with({}, 2)

        worker.perform(serialized_events)
      end

      it 'does not increment BUFFERED_COUNTER' do
        allow(described_class::STORED_COUNTER).to receive(:increment)

        expect(described_class::BUFFERED_COUNTER).not_to receive(:increment)

        worker.perform(serialized_events)
      end
    end

    context 'when ClickHouse is globally enabled for analytics' do
      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        project.project_setting.update!(ai_audit_events_storage_enabled: true)
      end

      it 'buffers records to ClickHouse and does not insert into Postgres' do
        expect(ClickHouse::WriteBuffer).to receive(:add).with('ai_audit_events', anything).twice
        expect { worker.perform(serialized_events) }.not_to change { ::AuditEvents::AiAuditEvent.count }
      end

      it 'increments BUFFERED_COUNTER by the actual buffered count, not the total event count',
        :clean_gitlab_redis_shared_state do
        # store_to_clickhouse returns false for an invalid record, so only the valid
        # event is buffered and counted.
        serialized_events.last['workflow_id'] = nil

        expect(described_class::BUFFERED_COUNTER).to receive(:increment).with({}, 1)

        worker.perform(serialized_events)
      end

      it 'increments BUFFERED_COUNTER by the full event count when all records buffer successfully' do
        allow(ClickHouse::WriteBuffer).to receive(:add).and_return('OK')

        expect(described_class::BUFFERED_COUNTER).to receive(:increment).with({}, 2)

        worker.perform(serialized_events)
      end

      it 'does not increment STORED_COUNTER or PG_FALLBACK_COUNTER' do
        allow(ClickHouse::WriteBuffer).to receive(:add).and_return('OK')
        allow(described_class::BUFFERED_COUNTER).to receive(:increment)

        expect(described_class::STORED_COUNTER).not_to receive(:increment)
        expect(described_class::PG_FALLBACK_COUNTER).not_to receive(:increment)

        worker.perform(serialized_events)
      end
    end

    it 'streams each event via the Streamer' do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)

      expect(::AuditEvents::AiAuditEvents::Streamer)
        .to receive(:stream).with(kind_of(::AuditEvents::AiAuditEvent)).twice

      worker.perform(serialized_events)
    end

    it 'logs each event to the audit JSON log' do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)

      logger = instance_double(Gitlab::AuditJsonLogger)
      allow(Gitlab::AuditJsonLogger).to receive(:build).and_return(logger)

      expect(logger).to receive(:info).with(hash_including(cloud_event_id: event_id_one)).ordered
      expect(logger).to receive(:info).with(hash_including(cloud_event_id: event_id_two)).ordered

      worker.perform(serialized_events)
    end

    context 'when the storage setting gates persistence' do
      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
      end

      context 'when storage is disabled for the project' do
        before do
          project.project_setting.update!(ai_audit_events_storage_enabled: false)
        end

        it 'does not persist the events' do
          expect { worker.perform(serialized_events) }
            .not_to change { ::AuditEvents::AiAuditEvent.count }
        end

        it 'still streams the events' do
          expect(::AuditEvents::AiAuditEvents::Streamer)
            .to receive(:stream).with(kind_of(::AuditEvents::AiAuditEvent)).twice

          worker.perform(serialized_events)
        end
      end

      context 'when storage is disabled for a namespace-scoped event' do
        let_it_be_with_reload(:group) { create(:group) }

        let(:namespace_events) do
          [serialized_events.first.merge('project_id' => nil, 'namespace_id' => group.id)]
        end

        before do
          group.namespace_settings.update!(ai_audit_events_storage_enabled: false)
        end

        it 'does not persist the events' do
          expect { worker.perform(namespace_events) }
            .not_to change { ::AuditEvents::AiAuditEvent.count }
        end
      end

      context 'when the project and namespace cannot be resolved' do
        let(:unresolvable_events) do
          [serialized_events.first.merge('project_id' => non_existing_record_id, 'namespace_id' => nil)]
        end

        it 'does not persist the events' do
          expect { worker.perform(unresolvable_events) }
            .not_to change { ::AuditEvents::AiAuditEvent.count }
        end

        it 'still streams the events' do
          expect(::AuditEvents::AiAuditEvents::Streamer)
            .to receive(:stream).with(kind_of(::AuditEvents::AiAuditEvent)).once

          worker.perform(unresolvable_events)
        end
      end
    end

    context 'when serialized_events is blank' do
      it 'returns early without incrementing storage counters' do
        expect(::AuditEvents::AiAuditEvent).not_to receive(:bulk_insert!)
        expect(described_class::STORED_COUNTER).not_to receive(:increment)
        expect(described_class::BUFFERED_COUNTER).not_to receive(:increment)
        expect(described_class::PG_FALLBACK_COUNTER).not_to receive(:increment)

        worker.perform([])
        worker.perform(nil)
      end
    end
  end
end

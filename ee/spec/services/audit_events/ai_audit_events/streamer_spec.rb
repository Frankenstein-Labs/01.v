# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AiAuditEvents::Streamer, feature_category: :audit_events do
  let_it_be(:project) { create(:project) }
  let(:ai_audit_event) { build(:audit_events_ai_audit_event, target_project: project) }

  describe '.stream' do
    subject(:stream) { described_class.stream(ai_audit_event) }

    context 'when the instance setting is disabled (default)' do
      it 'does not enqueue the streaming worker' do
        expect(::AuditEvents::AiAuditEventStreamingWorker).not_to receive(:perform_async)

        stream
      end
    end

    context 'when the instance setting is enabled' do
      before do
        ::Ai::Setting.for_organization(project.organization).update!(ai_audit_events_streaming_enabled: true)
      end

      it 'enqueues the worker with the streaming JSON payload' do
        expect(::AuditEvents::AiAuditEventStreamingWorker)
          .to receive(:perform_async).with(ai_audit_event.streaming_json)

        stream
      end

      context 'when SilentMode is enabled' do
        before do
          allow(::Gitlab::SilentMode).to receive(:enabled?).and_return(true)
        end

        it 'does not enqueue the worker' do
          expect(::AuditEvents::AiAuditEventStreamingWorker).not_to receive(:perform_async)

          stream
        end
      end
    end
  end
end

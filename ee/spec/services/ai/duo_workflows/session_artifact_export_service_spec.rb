# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::SessionArtifactExportService, feature_category: :compliance_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:workflow) do
    create(:duo_workflows_workflow,
      project: project,
      workflow_definition: 'software_development',
      created_at: Time.utc(2026, 6, 1, 10, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 11, 0, 0))
  end

  subject(:payload) { described_class.new(workflow).as_json }

  describe '#as_json' do
    describe 'session summary' do
      it 'includes the session metadata', :aggregate_failures do
        expect(payload[:session]).to include(
          id: workflow.id,
          workflow_definition: 'software_development'
        )
        expect(Time.zone.parse(payload[:session][:created_at])).to be_like_time(Time.utc(2026, 6, 1, 10))
        expect(Time.zone.parse(payload[:session][:updated_at])).to be_like_time(Time.utc(2026, 6, 1, 11))
      end

      it 'includes the project summary' do
        expect(payload[:session][:project]).to eq(
          id: project.id,
          name: project.name,
          full_path: project.full_path
        )
      end

      context 'when the session has no project' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:workflow) { create(:duo_workflows_workflow, project: nil, namespace: namespace) }

        it 'returns a nil project' do
          expect(payload[:session][:project]).to be_nil
        end
      end
    end

    describe 'audit events' do
      context 'on the Postgres path' do
        let_it_be(:audit_event) do
          create(:audit_events_ai_audit_event,
            workflow_id: workflow.id,
            event_name: 'ai_agent_session_started',
            author_id: 42,
            ip_address: IPAddr.new('10.0.0.1'),
            created_at: Time.utc(2026, 6, 1, 10, 30, 0))
        end

        let_it_be(:event_for_other_session) do
          create(:audit_events_ai_audit_event, workflow_id: non_existing_record_id)
        end

        before_all do
          audit_event
          event_for_other_session
        end

        it 'serializes only the events belonging to the session', :aggregate_failures do
          expect(payload[:audit_events]).to contain_exactly(
            hash_including(
              id: audit_event.cloud_event_id,
              event_name: 'ai_agent_session_started',
              author_id: 42,
              ip_address: '10.0.0.1'
            )
          )
          expect(Time.zone.parse(payload[:audit_events].first[:created_at]))
            .to be_like_time(Time.utc(2026, 6, 1, 10, 30))
        end

        it 'includes the details payload as a hash' do
          details = payload[:audit_events].first[:details]

          expect(details).to be_a(Hash)
          expect(details.transform_keys(&:to_s)).to include('session_id' => 'session-abc123')
        end
      end

      context 'on the ClickHouse path' do
        let(:clickhouse_rows) do
          [
            {
              'id' => 'ch-event-1',
              'event_name' => 'ai_llm_input_sent',
              'author_id' => 7,
              'ip_address' => '192.168.0.2',
              'created_at' => '2026-06-01T12:00:00Z',
              'details' => '{"prompt":"hello"}'
            }
          ]
        end

        before do
          allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
          allow(::ClickHouse::Client).to receive(:select).and_return(clickhouse_rows)
        end

        it 'serializes ClickHouse hash rows with the same shape', :aggregate_failures do
          expect(payload[:audit_events]).to contain_exactly(
            hash_including(
              id: 'ch-event-1',
              event_name: 'ai_llm_input_sent',
              author_id: 7,
              ip_address: '192.168.0.2',
              details: { 'prompt' => 'hello' }
            )
          )
          expect(Time.zone.parse(payload[:audit_events].first[:created_at]))
            .to eq(Time.utc(2026, 6, 1, 12, 0, 0))
        end
      end

      context 'when the session has no audit events' do
        it 'returns an empty array' do
          expect(payload[:audit_events]).to eq([])
        end
      end
    end
  end
end

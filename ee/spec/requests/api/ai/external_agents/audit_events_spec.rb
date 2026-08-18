# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::ExternalAgents::AuditEvents, feature_category: :software_composition_analysis do
  let_it_be_with_reload(:group) do
    group = create(:group)
    group.namespace_settings.update_column(:duo_external_agents_enabled, true)
    group
  end

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:other_user) { create(:user, developer_of: project) }
  let_it_be(:identity) do
    create(:ai_agent_identity, user: user, project: project,
      agent_type: 'claude-code', machine_fingerprint: 'a' * 64)
  end

  let_it_be_with_reload(:session) do
    create(:duo_workflows_workflow, :running, user: user, project: project,
      environment: :external, agent_type: 'claude-code', sync_type: :hook,
      agent_identity_id: identity.id)
  end

  let(:base_path) { "/projects/#{project.id}/ai_agent/audit_events" }
  let(:cloud_event_id) { SecureRandom.uuid }
  let(:valid_params) do
    {
      session_id: session.id,
      events: [
        {
          event_name: 'ai_tool_invoked',
          cloud_event_id: cloud_event_id,
          occurred_at: Time.current.iso8601,
          details: { tool_name: 'Bash' }
        }
      ]
    }
  end

  before do
    stub_licensed_features(ai_catalog: true)
  end

  describe 'POST /api/v4/projects/:id/ai_agent/audit_events' do
    subject(:post_request) { post api(base_path, user), params: valid_params }

    it 'accepts events and returns 202' do
      post_request

      expect(response).to have_gitlab_http_status(:accepted)
      expect(json_response['status']).to eq('accepted')
      expect(json_response['count']).to eq(1)
    end

    it 'enqueues a ProcessAuditEventsWorker job' do
      expect { post_request }.to change { Ai::DuoWorkflows::ProcessAuditEventsWorker.jobs.size }.by(1)
    end

    context 'with multiple events' do
      let(:valid_params) do
        {
          session_id: session.id,
          events: [
            {
              event_name: 'ai_tool_invoked',
              cloud_event_id: SecureRandom.uuid,
              occurred_at: Time.current.iso8601,
              details: { tool_name: 'Bash' }
            },
            {
              event_name: 'ai_tool_invoked',
              cloud_event_id: SecureRandom.uuid,
              occurred_at: Time.current.iso8601,
              details: { tool_name: 'Edit' }
            }
          ]
        }
      end

      it 'accepts all events' do
        post_request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(json_response['count']).to eq(2)
      end
    end

    context 'with an unknown event type' do
      let(:valid_params) do
        super().merge(events: [
          {
            event_name: 'unknown_event_type',
            cloud_event_id: SecureRandom.uuid,
            occurred_at: Time.current.iso8601
          }
        ])
      end

      it 'returns accepted with dropped event types noted' do
        post_request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(json_response['count']).to eq(0)
        expect(json_response['dropped_unknown_event_types']).to include('unknown_event_type')
      end
    end

    context 'with an invalid cloud_event_id format' do
      let(:valid_params) do
        super().merge(events: [
          {
            event_name: 'ai_tool_invoked',
            cloud_event_id: 'not-a-uuid',
            occurred_at: Time.current.iso8601
          }
        ])
      end

      it 'returns bad request' do
        post_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when session does not exist' do
      let(:valid_params) { super().merge(session_id: 999999) }

      it 'returns not found' do
        post_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when session belongs to another user' do
      let_it_be(:other_session) do
        create(:duo_workflows_workflow, :running, user: other_user, project: project,
          environment: :external, agent_type: 'claude-code', sync_type: :hook,
          agent_identity_id: identity.id)
      end

      let(:valid_params) { super().merge(session_id: other_session.id) }

      it 'returns forbidden' do
        post_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post api(base_path), params: valid_params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ai_agent_session_tracking: false)
      end

      it 'returns not found' do
        post_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when license is not available' do
      before do
        stub_licensed_features(ai_catalog: false)
      end

      it 'returns forbidden' do
        post_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when duo_external_agents_enabled is false' do
      before do
        group.namespace_settings.update_column(:duo_external_agents_enabled, false)
      end

      it 'returns forbidden' do
        post_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_ai_agent_audit_event do
      let(:boundary_object) { project }
      let(:request) do
        post api(base_path, personal_access_token: pat), params: valid_params
      end
    end

    context 'when events array is empty' do
      let(:valid_params) { super().merge(events: []) }

      it 'returns bad request' do
        post_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when batch exceeds maximum size' do
      let(:valid_params) do
        super().merge(
          events: Array.new(::Ai::DuoWorkflows::IngestAuditEventsService::MAX_EVENTS_PER_REQUEST + 1) do
            {
              event_name: 'ai_tool_invoked',
              cloud_event_id: SecureRandom.uuid,
              occurred_at: Time.current.iso8601
            }
          end
        )
      end

      it 'returns bad request' do
        post_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when events include unknown event types alongside valid ones' do
      let(:valid_params) do
        super().merge(
          events: [
            {
              event_name: 'ai_tool_invoked',
              cloud_event_id: SecureRandom.uuid,
              occurred_at: Time.current.iso8601
            },
            {
              event_name: 'unknown_event',
              cloud_event_id: SecureRandom.uuid,
              occurred_at: Time.current.iso8601
            }
          ]
        )
      end

      it 'accepts valid events and notes dropped unknown types' do
        post_request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(json_response['count']).to eq(1)
        expect(json_response['dropped_unknown_event_types']).to include('unknown_event')
      end
    end

    context 'when user is not a project member' do
      let(:non_member) { create(:user) }

      it 'returns not found' do
        post api(base_path, non_member), params: valid_params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the rate limit is exceeded' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)
        allow(Gitlab::ApplicationRateLimiter).to receive(:interval)
          .with(:ai_agent_audit_event_ingest)
          .and_return(60)
      end

      it 'returns 429' do
        post_request

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when cloud_event_id is a duplicate' do
      it 'returns accepted -- deduplication is handled by the worker' do
        post_request
        post_request

        expect(response).to have_gitlab_http_status(:accepted)
        expect(json_response['count']).to eq(1)
      end
    end
  end
end

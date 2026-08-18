# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::AuditEvents, feature_category: :audit_events do
  let_it_be(:user) { create(:user) }
  let_it_be(:token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }
  let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/audit_events" }
  let(:valid_events) do
    [
      {
        id: SecureRandom.uuid,
        type: 'ai_llm_input_sent',
        source: '/duo_workflow_service',
        time: '2026-01-01T00:00:00Z',
        data: { model: 'claude-3' }
      }
    ]
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }

  before_all do
    project.add_developer(user)
  end

  before do
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    allow_next_found_instance_of(User) do |user|
      allow(user).to receive(:allowed_to_use?).and_return(true)
    end
    project.update!(duo_features_enabled: true)
  end

  describe 'POST /ai/duo_workflows/workflows/:id/audit_events' do
    context 'when authenticated with ai_workflows scope' do
      it 'returns 202 with accepted payload' do
        post api(path), params: { events: valid_events },
          headers: { 'Authorization' => "Bearer #{token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:accepted)
        expect(json_response['status']).to eq('accepted')
        expect(json_response['count']).to eq(1)
      end
    end

    context 'when authenticated with a composite identity token', :request_store do
      let_it_be(:service_account) { create(:user, :ai_service_account) }
      let(:composite_token) do
        create(:oauth_access_token, user: service_account, scopes: "user:#{user.id} ai_workflows")
      end

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_duo_workflow, workflow).and_return(true)
      end

      it 'attributes the events to the service account and records the human in details', :aggregate_failures do
        enqueued_attrs = nil
        allow(::Ai::DuoWorkflows::ProcessAuditEventsWorker)
          .to receive(:perform_async) { |attrs| enqueued_attrs = attrs }

        post api(path), params: { events: valid_events },
          headers: { 'Authorization' => "Bearer #{composite_token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:accepted)
        expect(enqueued_attrs.first['author_id']).to eq(service_account.id)
        expect(enqueued_attrs.first['details'].with_indifferent_access).to include(
          human_author_id: user.id,
          human_author_name: user.name,
          human_author_username: user.username
        )
      end
    end

    context 'when user cannot read the workflow' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :read_duo_workflow, workflow).and_return(false)
      end

      it 'returns 403' do
        post api(path), params: { events: valid_events },
          headers: { 'Authorization' => "Bearer #{token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post api(path), params: { events: valid_events }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when workflow belongs to a different user' do
      let_it_be(:other_user) { create(:user) }
      let_it_be(:other_token) { create(:oauth_access_token, user: other_user, scopes: [:ai_workflows]) }

      it 'returns 404' do
        post api(path), params: { events: valid_events },
          headers: { 'Authorization' => "Bearer #{other_token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when events param is missing' do
      it 'returns 400' do
        post api(path), params: {}, headers: { 'Authorization' => "Bearer #{token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when batch exceeds max size' do
      let(:oversized_events) do
        Array.new(501) do
          { id: SecureRandom.uuid, type: 'ai_llm_input_sent', source: '/', time: '2026-01-01T00:00:00Z' }
        end
      end

      it 'returns 400' do
        post api(path), params: { events: oversized_events },
          headers: { 'Authorization' => "Bearer #{token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when an event is missing time' do
      let(:event_without_time) do
        [{ id: SecureRandom.uuid, type: 'ai_llm_input_sent', source: '/duo_workflow_service' }]
      end

      it 'returns 400 rather than accepting the event with a fabricated timestamp' do
        post api(path), params: { events: event_without_time },
          headers: { 'Authorization' => "Bearer #{token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when an event has an unparseable time' do
      let(:event_with_bad_time) do
        [{ id: SecureRandom.uuid, type: 'ai_llm_input_sent', source: '/duo_workflow_service', time: 'not-a-date' }]
      end

      it 'returns 400 rather than silently stamping the current time' do
        post api(path), params: { events: event_with_bad_time },
          headers: { 'Authorization' => "Bearer #{token.plaintext_token}" }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when an event has a type not in the allowlist' do
      let(:event_with_unknown_type) do
        [{
          id: SecureRandom.uuid,
          type: 'totally_made_up_event',
          source: '/duo_workflow_service',
          time: '2026-01-01T00:00:00Z'
        }]
      end

      it 'drops the unknown event, accepts the request, and reports it in the response' do
        expect do
          post api(path), params: { events: event_with_unknown_type },
            headers: { 'Authorization' => "Bearer #{token.plaintext_token}" }
        end.not_to change { ::AuditEvents::AiAuditEvent.count }

        expect(response).to have_gitlab_http_status(:accepted)
        expect(json_response['count']).to eq(0)
        expect(json_response['dropped_unknown_event_types']).to eq(['totally_made_up_event'])
      end
    end
  end
end

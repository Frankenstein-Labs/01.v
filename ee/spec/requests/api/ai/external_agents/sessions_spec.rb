# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::ExternalAgents::Sessions, feature_category: :software_composition_analysis do
  let_it_be(:group) do
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

  let(:base_path) { "/projects/#{project.id}/ai_agent/sessions" }

  before do
    stub_licensed_features(ai_catalog: true)
  end

  describe 'POST /api/v4/projects/:id/ai_agent/sessions' do
    let(:params) do
      {
        agent_type: 'claude-code',
        agent_identity_id: identity.id,
        sync_type: 'hook'
      }
    end

    subject(:post_request) { post api(base_path, user), params: params }

    it 'creates a session and returns 201' do
      expect { post_request }.to change { Ai::DuoWorkflows::Workflow.external.count }.by(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['agent_type']).to eq('claude-code')
      expect(json_response['sync_type']).to eq('hook')
      expect(json_response['status']).to eq('running')
      expect(json_response).to have_key('id')
    end

    context 'with idempotency key' do
      let(:params) { super().merge(idempotency_key: 'test-uuid-123') }

      it 'is idempotent' do
        post_request
        first_id = json_response['id']

        post_request
        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['id']).to eq(first_id)
        expect(Ai::DuoWorkflows::Workflow.external.where(idempotency_key: 'test-uuid-123').count).to eq(1)
      end
    end

    context 'when agent_type is invalid' do
      let(:params) { super().merge(agent_type: 'unknown-agent') }

      it 'returns 400' do
        post_request
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when sync_type is invalid' do
      let(:params) { super().merge(sync_type: 'invalid') }

      it 'returns 400' do
        post_request
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when user is a guest' do
      let_it_be(:guest) { create(:user, guest_of: project) }

      subject(:post_request) { post api(base_path, guest), params: params }

      it 'returns 403' do
        post_request
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when user is a reporter' do
      let_it_be(:reporter) { create(:user, reporter_of: project) }

      subject(:post_request) { post api(base_path, reporter), params: params }

      it 'returns 403' do
        post_request
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when user is a maintainer' do
      let_it_be(:maintainer) { create(:user, maintainer_of: project) }
      let_it_be(:maintainer_identity) do
        create(:ai_agent_identity, user: maintainer, project: project,
          agent_type: 'claude-code', machine_fingerprint: 'b' * 64)
      end

      subject(:post_request) do
        post api(base_path, maintainer),
          params: params.merge(agent_identity_id: maintainer_identity.id)
      end

      it 'returns 201' do
        post_request
        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when unauthenticated' do
      subject(:post_request) { post api(base_path), params: params }

      it 'returns 401' do
        post_request
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ai_agent_session_tracking: false)
      end

      it 'returns 404' do
        post_request
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when rate limit is exceeded' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)
        allow(Gitlab::ApplicationRateLimiter).to receive(:interval)
          .with(:ai_agent_session_creation)
          .and_return(60)
      end

      it 'returns 429' do
        post_request
        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_ai_agent_session do
      let(:boundary_object) { project }
      let(:request) do
        post api(base_path, personal_access_token: pat), params: params
      end
    end

    context 'when idempotency_key exceeds 255 characters' do
      let(:params) { super().merge(idempotency_key: 'a' * 256) }

      it 'returns 400' do
        post_request
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when started_at is in the future' do
      let(:params) { super().merge(started_at: 1.hour.from_now.iso8601) }

      it 'returns 400' do
        post_request
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when agent_identity belongs to a different agent_type' do
      let_it_be(:opencode_identity) do
        create(:ai_agent_identity, user: user, project: project,
          agent_type: 'opencode', machine_fingerprint: 'b' * 64)
      end

      let(:params) { super().merge(agent_type: 'claude-code', agent_identity_id: opencode_identity.id) }

      it 'returns 404' do
        post_request
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /api/v4/projects/:id/ai_agent/sessions/:session_id' do
    let(:path) { "#{base_path}/#{session.id}" }
    let(:params) { { status: 'completed' } }

    subject(:patch_request) { patch api(path, user), params: params }

    it 'completes the session and returns 200' do
      patch_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['status']).to eq('finished')
    end

    context 'when status is failed' do
      let(:params) { { status: 'failed' } }

      it 'fails the session' do
        patch_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['status']).to eq('failed')
      end
    end

    context 'when jsonl_sha256 matches stored value and session is already terminal' do
      before do
        session.update!(jsonl_sha256: 'a' * 64)
        session.finish!
      end

      let(:params) { { status: 'completed', jsonl_sha256: 'a' * 64 } }

      it 'returns 200 with existing record unchanged' do
        patch_request
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['status']).to eq('finished')
      end
    end

    context 'when session belongs to another user' do
      subject(:patch_request) { patch api(path, other_user), params: params }

      it 'returns 403' do
        patch_request
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when session does not exist' do
      let(:path) { "#{base_path}/#{non_existing_record_id}" }

      it 'returns 404' do
        patch_request
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      subject(:patch_request) { patch api(path), params: params }

      it 'returns 401' do
        patch_request
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :update_ai_agent_session do
      let(:boundary_object) { project }
      let(:request) do
        patch api("#{base_path}/#{session.id}", personal_access_token: pat),
          params: { status: 'completed' }
      end
    end

    context 'when jsonl_sha256 exceeds 64 characters' do
      let(:params) { { status: 'completed', jsonl_sha256: 'a' * 65 } }

      it 'returns 400' do
        patch_request
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when jsonl_sha256 is not a valid hex string' do
      let(:params) { { status: 'completed', jsonl_sha256: 'z' * 64 } }

      it 'returns 400' do
        patch_request
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :update_ai_agent_session do
      let(:boundary_object) { project }
      let(:request) do
        patch api("#{base_path}/#{session.id}", personal_access_token: pat),
          params: { status: 'completed' }
      end
    end
  end

  describe 'GET /api/v4/projects/:id/ai_agent/sessions' do
    subject(:get_request) { get api(base_path, user) }

    it 'returns sessions and 200' do
      get_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_an(Array)
      expect(json_response.first['agent_type']).to eq('claude-code')
    end

    context 'with agent_type filter' do
      subject(:get_request) { get api(base_path, user), params: { agent_type: 'claude-code' } }

      it 'filters by agent type' do
        get_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.map { |s| s['agent_type'] }.uniq).to eq(['claude-code'])
      end
    end

    context 'with status filter' do
      subject(:get_request) { get api(base_path, user), params: { status: 'running' } }

      it 'filters by status' do
        get_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.map { |s| s['status'] }.uniq).to eq(['running'])
      end
    end

    context 'when unauthenticated' do
      subject(:get_request) { get api(base_path) }

      it 'returns 401' do
        get_request
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_ai_agent_session do
      let(:boundary_object) { project }
      let(:request) do
        get api(base_path, personal_access_token: pat)
      end
    end

    context 'when another user has sessions on the project' do
      let_it_be(:other_session) do
        create(:duo_workflows_workflow, :running, user: other_user, project: project,
          environment: :external, agent_type: 'claude-code', sync_type: :hook,
          agent_identity_id: identity.id)
      end

      it 'only returns the current user sessions' do
        get_request

        expect(response).to have_gitlab_http_status(:ok)
        returned_user_ids = json_response.map { |s| s['user_id'] }.uniq
        expect(returned_user_ids).to eq([user.id])
        expect(returned_user_ids).not_to include(other_user.id)
      end
    end

    it 'includes user_id in the response for attribution' do
      get_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.first).to have_key('user_id')
      expect(json_response.first['user_id']).to eq(session.user_id)
    end
  end
end

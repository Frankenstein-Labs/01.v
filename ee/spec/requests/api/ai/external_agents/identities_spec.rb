# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::ExternalAgents::Identities, feature_category: :software_composition_analysis do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:non_member) { create(:user) }

  let(:agent_type) { 'claude-code' }
  let(:machine_fingerprint) { 'a' * 64 }
  let(:path) { "/projects/#{project.id}/ai_agent/identities" }

  describe 'POST /api/v4/projects/:id/ai_agent/identities' do
    let(:params) { { agent_type: agent_type, machine_fingerprint: machine_fingerprint } }

    subject(:post_request) { post api(path, user), params: params }

    before do
      stub_licensed_features(ai_catalog: true)
      allow(group).to receive(:duo_external_agents_enabled).and_return(true)
    end

    context 'when the user is a guest on the project' do
      let_it_be(:guest) { create(:user, guest_of: project) }

      subject(:post_request) { post api(path, guest), params: params }

      it 'returns 403' do
        post_request
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the user is a reporter on the project' do
      let_it_be(:reporter) { create(:user, reporter_of: project) }

      subject(:post_request) { post api(path, reporter), params: params }

      it 'returns 403' do
        post_request
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the user is a maintainer on the project' do
      let_it_be(:maintainer) { create(:user, maintainer_of: project) }

      subject(:post_request) { post api(path, maintainer), params: params }

      it 'returns 201' do
        post_request
        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the user is a developer on the project' do
      it 'creates an identity and returns 201' do
        expect { post_request }.to change { Ai::ExternalAgents::AgentIdentity.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['agent_type']).to eq(agent_type)
        expect(json_response['revoked_at']).to be_nil
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('created_at')
        expect(json_response).not_to have_key('machine_fingerprint')
      end

      it 'is idempotent -- returns the same record on repeat calls' do
        post_request
        first_id = json_response['id']

        post_request

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['id']).to eq(first_id)
        expect(Ai::ExternalAgents::AgentIdentity.count).to eq(1)
      end

      context 'when the identity has been revoked' do
        before do
          create(:ai_agent_identity, user: user, project: project,
            agent_type: agent_type, machine_fingerprint: machine_fingerprint,
            revoked_at: Time.current)
        end

        it 'returns 403' do
          post_request

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to include('revoked')
        end
      end

      context 'when agent_type is not in the allowlist' do
        let(:params) { { agent_type: 'unknown-agent', machine_fingerprint: machine_fingerprint } }

        it 'returns 400' do
          post_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when machine_fingerprint is missing' do
        let(:params) { { agent_type: agent_type } }

        it 'returns 400' do
          post_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when machine_fingerprint exceeds 64 characters' do
        let(:params) { { agent_type: agent_type, machine_fingerprint: 'a' * 65 } }

        it 'returns 400' do
          post_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when the user is not a member of the project' do
      subject(:post_request) { post api(path, non_member), params: params }

      it 'returns 404' do
        post_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      subject(:post_request) { post api(path), params: params }

      it 'returns 401' do
        post_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the ai_catalog feature is not licensed' do
      before do
        stub_licensed_features(ai_catalog: false)
      end

      it 'returns 403' do
        post_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_ai_agent_identity do
      let(:boundary_object) { project }
      let(:request) do
        post api("/projects/#{project.id}/ai_agent/identities", personal_access_token: pat),
          params: { agent_type: 'claude-code', machine_fingerprint: 'a' * 64 }
      end
    end

    context 'when the ai_agent_session_tracking feature flag is disabled' do
      before do
        stub_feature_flags(ai_agent_session_tracking: false)
      end

      it 'returns 404' do
        post_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the rate limit is exceeded' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)
        allow(Gitlab::ApplicationRateLimiter).to receive(:interval)
          .with(:ai_agent_identity_registration)
          .and_return(60)
      end

      it 'returns 429' do
        post_request

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end
  end
end

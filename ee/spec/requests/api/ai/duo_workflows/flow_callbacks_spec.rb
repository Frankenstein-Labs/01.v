# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::FlowCallbacks, :with_current_organization, :aggregate_failures,
  feature_category: :duo_agent_platform do
  let_it_be(:current_organization) { create(:organization) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:member) { create(:user) }
  let_it_be(:non_member) { create(:user) }

  # `user` is the identity used by the 'authorizing granular token permissions'
  # shared example to mint PATs; the abilities under test require organization
  # ownership, so it must resolve to `owner`.
  let(:user) { owner }

  let(:signing_token) { "whsec_#{Base64.strict_encode64(SecureRandom.bytes(32))}" }

  before_all do
    create(:organization_user, :owner, organization: current_organization, user: owner)
    create(:organization_user, organization: current_organization, user: member, access_level: :default)
  end

  describe 'POST /ai/duo_workflows/flow_callbacks' do
    let(:params) { { url: 'https://autoflow.example.com/duo/callbacks', name: 'AutoFlow', signing_token: signing_token } }
    let(:path) { '/ai/duo_workflows/flow_callbacks' }

    subject(:register) { post api(path, owner), params: params }

    it 'registers an org-scoped hook and never returns the secret' do
      expect { register }.to change { ::Ai::DuoWorkflows::FlowCallbackHook.count }.by(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response).to include('url' => params[:url], 'name' => 'AutoFlow', 'signing_token_set' => true)
      expect(json_response).not_to have_key('signing_token')

      hook = ::Ai::DuoWorkflows::FlowCallbackHook.last
      expect(hook.organization).to eq(current_organization)
      expect(hook.signing_token).to eq(signing_token)
    end

    it_behaves_like 'authorizing granular token permissions', :create_duo_flow_callback_hook do
      let(:boundary_object) { :instance }
      let(:request) { post api(path, personal_access_token: pat), params: params }
    end

    context 'when the signing_token is malformed' do
      let(:params) { super().merge(signing_token: 'not-a-whsec-token') }

      it 'returns a validation error' do
        register

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when the url is not HTTPS' do
      let(:params) { super().merge(url: 'http://autoflow.example.com/duo/callbacks') }

      it 'returns a validation error' do
        allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)

        register

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when the caller is not an organization owner' do
      subject(:register) { post api(path, member), params: params }

      it 'is forbidden' do
        register

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the caller is not a member of the organization' do
      subject(:register) { post api(path, non_member), params: params }

      it 'is forbidden' do
        register

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'is rejected' do
        post api(path), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when an organization could not be resolved' do
      before do
        stub_current_organization(nil)
      end

      it 'returns bad request' do
        expect { register }.not_to change { ::Ai::DuoWorkflows::FlowCallbackHook.count }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  describe 'GET /ai/duo_workflows/flow_callbacks' do
    let_it_be(:hook) { create(:duo_workflows_flow_callback_hook, organization: current_organization) }
    let_it_be(:other_org_hook) { create(:duo_workflows_flow_callback_hook) }
    let(:path) { '/ai/duo_workflows/flow_callbacks' }

    it 'lists only the callers organization hooks' do
      get api(path, owner)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.map { |h| h['id'] }).to contain_exactly(hook.id)
      expect(json_response.first).not_to have_key('signing_token')
    end

    it_behaves_like 'authorizing granular token permissions', :read_duo_flow_callback_hook do
      let(:boundary_object) { :instance }
      let(:request) { get api(path, personal_access_token: pat) }
    end

    context 'when the caller is not an organization owner' do
      it 'is forbidden' do
        get api(path, member)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'is rejected' do
        get api(path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when an organization could not be resolved' do
      before do
        stub_current_organization(nil)
      end

      it 'returns bad request' do
        get api(path, owner)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  describe 'GET /ai/duo_workflows/flow_callbacks/:id' do
    let_it_be(:hook) { create(:duo_workflows_flow_callback_hook, organization: current_organization) }
    let(:path) { "/ai/duo_workflows/flow_callbacks/#{hook.id}" }

    it 'returns the hook' do
      get api(path, owner)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(hook.id)
    end

    it_behaves_like 'authorizing granular token permissions', :read_duo_flow_callback_hook do
      let(:boundary_object) { :instance }
      let(:request) { get api(path, personal_access_token: pat) }
    end

    context 'when the caller is not an organization owner' do
      it 'is forbidden' do
        get api(path, member)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'is rejected' do
        get api(path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the hook belongs to another organization' do
      let_it_be(:other_hook) { create(:duo_workflows_flow_callback_hook) }
      let(:path) { "/ai/duo_workflows/flow_callbacks/#{other_hook.id}" }

      it 'is not found' do
        get api(path, owner)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when an organization could not be resolved' do
      before do
        stub_current_organization(nil)
      end

      it 'returns bad request' do
        get api(path, owner)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  describe 'DELETE /ai/duo_workflows/flow_callbacks/:id' do
    let_it_be_with_reload(:hook) { create(:duo_workflows_flow_callback_hook, organization: current_organization) }
    let(:path) { "/ai/duo_workflows/flow_callbacks/#{hook.id}" }

    subject(:destroy_hook) { delete api(path, owner) }

    it 'deletes the hook' do
      expect { destroy_hook }.to change { ::Ai::DuoWorkflows::FlowCallbackHook.count }.by(-1)

      expect(response).to have_gitlab_http_status(:no_content)
    end

    it_behaves_like 'authorizing granular token permissions', :delete_duo_flow_callback_hook do
      let(:boundary_object) { :instance }
      let(:request) { delete api(path, personal_access_token: pat) }
    end

    context 'when the caller is not an organization owner' do
      subject(:destroy_hook) { delete api(path, member) }

      it 'is forbidden' do
        destroy_hook

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the hook belongs to another organization' do
      let_it_be(:other_hook) { create(:duo_workflows_flow_callback_hook) }

      subject(:destroy_hook) { delete api("/ai/duo_workflows/flow_callbacks/#{other_hook.id}", owner) }

      it 'does not delete a hook from another organization' do
        expect { destroy_hook }.not_to change { ::Ai::DuoWorkflows::FlowCallbackHook.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when an organization could not be resolved' do
      before do
        stub_current_organization(nil)
      end

      it 'returns bad request' do
        expect { destroy_hook }.not_to change { ::Ai::DuoWorkflows::FlowCallbackHook.count }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end
end

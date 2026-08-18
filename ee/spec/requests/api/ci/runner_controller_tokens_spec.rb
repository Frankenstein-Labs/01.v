# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::RunnerControllerTokens, :aggregate_failures, feature_category: :continuous_integration do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be(:runner_controller) { create(:ci_runner_controller) }
  let_it_be(:path) { "/runner_controllers/#{runner_controller.id}/tokens" }
  let_it_be(:token) { create(:ci_runner_controller_token, runner_controller: runner_controller) }

  shared_examples 'returns status 403 (forbidden)' do
    specify do
      call_endpoint

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  shared_examples 'returns status 404 (not found)' do
    specify do
      call_endpoint

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  before do
    stub_licensed_features(ci_runner_controllers: true)
  end

  describe 'GET /runner_controllers/:runner_controller_id/tokens' do
    it_behaves_like 'authorizing granular token permissions', :read_runner_controller_token do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api(path, personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'returns a list of active runner controller tokens' do
        create_list(:ci_runner_controller_token, 2, runner_controller: runner_controller)
        revoked_token = create(:ci_runner_controller_token, :revoked, runner_controller: runner_controller)

        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(3)
        json_response.each do |token_response|
          expect(token_response['id']).not_to eq(revoked_token.id)
        end
      end
    end

    context 'when runner controller does not exist' do
      subject(:call_endpoint) do
        get api("/runner_controllers/#{non_existing_record_id}/tokens", admin, admin_mode: true)
      end

      it_behaves_like 'returns status 404 (not found)'
    end

    context 'when user is not admin' do
      subject(:call_endpoint) { get api(path, non_admin_user) }

      it_behaves_like 'returns status 403 (forbidden)'
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { get api(path, admin, admin_mode: true) }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'GET /runner_controllers/:runner_controller_id/tokens/:id' do
    it_behaves_like 'authorizing granular token permissions', :read_runner_controller_token do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api("#{path}/#{token.id}", personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'returns a single runner controller token' do
        get api("#{path}/#{token.id}", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => token.id,
          'runner_controller_id' => runner_controller.id,
          'last_used_at' => anything
        )
      end

      context 'when runner controller token does not exist' do
        subject(:call_endpoint) { get api("#{path}/#{non_existing_record_id}", admin, admin_mode: true) }

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when the token is revoked' do
        let(:revoked_token) { create(:ci_runner_controller_token, :revoked, runner_controller: runner_controller) }

        subject(:call_endpoint) { get api("#{path}/#{revoked_token.id}", admin, admin_mode: true) }

        it_behaves_like 'returns status 404 (not found)'
      end
    end

    context 'when user is not admin' do
      it 'returns status 403 (forbidden)' do
        get api("#{path}/#{token.id}", non_admin_user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when runner controller does not exist' do
      subject(:call_endpoint) do
        get api("/runner_controllers/#{non_existing_record_id}/tokens/1", admin, admin_mode: true)
      end

      it_behaves_like 'returns status 404 (not found)'
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { get api("#{path}/#{token.id}", admin, admin_mode: true) }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'POST /runner_controllers/:runner_controller_id/tokens' do
    let(:params) { { description: 'New Token' } }

    it_behaves_like 'authorizing granular token permissions', :create_runner_controller_token do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api(path, personal_access_token: pat), params: { description: 'New Token' } }
    end

    context 'when user is admin' do
      it 'creates a new runner controller token' do
        post api(path, admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['id']).to be_present
        expect(json_response['runner_controller_id']).to eq(runner_controller.id)
        expect(json_response['token']).to start_with('glrct-')
        expect(json_response['description']).to eq('New Token')
      end

      context 'when token save fails' do
        before do
          allow_next_instance_of(Ci::RunnerControllerToken) do |instance|
            allow(instance).to receive(:save).and_return(false)
            allow(instance).to receive_message_chain(:errors, :full_messages).and_return(['Validation failed'])
          end
        end

        it 'returns 400 with error message' do
          post api(path, admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Validation failed')
        end
      end

      context 'when runner controller does not exist' do
        subject(:call_endpoint) do
          post api("/runner_controllers/#{non_existing_record_id}/tokens", admin, admin_mode: true), params: params
        end

        it_behaves_like 'returns status 404 (not found)'
      end
    end

    context 'when user is not admin' do
      it 'returns status 403 (forbidden)' do
        post api(path, non_admin_user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { post api(path, admin, admin_mode: true) }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'DELETE /runner_controllers/:runner_controller_id/tokens/:id' do
    it_behaves_like 'authorizing granular token permissions', :revoke_runner_controller_token do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { delete api("#{path}/#{token.id}", personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'revokes the runner controller token' do
        delete api("#{path}/#{token.id}", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:no_content)
        expect(token.reload.revoked?).to be true
      end

      context 'when token revoke fails' do
        before do
          allow(Ci::RunnerControllerToken).to receive(:find_by_id).and_return(token)
          allow(token).to receive(:revoke!).and_return(false)
          allow(token).to receive_message_chain(:errors, :full_messages).and_return(['Revoke failed'])
        end

        it 'returns 400 with error message' do
          delete api("#{path}/#{token.id}", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Revoke failed')
        end
      end

      context 'when runner controller does not exist' do
        subject(:call_endpoint) do
          delete api("/runner_controllers/#{non_existing_record_id}/tokens/#{token.id}", admin, admin_mode: true)
        end

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when runner controller token does not exist' do
        subject(:call_endpoint) do
          delete api("#{path}/#{non_existing_record_id}", admin, admin_mode: true)
        end

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when the token is already revoked' do
        let(:revoked_token) { create(:ci_runner_controller_token, :revoked, runner_controller: runner_controller) }

        subject(:call_endpoint) { delete api("#{path}/#{revoked_token.id}", admin, admin_mode: true) }

        it_behaves_like 'returns status 404 (not found)'
      end
    end

    context 'when user is not admin' do
      it 'returns status 403 (forbidden)' do
        delete api("#{path}/#{token.id}", non_admin_user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /runner_controllers/:runner_controller_id/tokens/:id/rotate' do
    it_behaves_like 'authorizing granular token permissions', :rotate_runner_controller_token do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api("#{path}/#{token.id}/rotate", personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'rotates the runner controller token' do
        post api("#{path}/#{token.id}/rotate", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to be_present
        expect(json_response['runner_controller_id']).to eq(runner_controller.id)
        expect(json_response['token']).to start_with('glrct-')
        expect(json_response['description']).to eq(token.description)
        expect(token.reload.revoked?).to be true
      end

      context 'when token rotate fails' do
        before do
          allow(::Ci::RunnerControllers::RotateTokenService).to receive_message_chain(:new, :execute).and_return(
            ServiceResponse.error(message: 'Rotate failed', reason: :bad_request)
          )
        end

        it 'returns 400 with error message' do
          post api("#{path}/#{token.id}/rotate", admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Rotate failed')
        end
      end

      context 'when runner controller does not exist' do
        subject(:call_endpoint) do
          post api("/runner_controllers/#{non_existing_record_id}/tokens/#{token.id}/rotate", admin, admin_mode: true)
        end

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when runner controller token does not exist' do
        subject(:call_endpoint) do
          post api("#{path}/#{non_existing_record_id}/rotate", admin, admin_mode: true)
        end

        it_behaves_like 'returns status 404 (not found)'
      end
    end

    context 'when user is not admin' do
      it 'returns status 403 (forbidden)' do
        post api("#{path}/#{token.id}/rotate", non_admin_user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end

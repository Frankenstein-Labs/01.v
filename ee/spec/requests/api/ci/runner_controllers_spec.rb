# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::RunnerControllers, :aggregate_failures, feature_category: :continuous_integration do
  let_it_be(:path) { '/runner_controllers' }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be(:controller) { create(:ci_runner_controller) }

  before do
    stub_licensed_features(ci_runner_controllers: true)
  end

  shared_examples 'returns status 404 (not found)' do
    specify do
      call_endpoint

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /runner_controllers' do
    let(:user) { admin }
    let(:admin_mode) { true }

    subject(:make_request) { get api(path, user, admin_mode: admin_mode) }

    it_behaves_like 'authorizing granular token permissions', :read_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api(path, personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'returns a list of runner controllers' do
        create_list(:ci_runner_controller, 2)

        make_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(3)
        expect(json_response.first).to have_key('state')
      end
    end

    context 'when user is not admin' do
      let(:user) { non_admin_user }
      let(:admin_mode) { false }

      it 'returns status 403 (forbidden)' do
        make_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { make_request }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'GET /runner_controllers/:id' do
    let(:user) { admin }
    let(:admin_mode) { true }
    let(:controller_id) { controller.id }

    subject(:make_request) { get api("#{path}/#{controller_id}", user, admin_mode: admin_mode) }

    it_behaves_like 'authorizing granular token permissions', :read_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api("#{path}/#{controller.id}", personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'returns a single runner controller' do
        make_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => controller.id,
          'state' => controller.state,
          'connected' => anything
        )
      end

      context 'when controller has a recently used token' do
        before do
          create(:ci_runner_controller_token, :recently_used, runner_controller: controller)
        end

        it 'returns connected as true' do
          make_request

          expect(json_response).to include('connected' => true)
        end
      end

      context 'when controller has no recently used tokens' do
        it 'returns connected as false' do
          make_request

          expect(json_response).to include('connected' => false)
        end
      end

      context 'when runner controller does not exist' do
        let(:controller_id) { non_existing_record_id }

        it 'returns status 404 (not found)' do
          make_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not admin' do
      let(:user) { non_admin_user }
      let(:admin_mode) { false }

      it 'returns status 403 (forbidden)' do
        make_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { make_request }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'POST /runner_controllers' do
    let(:user) { admin }
    let(:admin_mode) { true }
    let(:request_params) { { description: 'New Controller' } }

    subject(:make_request) { post api(path, user, admin_mode: admin_mode), params: request_params }

    it_behaves_like 'authorizing granular token permissions', :create_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api(path, personal_access_token: pat), params: { description: 'New Controller' } }
    end

    context 'when user is admin' do
      it 'creates a new runner controller with default state' do
        make_request

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['description']).to eq('New Controller')
        expect(json_response['state']).to eq('disabled')
      end

      context 'with state set to enabled' do
        let(:request_params) { { description: 'New Controller', state: 'enabled' } }

        it 'creates a new runner controller' do
          make_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['description']).to eq('New Controller')
          expect(json_response['state']).to eq('enabled')
        end
      end

      context 'with state set to disabled' do
        let(:request_params) { { description: 'New Controller', state: 'disabled' } }

        it 'creates a new runner controller' do
          make_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['description']).to eq('New Controller')
          expect(json_response['state']).to eq('disabled')
        end
      end

      context 'with state set to dry_run' do
        let(:request_params) { { description: 'New Controller', state: 'dry_run' } }

        it 'creates a new runner controller' do
          make_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['description']).to eq('New Controller')
          expect(json_response['state']).to eq('dry_run')
        end
      end

      context 'when parameters are invalid' do
        context 'with invalid description' do
          let(:request_params) { { description: FFaker::Lorem.characters(1025) } }

          it 'returns status 400 (bad request)' do
            make_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'with invalid state' do
          let(:request_params) { { description: 'New Controller', state: 'invalid_state' } }

          it 'returns status 400 (bad request)' do
            make_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end
    end

    context 'when user is not admin' do
      let(:user) { non_admin_user }
      let(:admin_mode) { false }

      it 'returns status 403 (forbidden)' do
        make_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { make_request }

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'PUT /runner_controllers/:id' do
    let(:user) { admin }
    let(:admin_mode) { true }
    let(:request_params) { {} }
    let_it_be_with_refind(:controller) { create(:ci_runner_controller, :disabled, description: 'Initial Description') }
    let(:controller_to_update) { controller.id }

    subject(:make_request) do
      put api("#{path}/#{controller_to_update}", user, admin_mode: admin_mode), params: request_params
    end

    it_behaves_like 'authorizing granular token permissions', :update_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        put api("#{path}/#{controller.id}", personal_access_token: pat), params: { description: 'Updated' }
      end
    end

    context 'when user is admin' do
      context 'when updating a runner controller description' do
        let(:request_params) { { description: 'Updated Description' } }

        it 'changes the description' do
          make_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['description']).to eq('Updated Description')
          expect(json_response['state']).to eq(controller.state)
        end
      end

      context 'when updating a runner controller state to enabled' do
        let(:request_params) { { state: 'enabled' } }

        it 'enables the runner controller' do
          make_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['state']).to eq('enabled')
        end
      end

      context 'when updating a runner controller state to dry_run' do
        let(:request_params) { { state: 'dry_run' } }

        it 'sets the runner controller to dry_run' do
          make_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['state']).to eq('dry_run')
        end
      end

      context 'when updating a runner controller state to disabled' do
        let(:controller) { create(:ci_runner_controller, description: 'Initial Description', state: :enabled) }
        let(:request_params) { { state: 'disabled' } }

        it 'disables the runner controller' do
          make_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['state']).to eq('disabled')
        end
      end

      context 'when parameters are invalid' do
        let(:request_params) { { description: FFaker::Lorem.characters(1025) } }

        it 'returns status 400 (bad request)' do
          make_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when state is invalid' do
        let(:request_params) { { state: 'invalid_state' } }

        it 'returns status 400 (bad request)' do
          make_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when runner controller does not exist' do
        let(:request_params) { { description: 'Updated Description' } }
        let(:controller_to_update) { non_existing_record_id }

        it 'returns status 404 (not found)' do
          make_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not admin' do
      let(:request_params) { { description: 'Updated Description' } }
      let(:admin_mode) { false }
      let(:user) { nil }

      it 'returns status 401 (unauthorized)' do
        make_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /runner_controllers/:id' do
    let_it_be_with_refind(:controller_to_delete) { create(:ci_runner_controller) }

    let(:user) { admin }
    let(:admin_mode) { true }
    let(:headers) { {} }
    let(:controller_id) { controller_to_delete.id }

    subject(:make_request) do
      delete api("#{path}/#{controller_id}", user, admin_mode: admin_mode), headers: headers
    end

    it_behaves_like 'authorizing granular token permissions', :delete_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { delete api("#{path}/#{controller_to_delete.id}", personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'deletes a runner controller' do
        make_request

        expect(response).to have_gitlab_http_status(:no_content)
        expect(::Ci::RunnerController.find_by_id(controller_to_delete.id)).to be_nil
      end

      context 'when deletion fails' do
        it 'returns status 400 (bad request)' do
          allow_next_found_instance_of(::Ci::RunnerController) do |instance|
            allow(instance).to receive(:destroy).and_return(false)
          end

          make_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with If-Unmodified-Since header' do
        context 'when controller has not been modified since' do
          let(:headers) { { 'If-Unmodified-Since' => 1.day.from_now.httpdate } }

          it 'deletes the controller' do
            make_request

            expect(response).to have_gitlab_http_status(:no_content)
            expect(::Ci::RunnerController.find_by_id(controller_to_delete.id)).to be_nil
          end
        end

        context 'when controller has been modified since' do
          let(:headers) { { 'If-Unmodified-Since' => 1.day.ago.httpdate } }

          it 'returns precondition failed' do
            make_request

            expect(response).to have_gitlab_http_status(:precondition_failed)
            expect(::Ci::RunnerController.find_by_id(controller_to_delete.id)).to be_present
          end
        end
      end

      context 'when runner controller does not exist' do
        let(:controller_id) { non_existing_record_id }

        it 'returns status 404 (not found)' do
          make_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not admin' do
      let(:user) { non_admin_user }
      let(:admin_mode) { false }

      it 'returns status 403 (forbidden)' do
        make_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      subject(:call_endpoint) { make_request }

      it_behaves_like 'returns status 404 (not found)'
    end
  end
end

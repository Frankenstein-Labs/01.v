# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::RunnerControllerScopes, :aggregate_failures, feature_category: :continuous_integration do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be_with_refind(:controller) { create(:ci_runner_controller) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }
  let_it_be(:project) { create(:project) }
  let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }

  before do
    stub_licensed_features(ci_runner_controllers: true)
  end

  shared_examples 'returns status 404 (not found)' do
    it 'returns not found status' do
      perform_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'returns status 403 (forbidden)' do
    it 'returns forbidden status' do
      perform_request

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /runner_controllers/:id/scopes' do
    subject(:perform_request) { get api(path, current_user, admin_mode: admin_mode) }

    let(:path) { "/runner_controllers/#{controller.id}/scopes" }
    let(:current_user) { admin }
    let(:admin_mode) { true }

    it_behaves_like 'authorizing granular token permissions', :read_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api(path, personal_access_token: pat) }
    end

    context 'when user is admin' do
      context 'when no scopes exist' do
        it 'returns empty scopings arrays' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/runner_controller_scopes', dir: 'ee')
          expect(json_response['instance_level_scopings']).to eq([])
          expect(json_response['runner_level_scopings']).to eq([])
        end
      end

      context 'when instance-level scope exists' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: controller)
        end

        it 'returns the instance-level scoping' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/runner_controller_scopes', dir: 'ee')
          expect(json_response['instance_level_scopings'].size).to eq(1)
          expect(json_response['runner_level_scopings']).to eq([])
        end
      end

      context 'when runner-level scopes exist' do
        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: controller,
            runner: instance_runner)
        end

        it 'returns the runner-level scopings' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/runner_controller_scopes', dir: 'ee')
          expect(json_response['instance_level_scopings']).to eq([])
          expect(json_response['runner_level_scopings'].size).to eq(1)
          expect(json_response['runner_level_scopings'].first['runner_id']).to eq(instance_runner.id)
        end
      end

      context 'when runner controller does not exist' do
        let(:path) { "/runner_controllers/#{non_existing_record_id}/scopes" }

        it_behaves_like 'returns status 404 (not found)'
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }
      let(:admin_mode) { false }

      it_behaves_like 'returns status 403 (forbidden)'
    end

    context 'when feature is not available' do
      let(:current_user) { admin }
      let(:admin_mode) { true }

      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'POST /runner_controllers/:id/scopes/instance' do
    subject(:perform_request) { post api(path, current_user, admin_mode: admin_mode) }

    let(:path) { "/runner_controllers/#{controller.id}/scopes/instance" }
    let(:current_user) { admin }
    let(:admin_mode) { true }

    it_behaves_like 'authorizing granular token permissions', :update_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api(path, personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'creates an instance-level scope' do
        expect { perform_request }.to change { Ci::RunnerControllerInstanceLevelScoping.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/runner_controller_instance_level_scoping', dir: 'ee')
      end

      context 'when instance-level scope already exists' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: controller)
        end

        it 'returns status 409 (conflict)' do
          expect { perform_request }.not_to change { Ci::RunnerControllerInstanceLevelScoping.count }

          expect(response).to have_gitlab_http_status(:conflict)
        end
      end

      context 'when runner controller does not exist' do
        let(:path) { "/runner_controllers/#{non_existing_record_id}/scopes/instance" }

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when service returns an error' do
        before do
          allow_next_instance_of(Ci::RunnerControllers::Scopes::AddInstanceService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Some error', reason: :bad_request)
            )
          end
        end

        it 'returns status 400 (bad request)' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }
      let(:admin_mode) { false }

      it_behaves_like 'returns status 403 (forbidden)'
    end

    context 'when feature is not available' do
      let(:current_user) { admin }
      let(:admin_mode) { true }

      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'DELETE /runner_controllers/:id/scopes/instance' do
    subject(:perform_request) { delete api(path, current_user, admin_mode: admin_mode) }

    let(:path) { "/runner_controllers/#{controller.id}/scopes/instance" }
    let(:current_user) { admin }
    let(:admin_mode) { true }

    it_behaves_like 'authorizing granular token permissions', :update_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { delete api(path, personal_access_token: pat) }
    end

    context 'when user is admin' do
      context 'when instance-level scope exists' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: controller)
        end

        it 'removes the instance-level scope' do
          expect { perform_request }.to change { Ci::RunnerControllerInstanceLevelScoping.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      context 'when no instance-level scope exists' do
        it 'returns status 204 (no content) - idempotent' do
          expect { perform_request }.not_to change { Ci::RunnerControllerInstanceLevelScoping.count }

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      context 'when runner controller does not exist' do
        let(:path) { "/runner_controllers/#{non_existing_record_id}/scopes/instance" }

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when service returns an error' do
        before do
          allow_next_instance_of(Ci::RunnerControllers::Scopes::RemoveInstanceService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Some error', reason: :bad_request)
            )
          end
        end

        it 'returns status 400 (bad request)' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }
      let(:admin_mode) { false }

      it_behaves_like 'returns status 403 (forbidden)'
    end

    context 'when feature is not available' do
      let(:current_user) { admin }
      let(:admin_mode) { true }

      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'POST /runner_controllers/:id/scopes/runners/:runner_id' do
    subject(:perform_request) { post api(path, current_user, admin_mode: admin_mode) }

    let(:path) { "/runner_controllers/#{controller.id}/scopes/runners/#{instance_runner.id}" }
    let(:current_user) { admin }
    let(:admin_mode) { true }

    it_behaves_like 'authorizing granular token permissions', :update_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api(path, personal_access_token: pat) }
    end

    context 'when user is admin' do
      it 'creates a runner-level scope' do
        expect { perform_request }.to change { Ci::RunnerControllerRunnerLevelScoping.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/runner_controller_runner_level_scoping', dir: 'ee')
        expect(json_response['runner_id']).to eq(instance_runner.id)
      end

      context 'when runner is not instance-type' do
        let(:path) { "/runner_controllers/#{controller.id}/scopes/runners/#{project_runner.id}" }

        it 'returns status 422 (unprocessable entity)' do
          expect { perform_request }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when runner controller already has instance-level scope' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: controller)
        end

        it 'returns status 409 (conflict)' do
          expect { perform_request }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

          expect(response).to have_gitlab_http_status(:conflict)
        end
      end

      context 'when runner scope already exists' do
        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: controller,
            runner: instance_runner)
        end

        it 'returns status 409 (conflict)' do
          expect { perform_request }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

          expect(response).to have_gitlab_http_status(:conflict)
        end
      end

      context 'when runner controller does not exist' do
        let(:path) { "/runner_controllers/#{non_existing_record_id}/scopes/runners/#{instance_runner.id}" }

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when runner does not exist' do
        let(:path) { "/runner_controllers/#{controller.id}/scopes/runners/#{non_existing_record_id}" }

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when service returns an error' do
        before do
          allow_next_instance_of(Ci::RunnerControllers::Scopes::AddRunnerService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Some error', reason: :bad_request)
            )
          end
        end

        it 'returns status 400 (bad request)' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }
      let(:admin_mode) { false }

      it_behaves_like 'returns status 403 (forbidden)'
    end

    context 'when feature is not available' do
      let(:current_user) { admin }
      let(:admin_mode) { true }

      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      it_behaves_like 'returns status 404 (not found)'
    end
  end

  describe 'DELETE /runner_controllers/:id/scopes/runners/:runner_id' do
    subject(:perform_request) { delete api(path, current_user, admin_mode: admin_mode) }

    let(:path) { "/runner_controllers/#{controller.id}/scopes/runners/#{instance_runner.id}" }
    let(:current_user) { admin }
    let(:admin_mode) { true }

    it_behaves_like 'authorizing granular token permissions', :update_runner_controller do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { delete api(path, personal_access_token: pat) }
    end

    context 'when user is admin' do
      context 'when runner-level scope exists' do
        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: controller,
            runner: instance_runner)
        end

        it 'removes the runner-level scope' do
          expect { perform_request }.to change { Ci::RunnerControllerRunnerLevelScoping.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      context 'when no runner-level scope exists' do
        it 'returns status 204 (no content) - idempotent' do
          expect { perform_request }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      context 'when runner controller does not exist' do
        let(:path) { "/runner_controllers/#{non_existing_record_id}/scopes/runners/#{instance_runner.id}" }

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when runner does not exist' do
        let(:path) { "/runner_controllers/#{controller.id}/scopes/runners/#{non_existing_record_id}" }

        it_behaves_like 'returns status 404 (not found)'
      end

      context 'when service returns an error' do
        before do
          allow_next_instance_of(Ci::RunnerControllers::Scopes::RemoveRunnerService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Some error', reason: :bad_request)
            )
          end
        end

        it 'returns status 400 (bad request)' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }
      let(:admin_mode) { false }

      it_behaves_like 'returns status 403 (forbidden)'
    end

    context 'when feature is not available' do
      let(:current_user) { admin }
      let(:admin_mode) { true }

      before do
        stub_licensed_features(ci_runner_controllers: false)
      end

      it_behaves_like 'returns status 404 (not found)'
    end
  end
end

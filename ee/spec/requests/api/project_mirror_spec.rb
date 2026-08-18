# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectMirror, feature_category: :source_code_management do
  def project_member(project, role, user)
    create(:project_member, role, user: user, project: project)
  end

  describe 'POST /projects/:id/mirror/pull' do
    let_it_be(:user) { create(:user) }
    let(:visibility) { Gitlab::VisibilityLevel::PUBLIC }
    let(:project_mirrored) { create(:project, :repository, :mirror, visibility: visibility) }

    def do_post(user: nil, params: {}, headers: { 'X-Hub-Signature' => 'signature' })
      api_path = api("/projects/#{project_mirrored.id}/mirror/pull", user)

      post api_path, params: params, headers: headers
    end

    context 'when authenticated via GitHub signature' do
      before do
        Grape::Endpoint.before_each do |endpoint|
          allow(endpoint).to receive(:valid_github_signature?).and_return(true)
          allow(endpoint).to receive(:project).and_return(project_mirrored)
        end
      end

      after do
        Grape::Endpoint.before_each nil
      end

      context 'when project is not mirrored' do
        before do
          allow(project_mirrored).to receive(:mirror?).and_return(false)

          do_post
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when project is mirrored' do
        before do
          allow_next_instance_of(Projects::UpdateMirrorService) do |instance|
            allow(instance).to receive(:execute).and_return(status: :success)
          end
        end

        context 'when "pull_request" event is received' do
          let(:create_pipeline_service) { instance_double(Ci::CreatePipelineService) }
          let(:branch) { project_mirrored.repository.branches.first }
          let(:source_branch) { branch.name }
          let(:source_sha) { branch.target }
          let(:action) { 'opened' }
          let(:user) { project_mirrored.mirror_user }

          let(:params) do
            {
              pull_request: {
                number: 123,
                head: {
                  ref: source_branch,
                  sha: source_sha,
                  repo: { full_name: 'the-repo' }
                },
                base: {
                  ref: 'master',
                  sha: 'a09386439ca39abe575675ffd4b89ae824fec22f',
                  repo: { full_name: 'the-repo' }
                }
              },
              action: action
            }
          end

          let(:pipeline_params) do
            {
              ref: Gitlab::Git::BRANCH_REF_PREFIX + branch.name,
              source_sha: branch.target,
              target_sha: 'a09386439ca39abe575675ffd4b89ae824fec22f'
            }
          end

          before do
            stub_licensed_features(ci_cd_projects: true, github_integration: true)
          end

          subject(:send_request) { do_post(params: params) }

          shared_examples_for 'triggering pipeline creation' do
            it 'enqueues Ci::ExternalPullRequests::CreatePipelineWorker' do
              expect { send_request }
                .to change { ::Ci::ExternalPullRequest.count }.by(1)
                .and change { ::Ci::ExternalPullRequests::CreatePipelineWorker.jobs.count }.by(1)

              expect(response).to have_gitlab_http_status(:ok)

              args = ::Ci::ExternalPullRequests::CreatePipelineWorker.jobs.last['args']
              pull_request = ::Ci::ExternalPullRequest.last

              expect(args[0]).to eq(project_mirrored.id)
              expect(args[1]).to eq(user.id)
              expect(args[2]).to eq(pull_request.id)
            end
          end

          it_behaves_like 'triggering pipeline creation'

          context 'when any param is missing' do
            let(:source_sha) { nil }

            it 'returns the error message' do
              send_request

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end

          context 'when action is not supported' do
            let(:action) { 'assigned' }

            it 'ignores it and return success status' do
              expect(Ci::CreatePipelineService).not_to receive(:new)

              send_request

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end

          context 'when authenticated as user' do
            let_it_be(:user) { create(:user) }

            before do
              project_member(project_mirrored, :maintainer, user)
            end

            subject(:send_request) { do_post(params: params, user: user, headers: {}) }

            it_behaves_like 'triggering pipeline creation'
          end

          context 'when ci_cd_projects is not available' do
            before do
              stub_licensed_features(ci_cd_projects: false, github_integration: true)
            end

            it 'returns the error message' do
              send_request

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end

          context 'when github_integration is not available' do
            before do
              stub_licensed_features(github_integration: false, ci_cd_projects: true)
            end

            it 'returns the error message' do
              send_request

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when "push" event is received' do
          shared_examples_for 'an API endpoint that triggers pull mirroring operation' do
            it 'executes UpdateAllMirrorsWorker' do
              expect(project_mirrored.import_state).to receive(:force_import_job!).and_call_original
              expect(UpdateAllMirrorsWorker).to receive(:perform_async).once

              do_post

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          shared_examples_for 'an API endpoint that does not trigger pull mirroring operation' do |status_code|
            it "does not execute UpdateAllMirrorsWorker and returns #{status_code}" do
              expect(UpdateAllMirrorsWorker).not_to receive(:perform_async)
              do_post

              expect(response).to have_gitlab_http_status(status_code)
            end
          end

          shared_examples_for 'force-triggers a pull mirror update' do
            it 'starts mirroring without pausing on hard failure', :aggregate_failures do
              expect(StartPullMirroringService).to receive(:new)
                .with(project_mirrored, user, pause_on_hard_failure: false)
                .and_call_original

              Sidekiq::Testing.fake! do
                expect { do_post(user: user, params: { force: true }, headers: {}) }
                  .to change { UpdateAllMirrorsWorker.jobs.size }
                  .by(1)
              end

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          let(:state) { :none }

          before do
            project_mirrored
              .import_state
              .update!(status: state, next_execution_timestamp: 10.minutes.from_now)
          end

          context 'when import state is none' do
            it_behaves_like 'an API endpoint that triggers pull mirroring operation'

            context 'when authenticated as a maintainer' do
              before do
                project_member(project_mirrored, :maintainer, user)
              end

              it_behaves_like 'force-triggers a pull mirror update'
            end
          end

          context 'when import state is failed' do
            let(:state) { :failed }

            it_behaves_like 'an API endpoint that triggers pull mirroring operation'

            context "and retried more than #{Gitlab::Mirror::MAX_RETRY} times" do
              before do
                project_mirrored
                  .import_state
                  .update!(retry_count: Gitlab::Mirror::MAX_RETRY + 1)
              end

              it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :forbidden

              it 'ignores force when authenticated via GitHub signature', :aggregate_failures do
                expect(StartPullMirroringService).to receive(:new)
                  .with(project_mirrored, anything, pause_on_hard_failure: true)
                  .and_call_original
                expect(UpdateAllMirrorsWorker).not_to receive(:perform_async)

                do_post(params: { force: true })

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(project_mirrored.import_state.reload.retry_count).to eq(Gitlab::Mirror::MAX_RETRY + 1)
              end

              context 'when authenticated as a maintainer' do
                before do
                  project_member(project_mirrored, :maintainer, user)
                end

                it_behaves_like 'force-triggers a pull mirror update'

                it 'resets the retry_count for a hard-failed mirror', :aggregate_failures do
                  Sidekiq::Testing.fake! do
                    do_post(user: user, params: { force: true }, headers: {})
                  end

                  expect(project_mirrored.import_state.reload.retry_count).to eq(0)
                end

                it 'keeps hard-failed mirrors paused without force', :aggregate_failures do
                  expect(StartPullMirroringService).to receive(:new)
                    .with(project_mirrored, user, pause_on_hard_failure: true)
                    .and_call_original
                  expect(UpdateAllMirrorsWorker).not_to receive(:perform_async)

                  do_post(user: user, headers: {})

                  expect(response).to have_gitlab_http_status(:forbidden)
                  expect(project_mirrored.import_state.reload.retry_count).to eq(Gitlab::Mirror::MAX_RETRY + 1)
                end
              end
            end
          end

          context 'when import state is finished' do
            let(:state) { :finished }

            it_behaves_like 'an API endpoint that triggers pull mirroring operation'
          end

          context 'when import state is scheduled' do
            let(:state) { :scheduled }

            it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :ok
          end

          context 'when import state is started' do
            let(:state) { :started }

            it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :ok
          end

          context 'when authenticated as user' do
            let(:user) { create(:user) }

            context 'is authenticated as developer' do
              it 'returns forbidden error' do
                project_member(project_mirrored, :developer, user)

                do_post(user: user, headers: {})

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'is authenticated as reporter' do
              it 'returns forbidden error' do
                project_member(project_mirrored, :reporter, user)

                do_post(user: user, headers: {})

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'is authenticated as guest' do
              it 'returns forbidden error' do
                project_member(project_mirrored, :guest, user)

                do_post(user: user, headers: {})

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'is authenticated as maintainer' do
              it 'triggers the pull mirroring operation' do
                project_member(project_mirrored, :maintainer, user)

                Sidekiq::Testing.fake! do
                  expect { do_post(user: user, headers: {}) }
                    .to change { UpdateAllMirrorsWorker.jobs.size }
                    .by(1)

                  expect(response).to have_gitlab_http_status(:ok)
                end
              end
            end

            context 'is authenticated as owner' do
              it 'triggers the pull mirroring operation' do
                Sidekiq::Testing.fake! do
                  expect { do_post(user: project_mirrored.creator, headers: {}) }
                    .to change { UpdateAllMirrorsWorker.jobs.size }
                    .by(1)

                  expect(response).to have_gitlab_http_status(:ok)
                end
              end
            end
          end

          context 'when repository_mirrors feature is not available' do
            before do
              stub_licensed_features(repository_mirrors: false)
            end

            it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :bad_request
          end

          context 'when repository_mirrors feature is available' do
            before do
              stub_licensed_features(repository_mirrors: true)
            end

            it_behaves_like 'an API endpoint that triggers pull mirroring operation'
          end
        end
      end
    end

    context 'when attempting to authenticate via GitHub signature' do
      before do
        Grape::Endpoint.before_each do |endpoint|
          allow(endpoint).to receive(:project).and_return(project_mirrored)
        end

        allow(project_mirrored).to receive(:external_webhook_token).and_return(external_webhook_token)
      end

      after do
        Grape::Endpoint.before_each nil
      end

      subject(:request) do
        params = { action: 'opened' }
        spoofed_signature = "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), '', 'action=opened')}"

        do_post(params: params, headers: { 'X-Hub-Signature' => spoofed_signature })
      end

      context 'without a project.external_webhook_token' do
        let(:external_webhook_token) { nil }

        it 'returns a 401 status' do
          request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'with a project.external_webhook_token' do
        let(:external_webhook_token) { 'a-fake-token' }

        it 'returns a 401 status' do
          request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end

    context 'when not authenticated' do
      before do
        Grape::Endpoint.before_each do |endpoint|
          allow(endpoint).to receive(:valid_github_signature?).and_return(false)
        end
      end

      after do
        Grape::Endpoint.before_each nil
      end

      context 'with public project' do
        let(:visibility) { Gitlab::VisibilityLevel::PUBLIC }

        it 'returns a 401 status' do
          do_post

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'with internal project' do
        let(:visibility) { Gitlab::VisibilityLevel::INTERNAL }

        it 'returns a 404 status' do
          do_post

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with private project' do
        let(:visibility) { Gitlab::VisibilityLevel::PRIVATE }

        it 'returns a 404 status' do
          do_post

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_pull_mirror do
      let(:boundary_object) { project_mirrored }
      let(:request) do
        post api("/projects/#{project_mirrored.id}/mirror/pull", personal_access_token: pat)
      end

      before do
        project_member(project_mirrored, :maintainer, user)
      end
    end
  end

  describe 'GET /projects/:id/mirror/pull' do
    let_it_be(:project) { create(:project, :repository, :mirror) }
    let_it_be(:user) { create(:user) }

    let(:route) { "/projects/#{project.id}/mirror/pull" }

    context 'when user is missing' do
      it 'returns Unauthorized' do
        get api(route, nil)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user has no admin permissions' do
      before do
        project.add_developer(user)
      end

      it 'returns forbidden error' do
        get api(route, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when user has admin permissions' do
      before do
        project.add_maintainer(user)
      end

      it 'returns pull mirror details' do
        get api(route, user)

        expect(response).to have_gitlab_http_status(:success)
        expect(response).to match_response_schema('project_mirror')
      end

      context 'when project does not support mirroring' do
        let_it_be(:project) { create(:project, :repository, :with_import_url) }

        it 'returns BadRequest' do
          get api(route, user)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_pull_mirror do
      let(:boundary_object) { project }
      let(:request) { get api(route, personal_access_token: pat) }

      before do
        project_member(project, :maintainer, user)
      end
    end
  end

  describe 'PUT /projects/:id/mirror/pull' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository, :mirror) }

    let(:route) { "/projects/#{project.id}/mirror/pull" }
    let(:request) { put api(route, current_user), params: params }
    let(:current_user) { user }
    let(:params) { { enabled: true, url: mirror_url } }
    let(:mirror_url) { 'http://example.com' }

    shared_examples 'pull mirror configuration' do
      before do
        allow_next_instance_of(Import::ValidateRemoteGitEndpointService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end

      context 'when user is missing' do
        let(:current_user) { nil }

        it 'returns Unauthorized' do
          request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'when user has no admin permissions' do
        before do
          project.add_developer(user)
        end

        it 'returns forbidden error' do
          request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when user has admin permissions' do
        before do
          project.add_maintainer(user)
        end

        it 'returns pull mirror details' do
          request

          expect(response).to have_gitlab_http_status(:success)
          expect(response).to match_response_schema('project_mirror')
        end

        context 'when pull mirroring is not available' do
          before do
            stub_ee_application_setting(mirror_available: false)
          end

          it 'does not allow to update pull mirror' do
            request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when mirror url is not a valid URL' do
          let(:mirror_url) { 'wrong' }

          it 'does not allow to update pull mirror' do
            request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['unsafe_import_url']).to eq(
              ['is blocked: Only allowed schemes are http, https, ssh, git']
            )
          end
        end

        context 'when allowed parameters are provided' do
          let(:params) do
            {
              url: mirror_url,
              enabled: false,
              mirror_trigger_builds: true,
              only_mirror_protected_branches: true,
              mirror_overwrites_diverged_branches: true
            }
          end

          it 'updates a pull mirror' do
            request

            expect(response).to have_gitlab_http_status(:success)
            expect(response).to match_response_schema('project_mirror')

            expect(json_response).to include(
              'enabled' => false,
              'url' => 'http://example.com',
              'mirror_trigger_builds' => true,
              'only_mirror_protected_branches' => true,
              'mirror_overwrites_diverged_branches' => true
            )
          end

          context 'when user and password include special characters' do
            let(:params) do
              {
                url: mirror_url,
                auth_user: auth_user,
                auth_password: auth_password
              }
            end

            let(:auth_user) { 'u$/ser' }
            let(:auth_password) { 'pa$$w/o/rd' }

            it 'updates a pull mirror credentials' do
              request

              expect(response).to have_gitlab_http_status(:success)
              expect(json_response['url']).to eq('http://*****:*****@example.com')

              updated_project = project.reload
              expect(updated_project.import_data.reload.credentials).to eq(user: auth_user, password: auth_password)
              expect(updated_project.import_data.auth_method).to eq('password')
            end
          end

          context 'without parameters' do
            let(:params) { {} }

            it 'returns 400 response' do
              request

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end
        end
      end
    end

    context 'when project does not have a configured pull mirror' do
      let_it_be(:project) { create(:project, :repository) }

      it_behaves_like 'pull mirror configuration'
    end

    context 'when project already has a configured pull mirror' do
      let_it_be(:project) { create(:project, :repository, :mirror) }

      it_behaves_like 'pull mirror configuration'

      context 'when only new user and password were provided' do
        before do
          project.add_maintainer(user)

          project.build_or_assign_import_data(credentials: old_credentials)
          project.import_data.save!
        end

        let(:old_credentials) { { user: 'user', password: 'pass' } }

        let(:params) do
          {
            auth_user: auth_user,
            auth_password: auth_password
          }
        end

        let(:auth_user) { 'new_user' }
        let(:auth_password) { 'new_user' }

        it 'changes previous pull mirror credentials' do
          expect(project.import_data.reload.credentials).to eq(old_credentials)

          request

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response['url']).to include('http://*****:*****@')

          updated_project = project.reload
          expect(updated_project.import_data.reload.credentials).to eq(user: auth_user, password: auth_password)
          expect(updated_project.import_data.auth_method).to eq('password')
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :update_pull_mirror do
      let(:boundary_object) { project }
      let(:request) do
        put api(route, personal_access_token: pat), params: params
      end

      before do
        project_member(project, :maintainer, user)

        allow_next_instance_of(Import::ValidateRemoteGitEndpointService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end
    end
  end
end

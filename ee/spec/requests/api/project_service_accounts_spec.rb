# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectServiceAccounts, :with_current_organization, :aggregate_failures,
  :clean_gitlab_redis_rate_limiting, feature_category: :user_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project) }
  let_it_be_with_reload(:service_account_user) { create(:service_account, provisioned_by_project: project) }
  let_it_be_with_reload(:service_account_user2) { create(:service_account, provisioned_by_project: project) }
  let_it_be(:other_service_account) { create(:service_account, provisioned_by_project: other_project) }
  let_it_be(:regular_user) { create(:user, provisioned_by_project: project) }

  let(:project_id) { project.id }
  let(:current_user) { user }
  let(:params) { {} }

  before do
    stub_application_setting_enum('email_confirmation_setting', 'hard')
    allow(License).to receive(:current).and_return(build(:license, plan: License::ULTIMATE_PLAN))
  end

  shared_examples 'service account user creation' do
    let(:username_prefix) { "service_account_project_#{project_id}" }

    context 'when the project exists' do
      it 'creates service account user with default values and correct attributes' do
        perform_request

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['username']).to start_with(username_prefix)
        expect(json_response['name']).to eq('Service account user')
        expect(json_response['email']).to start_with(username_prefix)
        expect(json_response.keys).to match_array(%w[id name username email public_email])

        created_user = User.find(json_response['id'])
        expect(created_user.namespace.organization).to eq(current_organization)
        expect(created_user.user_type).to eq('service_account')
        expect(created_user).to be_confirmed
      end

      context 'when custom params are provided' do
        let(:params) do
          {
            name: 'John Doe',
            username: 'test_project_sa',
            email: 'test_project_service_account@example.com'
          }
        end

        it 'creates service account user with provided details' do
          perform_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['username']).to eq(params[:username])
          expect(json_response['name']).to eq(params[:name])
          expect(json_response['email']).to eq(params[:email])
          expect(json_response.keys).to match_array(%w[id name username email public_email])

          created_user = User.find(json_response['id'])
          expect(created_user.namespace.organization).to eq(current_organization)
          expect(created_user.user_type).to eq('service_account')
          expect(created_user).not_to be_confirmed
        end

        context 'when user with the username and email already exists' do
          before do
            post api("/projects/#{project_id}/service_accounts", current_user), params: params
          end

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('Username has already been taken')
            expect(json_response['message']).to include('Email has already been taken')
          end
        end
      end

      it 'returns bad request when service returns bad request' do
        allow_next_instance_of(::Namespaces::ServiceAccounts::ProjectCreateService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Some error', reason: :bad_request)
          )
        end

        perform_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when the project does not exist' do
      it 'returns error' do
        post api("/projects/#{non_existing_record_id}/service_accounts", current_user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'service account user update' do
    context 'when the project exists' do
      it 'updates the service account user' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to match_array(%w[id name username email public_email])
        expect(json_response['name']).to eq(params[:name])
        expect(json_response['username']).to eq(params[:username])
      end

      context 'when email is provided' do
        let(:params) { { email: 'test@test.com' } }
        let(:mailer_double) { instance_double(ActionMailer::MessageDelivery) }

        before do
          allow(Devise::Mailer).to receive(:confirmation_instructions).and_return(mailer_double)
          allow(mailer_double).to receive(:deliver_later)
        end

        it 'only updates the unconfirmed email' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.keys).to match_array(%w[id name username email public_email unconfirmed_email])
          expect(json_response['unconfirmed_email']).to eq('test@test.com')
          expect(json_response['email']).not_to eq('test@test.com')
        end

        it 'sends a confirmation email' do
          expect(mailer_double).to receive(:deliver_later)

          perform_request
        end
      end

      context 'when user with the username already exists' do
        let(:existing_user) { create(:user, username: 'existing_user') }
        let(:params) { { username: existing_user.username } }

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include('Username has already been taken')
        end
      end

      it 'returns 404 for non-existing user' do
        patch api("/projects/#{project_id}/service_accounts/#{non_existing_record_id}", current_user),
          params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it 'returns a 400 for invalid user ID' do
        patch api("/projects/#{project_id}/service_accounts/ASDF", current_user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'when target user is not a service account' do
        it 'returns not found error' do
          patch api("/projects/#{project_id}/service_accounts/#{regular_user.id}", current_user),
            params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end
    end

    context 'when the project does not exist' do
      it 'returns error' do
        patch api("/projects/#{non_existing_record_id}/service_accounts/#{service_account_user.id}", current_user),
          params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to include('404 Project Not Found')
      end
    end
  end

  shared_examples 'forbidden for non-owner/maintainer' do
    it 'returns forbidden error' do
      perform_request

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  shared_examples 'service account list endpoint' do
    it 'returns 200 status and service account users list' do
      perform_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/user/safes')
      expect(json_response.size).to eq(2)
      expect(json_response.pluck('id')).not_to include(regular_user.id)
    end

    context 'when order by is specified' do
      let(:params) { { order_by: 'username' } }

      before do
        service_account_user.update!(username: 'Auser')
        service_account_user2.update!(username: 'Buser')
      end

      it 'returns ordered list by username in desc order' do
        perform_request

        expect(response).to match_response_schema('public_api/v4/user/safes')
        expect(json_response.size).to eq(2)
        expect_paginated_array_response(service_account_user2.id, service_account_user.id)
      end

      context 'when sort order is specified' do
        let(:params) { { order_by: 'username', sort: 'asc' } }

        it 'follows sorting order' do
          perform_request

          expect(response).to match_response_schema('public_api/v4/user/safes')
          expect(json_response.size).to eq(2)
          expect_paginated_array_response(service_account_user.id, service_account_user2.id)
        end
      end

      context 'when invalid order_by is specified' do
        it 'does not order by any other column than username and id' do
          get api("/projects/#{project_id}/service_accounts", user), params: { order_by: 'name' }

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end

  describe 'POST /projects/:id/service_accounts' do
    subject(:perform_request) { post api("/projects/#{project_id}/service_accounts", current_user), params: params }

    context 'when current user is a project owner' do
      before_all do
        project.add_owner(user)
      end

      it_behaves_like 'service account user creation'
    end

    context 'when current user is a project maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      it_behaves_like 'service account user creation'
    end

    context 'when current user is a project developer' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'forbidden for non-owner/maintainer'
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post api("/projects/#{project_id}/service_accounts"), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'for rate limiting' do
      let_it_be(:user2) { create(:user) }

      let(:current_user) { user }

      before_all do
        project.add_owner(user)
        project.add_owner(user2)
      end

      def request
        post api("/projects/#{project.id}/service_accounts", user), params: params
      end

      def request_with_second_scope
        post api("/projects/#{project.id}/service_accounts", user2), params: params
      end

      it_behaves_like 'rate limited endpoint', rate_limit_key: :service_account_creation
    end
  end

  describe 'GET /projects/:id/service_accounts' do
    subject(:perform_request) { get api("/projects/#{project_id}/service_accounts", current_user), params: params }

    context 'when request is correct' do
      before_all do
        project.add_owner(user)
      end

      it_behaves_like 'service account list endpoint'

      it_behaves_like 'an endpoint with keyset pagination', invalid_order: nil do
        let(:first_record) { [service_account_user, service_account_user2].max_by(&:id) }
        let(:second_record) { [service_account_user, service_account_user2].min_by(&:id) }
        let(:api_call) { api("/projects/#{project_id}/service_accounts", current_user) }
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'returns not found error' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not project owner or maintainer' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'forbidden for non-owner/maintainer'
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get api("/projects/#{project_id}/service_accounts")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /projects/:id/service_accounts/:user_id' do
    subject(:perform_request) do
      patch api("/projects/#{project_id}/service_accounts/#{service_account_user.id}", current_user), params: params
    end

    let(:params) { { name: 'Updated Name', username: 'updated_username' } }

    context 'when current user is a project owner' do
      before_all do
        project.add_owner(user)
      end

      it_behaves_like 'service account user update'

      context 'when service account does not belong to this project' do
        it 'returns not found error' do
          patch api("/projects/#{project_id}/service_accounts/#{other_service_account.id}", current_user),
            params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end
    end

    context 'when current user is a project maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      it_behaves_like 'service account user update'
    end

    context 'when current user is not a project owner or maintainer' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'forbidden for non-owner/maintainer'
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        patch api("/projects/#{project_id}/service_accounts/#{service_account_user.id}"), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /projects/:id/service_accounts/:user_id' do
    let(:issue) { create(:issue, author: service_account_user) }
    let(:path) { "/projects/#{project_id}/service_accounts/#{service_account_user.id}" }

    context 'when service account does not belong to this project' do
      it 'returns not found error' do
        perform_enqueued_jobs do
          delete api("/projects/#{project_id}/service_accounts/#{other_service_account.id}", admin, admin_mode: true)
        end

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 User Not Found')
      end
    end

    context 'when target user is not a service account' do
      it 'returns not found error' do
        perform_enqueued_jobs do
          delete api("/projects/#{project_id}/service_accounts/#{regular_user.id}", admin, admin_mode: true)
        end

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 User Not Found')
      end
    end

    it 'is available for project owners', :sidekiq_inline do
      project.add_owner(user)

      perform_enqueued_jobs { delete api(path, user) }

      expect(response).to have_gitlab_http_status(:no_content)
      expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: user)).to exist
    end

    it 'is available for project maintainers', :sidekiq_inline do
      project.add_maintainer(user)

      perform_enqueued_jobs { delete api(path, user) }

      expect(response).to have_gitlab_http_status(:no_content)
      expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: user)).to exist
    end

    it 'is not available to non project owners/maintainers' do
      project.add_developer(user)

      perform_enqueued_jobs { delete api(path, user) }

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /projects/:id/service_accounts/:user_id/personal_access_tokens' do
    let(:target_user_id) { service_account_user.id }
    let(:path) { "/projects/#{project_id}/service_accounts/#{target_user_id}/personal_access_tokens" }
    let(:params) { nil }

    subject(:perform_request) { get(api(path, current_user), params: params) }

    context 'when the user is a project owner' do
      before_all do
        project.add_owner(user)
      end

      context 'when the service_account is provisioned_by the project' do
        let_it_be(:active_token1) { create(:personal_access_token, user: service_account_user) }
        let_it_be(:active_token2) { create(:personal_access_token, user: service_account_user) }

        it 'returns the personal access tokens' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(2)
        end

        context 'when filtering by state' do
          let!(:revoked_token) { create(:personal_access_token, user: service_account_user, revoked: true) }
          let(:params) { { state: 'inactive' } }

          it 'returns only inactive tokens' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.size).to eq(1)
            expect(json_response.first['revoked']).to be_truthy
          end
        end
      end

      context 'when the service_account does not belong to the project' do
        let(:target_user_id) { other_service_account.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end

      context 'when the target_user is not a service account' do
        let(:target_user_id) { regular_user.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'returns not found' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not a project owner or maintainer' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'forbidden for non-owner/maintainer'
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get api(path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/service_accounts/:user_id/personal_access_tokens' do
    let(:name) { 'new pat' }
    let(:description) { 'description' }
    let(:expires_at) { 3.days.from_now }
    let(:scopes) { %w[api read_user] }
    let(:params) { { name: name, description: description, expires_at: expires_at, scopes: scopes } }
    let(:path) { "/projects/#{project_id}/service_accounts/#{service_account_user.id}/personal_access_tokens" }

    subject(:perform_request) { post(api(path, current_user), params: params) }

    context 'when user is a project owner' do
      before_all do
        project.add_owner(user)
      end

      it 'creates personal access token for the service account' do
        perform_request

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['name']).to eq(name)
        expect(json_response['description']).to eq(description)
        expect(json_response['scopes']).to eq(scopes)
        expect(json_response['expires_at']).to eq(expires_at.to_date.iso8601)
        expect(json_response['id']).to be_present
        expect(json_response['created_at']).to be_present
        expect(json_response['active']).to be_truthy
        expect(json_response['revoked']).to be_falsey
        expect(json_response['token']).to be_present
      end

      it 'passes creation_source api to the service' do
        expect(::PersonalAccessTokens::CreateService).to receive(:new)
          .with(hash_including(params: hash_including(
            creation_source: PersonalAccessToken::CREATION_SOURCE_API
          )))
          .and_call_original

        perform_request
      end

      context 'when an error is thrown by the service' do
        let(:error_message) { 'error message' }

        before do
          allow_next_instance_of(::PersonalAccessTokens::CreateService) do |create_service|
            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.error(message: error_message)
            )
          end
        end

        it 'returns the error' do
          perform_request

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq(error_message)
        end
      end

      context 'when service account does not belong to the project' do
        let(:path) { "/projects/#{project_id}/service_accounts/#{other_service_account.id}/personal_access_tokens" }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end

      context 'when target user is not a service account' do
        let(:path) { "/projects/#{project_id}/service_accounts/#{regular_user.id}/personal_access_tokens" }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end
    end

    context 'when user is a project maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      it 'creates personal access token for the service account' do
        perform_request

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['token']).to be_present
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'returns not found' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not a project owner or maintainer' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'forbidden for non-owner/maintainer'
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post api(path), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /projects/:id/service_accounts/:user_id/personal_access_tokens/:token_id' do
    let_it_be(:token) { create(:personal_access_token, user: service_account_user) }

    let(:user_id) { service_account_user.id }
    let(:token_id) { token.id }
    let(:request_path) { "/projects/#{project_id}/service_accounts/#{user_id}/personal_access_tokens/#{token_id}" }

    subject(:perform_request) { delete(api(request_path, current_user)) }

    shared_examples 'successful token revocation' do
      it 'revokes the token' do
        perform_request

        expect(response).to have_gitlab_http_status(:no_content)
        expect(token.reload.revoked?).to be_truthy
      end
    end

    context 'when user is a project owner' do
      before_all do
        project.add_owner(user)
      end

      context 'when all parameters are valid' do
        it_behaves_like 'successful token revocation'
      end

      context 'when the revocation service fails' do
        let(:error_message) { 'error message' }

        before do
          allow_next_instance_of(::PersonalAccessTokens::RevokeService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: error_message)
            )
          end
        end

        it 'returns the error message' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('400 Bad request - error message')
        end
      end

      context 'when the token does not exist' do
        let(:token_id) { non_existing_record_id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Personal Access Token Not Found')
        end
      end

      context 'when the token does not belong to the service account' do
        let(:other_user) { create(:user) }
        let(:other_token) { create(:personal_access_token, user: other_user) }
        let(:token_id) { other_token.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Personal Access Token Not Found')
        end
      end

      context 'when the service account does not belong to the project' do
        let(:user_id) { other_service_account.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end

      context 'when target user is not a service account' do
        let(:user_id) { regular_user.id }
        let(:regular_token) { create(:personal_access_token, user: regular_user) }
        let(:token_id) { regular_token.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end
    end

    context 'when user is a project maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      it_behaves_like 'successful token revocation'
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'returns not found' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not a project owner or maintainer' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'forbidden for non-owner/maintainer'
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        delete api(request_path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /projects/:id/service_accounts/:user_id/personal_access_tokens/:token_id/rotate' do
    let!(:token) { create(:personal_access_token, user: service_account_user) }

    let(:user_id) { service_account_user.id }
    let(:token_id) { token.id }
    let(:params) { nil }
    let(:path) { "/projects/#{project_id}/service_accounts/#{user_id}/personal_access_tokens/#{token_id}/rotate" }

    subject(:perform_request) { post(api(path, current_user), params: params) }

    context 'when user is a project owner' do
      before_all do
        project.add_owner(user)
      end

      it 'rotates the token' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(token.reload.revoked?).to be_truthy
        expect(json_response['token']).not_to eq(token.token)
        expect(json_response['expires_at']).to eq(1.week.from_now.to_date.iso8601)
      end

      context 'when expiry is defined' do
        let(:expiry_date) { 1.month.from_now }
        let(:params) { { expires_at: expiry_date } }

        it 'allows owner to rotate token with custom expiry', :freeze_time do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(token.reload.revoked?).to be_truthy
          expect(json_response['token']).not_to eq(token.token)
          expect(json_response['expires_at']).to eq(expiry_date.to_date.iso8601)
        end
      end

      it 'passes creation_source api to the service' do
        expect(::PersonalAccessTokens::RotateService).to receive(:new)
          .with(anything, anything, anything, hash_including(creation_source: PersonalAccessToken::CREATION_SOURCE_API))
          .and_call_original

        perform_request
      end

      context 'when the token is already revoked' do
        before do
          token.revoke!
        end

        it 'returns bad request error' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('400 Bad request - Token already revoked')
        end
      end

      context 'when token does not exist' do
        let(:token_id) { non_existing_record_id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when token does not belong to the service account' do
        let(:other_user) { create(:user) }
        let(:other_token) { create(:personal_access_token, user: other_user) }
        let(:token_id) { other_token.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when service account does not belong to the project' do
        let(:user_id) { other_service_account.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end

      context 'when target user is not a service account' do
        let(:user_id) { regular_user.id }
        let(:regular_token) { create(:personal_access_token, user: regular_user) }
        let(:token_id) { regular_token.id }

        it 'returns not found' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 User Not Found')
        end
      end
    end

    context 'when user is a project maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      it 'rotates the token' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['token']).to be_present
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'returns not found' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not a project owner or maintainer' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'forbidden for non-owner/maintainer'
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post api(path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end
end

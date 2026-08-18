# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupServiceAccounts, :with_current_organization, :aggregate_failures,
  :clean_gitlab_redis_rate_limiting, feature_category: :user_management do
  include Auth::DpopTokenHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let(:current_user) { create(:user) }
  let(:group) { create(:group) }
  let(:subgroup) { create(:group, :private, parent: group) }

  let_it_be_with_reload(:service_account_user) { create(:user, :service_account) }

  before do
    stub_application_setting_enum('email_confirmation_setting', 'hard')

    service_account_user.provisioned_by_group_id = group.id
    service_account_user.save!
  end

  RSpec.shared_examples "service account user creation" do
    context 'when the group exists' do
      let(:group_id) { group.id }

      it "creates user and responds with the default values" do
        perform_request

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['username']).to start_with("service_account_group_#{group_id}")
        expect(json_response['name']).to eq('Service account user')
        expect(json_response['email']).to start_with("service_account_group_#{group_id}")
        expect(json_response.keys).to match_array(%w[id name username email public_email])
      end

      it 'creates the user with the correct attributes' do
        perform_request

        user = User.find(json_response['id'])

        expect(user.namespace.organization).to eq(current_organization)
        expect(user.user_type).to eq('service_account')
        expect(user).to be_confirmed
      end

      context 'when params are provided' do
        let_it_be(:params) do
          {
            name: 'John Doe',
            username: 'test',
            email: 'test_service_account@example.com'
          }
        end

        it "creates user with provided details" do
          perform_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['username']).to eq(params[:username])
          expect(json_response['name']).to eq(params[:name])
          expect(json_response['email']).to eq(params[:email])
          expect(json_response.keys).to match_array(%w[id name username email public_email])
        end

        it 'creates the user with the correct attributes' do
          perform_request

          user = User.find(json_response['id'])

          expect(user.namespace.organization).to eq(current_organization)
          expect(user.user_type).to eq('service_account')
          expect(user).not_to be_confirmed
        end

        context 'when user with the username and email already exists' do
          before do
            post api("/groups/#{group_id}/service_accounts", user), params: params
          end

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include('Username has already been taken')
            expect(json_response['message']).to include('Email has already been taken')
          end
        end

        context 'when the group does not exist' do
          let(:group_id) { non_existing_record_id }

          it "returns error" do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      it "returns bad request when service returns bad request" do
        allow_next_instance_of(::Namespaces::ServiceAccounts::GroupCreateService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: message, reason: :bad_request)
          )
        end

        perform_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'for subgroup' do
        let(:group_id) { subgroup.id }

        it 'creates the user with the correct attributes' do
          perform_request

          user = User.find(json_response['id'])

          expect(user.namespace.organization).to eq(current_organization)
          expect(user.user_type).to eq('service_account')
          expect(user.provisioned_by_group_id).to eq(group_id)
          expect(user).to be_confirmed
        end
      end
    end

    context 'when the group does not exist' do
      let(:group_id) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  RSpec.shared_examples "service account user update" do
    context 'when the group exists' do
      let(:group_id) { group.id }

      it 'updates the service account user' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to match_array(%w[id name username email public_email])
        expect(json_response['name']).to eq(params[:name])
        expect(json_response['username']).to eq(params[:username])
      end

      context 'when email is provided' do
        before do
          allow(Devise::Mailer).to receive(:confirmation_instructions).and_return(mailer_double)
          allow(mailer_double).to receive(:deliver_later)
        end

        let(:params) { { email: 'test@test.com' } }
        let(:mailer_double) { instance_double(ActionMailer::MessageDelivery) }

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

      it "returns 404 for non-existing user" do
        patch api("/groups/#{group_id}/service_accounts/#{non_existing_record_id}", user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it "returns a 400 for invalid user ID" do
        patch api("/groups/#{group_id}/service_accounts/ASDF", user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      context 'when target user is not a service account' do
        let(:regular_user) { create(:user, provisioned_by_group: group) }

        it 'returns bad request error' do
          patch api("/groups/#{group_id}/service_accounts/#{regular_user.id}", user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include('User is not of type Service Account')
        end
      end

      context 'with an enforced composite_identity' do
        let(:service_account_user) do
          create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: group)
        end

        context 'when attempting to update the username' do
          let(:params) { super().merge(username: "service_account_#{SecureRandom.hex(8)}") }

          it 'returns a 400 error' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to include(
              'You cannot update the username of a service account associated with a composite identity.'
            )
          end
        end

        context 'when updating other fields' do
          let(:params) { super().except(:username) }

          it 'updates the service account' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['name']).to eq(params[:name])
            expect(json_response['email']).to eq(params[:email]) if params[:email]
          end
        end
      end
    end

    context 'when the group does not exist' do
      let(:group_id) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to include('404 Group Not Found')
      end
    end
  end

  describe "POST /groups/:id/service_accounts" do
    subject(:perform_request) { post api("/groups/#{group_id}/service_accounts", user), params: params }

    let_it_be(:params) { {} }

    context 'when current user is a group owner' do
      let_it_be(:user) { create(:user) }

      before do
        group.add_owner(user)
      end

      context 'when group is identified by URL-encoded path' do
        let(:group_id) { group.full_path }

        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        end

        it 'creates the service account user' do
          perform_request

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when allow top level setting is activated' do
        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        end

        it_behaves_like "service account user creation"

        context 'when in GitLab.com', :saas do
          let(:hosted_plan) { create(:ultimate_plan) }

          before do
            create(:gitlab_subscription, namespace: group, hosted_plan: hosted_plan)
            stub_application_setting(check_namespace_plan: true)
          end

          it_behaves_like "service account user creation"

          context 'when group has a verified domain' do
            let(:group_id) { group.id }
            let_it_be(:params) do
              {
                name: 'John Doe',
                username: 'test',
                email: 'test_service_account@example.com'
              }
            end

            before do
              stub_licensed_features(domain_verification: true)
              project = create(:project, group: group)
              create(:pages_domain, project: project, domain: 'example.com')
            end

            it 'creates a confirmed user' do
              perform_request

              user = User.find(json_response['id'])

              expect(user.namespace.organization).to eq(current_organization)
              expect(user.user_type).to eq('service_account')
              expect(user.email).to eq('test_service_account@example.com')
              expect(user).to be_confirmed
            end
          end
        end
      end

      context 'when allow top level setting is deactivated' do
        let(:group_id) { group.id }

        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
        end

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include(
            s_('ServiceAccount|User does not have permission to create a service account in this group.')
          )
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_service_account do
        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        end

        let(:boundary_object) { group }
        let(:request) { post api("/groups/#{group.id}/service_accounts", personal_access_token: pat), params: params }
      end

      context 'for rate limiting' do
        let_it_be(:user2) { create(:user) }

        let(:current_user) { user }

        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          group.add_owner(user2)
        end

        def request
          post api("/groups/#{group.id}/service_accounts", user), params: params
        end

        def request_with_second_scope
          post api("/groups/#{group.id}/service_accounts", user2), params: params
        end

        it_behaves_like 'rate limited endpoint', rate_limit_key: :service_account_creation
      end
    end
  end

  describe "PATCH /groups/:id/service_accounts/:user_id" do
    let(:group_id) { group.id }
    let(:params) { { name: 'Updated Name', username: 'updated_username' } }

    subject(:perform_request) do
      patch api("/groups/#{group_id}/service_accounts/#{service_account_user.id}", user), params: params
    end

    context 'when current user is a group owner' do
      before do
        group.add_owner(user)
      end

      context 'when group is identified by URL-encoded path' do
        let(:group_id) { group.full_path }

        it 'updates the service account user' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['name']).to eq(params[:name])
          expect(json_response['username']).to eq(params[:username])
        end
      end

      context 'when saas', :saas do
        it_behaves_like "service account user update"

        context 'when group has a verified domain' do
          before do
            stub_licensed_features(domain_verification: true)
            project = create(:project, group: group)
            create(:pages_domain, project: project, domain: 'test.com')
          end

          let(:params) { super().merge(email: 'test@test.com') }

          it 'updates the email' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['email']).to eq('test@test.com')
            expect(json_response.keys).to match_array(%w[id name username email public_email])
          end
        end
      end

      it_behaves_like 'authorizing granular token permissions', :update_service_account do
        let(:boundary_object) { group }
        let(:request) do
          patch api("/groups/#{group_id}/service_accounts/#{service_account_user.id}", personal_access_token: pat),
            params: params
        end
      end
    end
  end

  describe "DELETE /groups/:id/service_accounts/:user_id" do
    let(:issue) { create(:issue, author: service_account_user) }
    let(:group_id) { group.id }
    let(:path) { "/groups/#{group_id}/service_accounts/#{service_account_user.id}" }

    context "when allow top level group owners application setting is enabled" do
      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        group.add_owner(user)
      end

      it "is available for group owners", :sidekiq_inline, :saas do
        perform_enqueued_jobs { delete api(path, user) }
        expect(response).to have_gitlab_http_status(:no_content)
        expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: user)).to exist
      end

      it_behaves_like 'authorizing granular token permissions', :delete_service_account do
        let(:boundary_object) { group }
        let(:request) do
          delete api(path, personal_access_token: pat)
        end
      end
    end
  end

  describe "GET /groups/:id/service_accounts/:user_id/personal_access_tokens" do
    let(:group_id) { group.id }
    let(:target_user_id) { service_account_user.id }
    let(:path) { "/groups/#{group_id}/service_accounts/#{target_user_id}/personal_access_tokens" }
    let(:params) { nil }
    let(:admin_service_account) { create(:user, :service_account, :admin, provisioned_by_group: group) }

    subject(:perform_request) { get(api(path, user), params: params) }

    context 'when group service account is an admin', :enable_admin_mode do
      let(:user) { admin }

      context 'when the requested service account is an admin' do
        let(:target_user_id) { admin_service_account.id }

        let!(:impersonation_token) do
          create(:personal_access_token, :impersonation, user: admin_service_account)
        end

        let!(:admin_sa_token) { create(:personal_access_token, user: admin_service_account) }

        it 'returns 200 and lists tokens' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to include(admin_sa_token.id)
        end

        it 'does not return impersonation tokens' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).not_to include(impersonation_token.id)
        end
      end

      context 'when the requested service account is not an admin' do
        let(:service_account) do
          create(:user, :service_account, provisioned_by_group: group)
        end

        let(:target_user_id) { service_account.id }

        let!(:sa_token) { create(:personal_access_token, user: service_account) }

        it 'returns 200 and lists tokens' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to include(sa_token.id)
        end
      end
    end

    context 'when the user is a top-level-group owner' do
      before do
        group.add_owner(user)
      end

      context 'when the requested service account is an admin' do
        let(:target_user_id) { admin_service_account.id }

        let!(:impersonation_token) do
          create(:personal_access_token, :impersonation, user: admin_service_account)
        end

        let!(:admin_sa_token) { create(:personal_access_token, user: admin_service_account) }

        it 'returns 200 and lists tokens' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to include(admin_sa_token.id)
        end

        it 'does not return impersonation tokens' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).not_to include(impersonation_token.id)
        end
      end

      context 'when the service_account is provisioned_by the group' do
        # let_it_be overrides outer let(:group) so PAT let_it_be blocks get a stable committed group,
        # preventing stale provisioned_by_group association caches from causing foreign key violations.
        let_it_be(:group) { create(:group) }
        let_it_be_with_reload(:service_account_user) { create(:user, :service_account, provisioned_by_group: group) }
        let_it_be(:current_user) { user }
        let_it_be(:active_token1) { create(:personal_access_token, user: service_account_user) }
        let_it_be(:active_token2) { create(:personal_access_token, user: service_account_user) }
        let_it_be(:expired_token1) do
          create(:personal_access_token, user: service_account_user, expires_at: 1.year.ago)
        end

        let_it_be(:expired_token2) do
          create(:personal_access_token, user: service_account_user, expires_at: 1.year.ago)
        end

        let_it_be(:revoked_token1) do
          create(:personal_access_token, user: service_account_user, revoked: true)
        end

        let_it_be(:revoked_token2) do
          create(:personal_access_token, user: service_account_user, revoked: true)
        end

        let_it_be(:created_2_days_ago_token) do
          create(:personal_access_token, user: service_account_user, created_at: 2.days.ago)
        end

        let_it_be(:named_token) do
          create(:personal_access_token, user: service_account_user, name: 'test_1')
        end

        let_it_be(:last_used_2_days_ago_token) do
          create(:personal_access_token, user: service_account_user, last_used_at: 2.days.ago)
        end

        let_it_be(:last_used_2_months_ago_token) do
          create(:personal_access_token, user: service_account_user, last_used_at: 2.months.ago)
        end

        let_it_be(:created_at_asc) do
          [
            created_2_days_ago_token,
            active_token1,
            active_token2,
            expired_token1,
            expired_token2,
            revoked_token1,
            revoked_token2,
            named_token,
            last_used_2_days_ago_token,
            last_used_2_months_ago_token
          ]
        end

        let_it_be(:all_token_ids) do
          [
            active_token1.id,
            active_token2.id,
            expired_token1.id,
            expired_token2.id,
            revoked_token1.id,
            revoked_token2.id,
            named_token.id,
            created_2_days_ago_token.id,
            last_used_2_days_ago_token.id,
            last_used_2_months_ago_token.id
          ]
        end

        it_behaves_like 'an access token GET API with access token params'

        it_behaves_like 'authorizing granular token permissions', :read_service_account_personal_access_token do
          let(:boundary_object) { group }
          let(:request) { get api(path, personal_access_token: pat), params: params }
        end
      end

      context 'when the service_account is not provisioned_by the group' do
        before do
          service_account_user.provisioned_by_group_id = nil
          service_account_user.save!
        end

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the target_user (service_account) is not a service account' do
        let(:regular_user) { create(:user) }

        before do
          regular_user.provisioned_by_group_id = group.id
          regular_user.save!
        end

        it 'returns bad request error' do
          get api(
            "/groups/#{group_id}/service_accounts/#{regular_user.id}/personal_access_tokens", user
          ), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq("404 Group Not Found")
      end
    end

    context 'when service account does not exist' do
      let(:service_account) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when user is not a top-level-group owner' do
      before do
        group.add_maintainer(user)
      end

      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "POST /groups/:id/service_accounts/:user_id/personal_access_tokens" do
    let(:name) { 'new pat' }
    let(:group_id) { group.id }
    let(:description) { 'description' }
    let(:expires_at) { 3.days.from_now }
    let(:scopes) { %w[api read_user] }
    let(:params) { { name: name, description: description, expires_at: expires_at, scopes: scopes } }
    let(:path) { "/groups/#{group_id}/service_accounts/#{service_account_user.id}/personal_access_tokens" }

    subject(:perform_request) do
      post(api(path, user), params: params)
    end

    context 'when user is a group owner' do
      before do
        group.add_owner(user)
      end

      context 'when the group exists' do
        it_behaves_like 'authorizing granular token permissions', :create_service_account_personal_access_token do
          let(:boundary_object) { group }
          let(:request) { post api(path, personal_access_token: pat), params: params }
        end

        it 'creates personal access token for the user' do
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

        context 'when an error is thrown by the model' do
          let(:group_id) { group.id }
          let(:error_message) { 'error message' }
          let!(:admin_personal_access_token) { create(:personal_access_token, :admin_mode, user: admin) }

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

        context 'when service account does not belong to the group' do
          before do
            service_account_user.provisioned_by_group_id = nil
            service_account_user.save!
          end

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when target user is not a service account' do
          let(:regular_user) { create(:user) }

          before do
            regular_user.provisioned_by_group_id = group.id
            regular_user.save!
          end

          it 'returns bad request error' do
            post api(
              "/groups/#{group_id}/service_accounts/#{regular_user.id}/personal_access_tokens", user
            ), params: params

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'when group does not exist' do
        let(:group_id) { non_existing_record_id }

        it "returns error" do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when user is not a group owner' do
      before do
        group.add_maintainer(user)
      end

      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /groups/:id/service_accounts/:user_id/personal_access_tokens/:token_id' do
    let(:group) { create(:group) }
    let(:service_account_user) { create(:user, :service_account, provisioned_by_group: group) }

    let(:token) { create(:personal_access_token, user: service_account_user) }
    let(:group_id) { group.id }
    let(:user_id) { service_account_user.id }
    let(:token_id) { token.id }
    let(:request_path) { "/groups/#{group_id}/service_accounts/#{user_id}/personal_access_tokens/#{token_id}" }

    subject(:revoke_token) { delete(api(request_path, current_user)) }

    shared_examples 'successful token revocation' do
      it 'revokes the token' do
        revoke_token

        expect(response).to have_gitlab_http_status(:no_content)
        expect(token.reload.revoked?).to be_truthy
      end
    end

    shared_examples 'token deletion unauthorized' do
      it 'returns a forbidden response' do
        revoke_token

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the requesting user is an admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it_behaves_like 'successful token revocation'
      end

      context 'when admin mode is not enabled' do
        it_behaves_like 'token deletion unauthorized'
      end
    end

    context 'when the requesting user is a group owner' do
      before do
        group.add_owner(current_user)
      end

      context 'when all parameters are valid' do
        it_behaves_like 'successful token revocation'
      end

      it_behaves_like 'authorizing granular token permissions', :revoke_service_account_personal_access_token do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:request) { delete api(request_path, personal_access_token: pat) }
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
          revoke_token

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('400 Bad request - error message')
        end
      end

      context 'when parameters are invalid' do
        context 'when the token does not exist' do
          let(:token_id) { non_existing_record_id }

          it 'returns not found' do
            revoke_token

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the token does not belong to the service account user' do
          let(:other_user) { create(:user) }
          let(:token) { create(:personal_access_token, user: other_user) }

          it 'returns not found' do
            revoke_token

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['message']).to eq("404 Personal Access Token Not Found")
          end
        end

        context 'when the service account does not belong to the group' do
          let(:other_group) { create(:group) }

          before do
            service_account_user.provisioned_by_group_id = other_group.id
            service_account_user.save!
          end

          it 'returns not found' do
            revoke_token

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['message']).to eq('404 User Not Found')
          end
        end

        context 'when the group does not exist' do
          let(:group_id) { non_existing_record_id }

          it 'returns not found' do
            revoke_token

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when target user is not a service account' do
          let(:regular_user) { create(:user) }
          let(:user_id) { regular_user.id }
          let(:token) { create(:personal_access_token, user: regular_user) }

          before do
            regular_user.update!(provisioned_by_group_id: group.id)
          end

          it 'returns bad request error' do
            revoke_token

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end
    end

    context 'when the requesting user does not have sufficient permissions' do
      context 'when user is not a group owner' do
        before do
          group.add_maintainer(current_user)
        end

        it_behaves_like 'token deletion unauthorized'
      end

      context 'without authentication' do
        let(:current_user) { nil }

        it 'returns unauthorized' do
          revoke_token

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'POST /groups/:id/service_accounts/:user_id/personal_access_tokens/:token_id/rotate' do
    let(:group_id) { group.id }
    let(:user_id) { service_account_user.id }
    let(:token) { create(:personal_access_token, user: service_account_user) }
    let(:token_id) { token.id }
    let(:params) { nil }
    let(:path) do
      "/groups/#{group_id}/service_accounts/#{user_id}/personal_access_tokens/#{token_id}/rotate"
    end

    subject(:perform_request) do
      post(api(path, user), params: params)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let_it_be(:user) { admin }

      context 'when the group and token exist' do
        it 'revokes the token' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(token.reload.revoked?).to be_truthy
          expect(json_response['token']).not_to eq(token.token)
          expect(json_response['expires_at']).to eq(1.week.from_now.to_date.iso8601)
        end
      end
    end

    context 'when user is a group owner' do
      before do
        group.add_owner(user)
      end

      context 'when the group exists' do
        it 'revokes the token' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(token.reload.revoked?).to be_truthy
          expect(json_response['token']).not_to eq(token.token)
          expect(json_response['expires_at']).to eq(1.week.from_now.to_date.iso8601)
        end

        context 'when expiry is defined' do
          let(:expiry_date) { 1.month.from_now }
          let(:params) { { expires_at: expiry_date } }

          it "allows owner to rotate token", :freeze_time do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(token.reload.revoked?).to be_truthy
            expect(json_response['token']).not_to eq(token.token)
            expect(json_response['expires_at']).to eq(expiry_date.to_date.iso8601)
          end
        end

        it 'passes creation_source api to the service' do
          expect(::PersonalAccessTokens::RotateService).to receive(:new)
            .with(anything, anything, anything,
              hash_including(creation_source: PersonalAccessToken::CREATION_SOURCE_API))
            .and_call_original

          perform_request
        end

        context 'when service raises an error' do
          it 'returns error message' do
            token.revoke!
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq("400 Bad request - Token already revoked")
          end
        end

        context 'when token does not exist' do
          let(:token_id) { non_existing_record_id }

          it 'returns not found' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when token does not belong to service account user' do
          before do
            token.user = create(:user)
            token.save!
          end

          it 'returns bad request' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when service account does not belong to the group' do
          before do
            service_account_user.provisioned_by_group_id = nil
            service_account_user.save!
          end

          it 'returns error' do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when target user is not a service account' do
          let(:regular_user) { create(:user) }
          let(:user_id) { regular_user.id }

          before do
            regular_user.provisioned_by_group_id = group.id
            regular_user.save!
            token.user = regular_user
            token.save!
          end

          it 'returns bad request error' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'when group does not exist' do
        let(:group_id) { non_existing_record_id }

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :rotate_service_account_personal_access_token do
        let(:boundary_object) { group }
        let(:request) { post api(path, personal_access_token: pat), params: params }
      end
    end

    context 'when user is not a group owner' do
      it 'throws error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end

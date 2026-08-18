# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Users, :with_current_organization, :aggregate_failures, feature_category: :user_profile do
  let(:user)  { create(:user) }
  let(:admin) { create(:admin) }

  context 'updating name' do
    it_behaves_like 'PUT request permissions for admin mode' do
      let(:path) { "/users/#{user.id}" }
      let(:params) { { name: 'New Name' } }
    end

    shared_examples_for 'admin can update the name of a user' do
      it 'updates the user with new name' do
        put api("/users/#{user.id}", admin, admin_mode: true), params: { name: 'New Name' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['name']).to eq('New Name')
      end
    end

    context "when authenticated and ldap is enabled" do
      it "returns non-ldap user" do
        ldap_user = create :omniauth_user, provider: "ldapserver1"

        get api("/users", user), params: { skip_ldap: "true" }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an Array
        expect(json_response).not_to be_empty
        expect(json_response.map { |u| u['username'] })
          .not_to include(ldap_user.username)
      end
    end

    context 'when `disable_name_update_for_users` feature is available' do
      before do
        stub_licensed_features(disable_name_update_for_users: true)
      end

      context 'when the ability to update their name is disabled for users' do
        before do
          stub_application_setting(updating_name_disabled_for_users: true)
        end

        it_behaves_like 'admin can update the name of a user'
      end

      context 'when the ability to update their name is not disabled for users' do
        before do
          stub_application_setting(updating_name_disabled_for_users: false)
        end

        it_behaves_like 'admin can update the name of a user'
      end
    end

    context 'when `disable_name_update_for_users` feature is not available' do
      before do
        stub_licensed_features(disable_name_update_for_users: false)
      end

      it_behaves_like 'admin can update the name of a user'
    end
  end

  context 'extended audit events' do
    let_it_be(:user)  { create(:user) }
    let_it_be(:admin) { create(:admin) }

    before do
      stub_licensed_features(extended_audit_events: true)
    end

    describe "PUT /users/:id" do
      it_behaves_like 'PUT request permissions for admin mode' do
        let(:path) { "/users/#{user.id}" }
        let(:params) { { password: User.random_password } }
      end

      it "creates audit event when updating user with new password" do
        put api("/users/#{user.id}", admin, admin_mode: true), params: { password: User.random_password }

        expect(AuditEventReader.count).to eq(1)
      end
    end

    describe 'POST /users/:id/block' do
      it_behaves_like 'POST request permissions for admin mode' do
        let(:path) { "/users/#{user.id}/block" }
        let(:params) { {} }
      end

      it 'creates audit event when blocking user' do
        expect do
          post api("/users/#{user.id}/block", admin, admin_mode: true)
        end.to change { AuditEventReader.count }.by(1)
      end
    end

    describe 'POST /user/keys' do
      it 'creates audit event when user adds a new SSH key' do
        key = attributes_for(:key)

        expect do
          post api('/user/keys', user), params: key
        end.to change { AuditEventReader.count }.by(1)
      end
    end

    describe 'POST /users/:id/keys' do
      it_behaves_like 'POST request permissions for admin mode' do
        let(:path) { "/users/#{user.id}/keys" }
        let(:params) { attributes_for(:key) }
      end

      it 'creates audit event when admin adds a new key for a user' do
        key = attributes_for(:key)

        expect do
          post api("/users/#{user.id}/keys", admin, admin_mode: true), params: key
        end.to change { AuditEventReader.count }.by(1)
      end
    end
  end

  describe 'SSH Keys' do
    describe 'POST /user/keys' do
      let(:path) { '/user/keys' }

      context 'for enterprise users', :saas do
        before do
          stub_licensed_features(disable_ssh_keys: true)
          stub_saas_features(disable_ssh_keys: true)
        end

        let_it_be_with_reload(:group) { create(:group) }
        let_it_be_with_reload(:user) { create(:enterprise_user, enterprise_group: group) }

        it 'creates ssh key' do
          key_attrs = attributes_for(:key)

          expect do
            post api(path, user), params: key_attrs
          end.to change { user.keys.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
        end

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it 'does create ssh key' do
            key_attrs = attributes_for(:key)

            expect do
              post api(path, user), params: key_attrs
            end.not_to change { user.keys.count }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['base']).to include('SSH keys are disabled for this user')
          end
        end
      end
    end

    describe 'POST /users/:id/keys' do
      let(:path) { "/users/#{user.id}/keys" }

      context 'for enterprise users', :saas do
        before do
          stub_licensed_features(disable_ssh_keys: true)
          stub_saas_features(disable_ssh_keys: true)
        end

        let_it_be_with_reload(:group) { create(:group) }
        let_it_be_with_reload(:user) { create(:enterprise_user, enterprise_group: group) }

        it 'creates ssh key' do
          key_attrs = attributes_for(:key)

          expect do
            post api(path, admin, admin_mode: true), params: key_attrs
          end.to change { user.keys.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
        end

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it 'does create ssh key' do
            key_attrs = attributes_for(:key)

            expect do
              post api(path, admin, admin_mode: true), params: key_attrs
            end.not_to change { user.keys.count }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['base']).to include('SSH keys are disabled for this user')
          end
        end
      end
    end
  end

  context 'shared_runners_minutes_limit' do
    describe "PUT /users/:id" do
      context 'when user is an admin' do
        it "updates shared_runners_minutes_limit" do
          expect do
            put api("/users/#{user.id}", admin, admin_mode: true), params: { shared_runners_minutes_limit: 133 }
          end.to change { user.reload.shared_runners_minutes_limit }
                   .from(nil).to(133)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['shared_runners_minutes_limit']).to eq(133)
        end
      end

      context 'when user is not an admin' do
        it "cannot update their own shared_runners_minutes_limit" do
          expect do
            put api("/users/#{user.id}", user), params: { shared_runners_minutes_limit: 133 }
          end.not_to change { user.reload.shared_runners_minutes_limit }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  context 'when auditor field is specified' do
    describe "PUT /users/:id" do
      context 'when user is an admin' do
        before do
          stub_licensed_features(auditor_user: true)
        end

        it "updates auditor status for the user" do
          expect do
            put api("/users/#{user.id}", admin, admin_mode: true), params: { auditor: true }
          end.to change { user.reload.auditor }
                   .from(false)
                   .to(true)

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response['is_auditor']).to be(true)
        end

        context "when licensed_feature is not available" do
          before do
            stub_licensed_features(auditor_user: false)
          end

          it "cannot update auditor status for the user" do
            expect do
              put api("/users/#{user.id}", admin, admin_mode: true), params: { auditor: true }
            end.not_to change { user.reload.auditor }

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'when user is not an admin' do
        before do
          stub_licensed_features(auditor_user: true)
        end

        it "cannot update auditor status for the user" do
          expect do
            put api("/users/#{user.id}", user), params: { auditor: true }
          end.not_to change { user.reload.auditor }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    describe "POST /users/" do
      it_behaves_like 'POST request permissions for admin mode' do
        let(:path) { "/users" }
        let(:params) { attributes_for(:user).merge({ auditor: true }) }
      end

      context 'when user is an admin' do
        before do
          stub_licensed_features(auditor_user: true)
        end

        it "creates user with auditor status" do
          optional_attributes = { auditor: true }
          post api("/users", admin, admin_mode: true), params: attributes_for(:user).merge(optional_attributes)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['is_auditor']).to be(true)
        end

        context "when licensed_feature is not available" do
          before do
            stub_licensed_features(auditor_user: false)
          end

          it "cannot create user with auditor status" do
            optional_attributes = { auditor: true }
            post api("/users", admin, admin_mode: true), params: attributes_for(:user).merge(optional_attributes)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['is_auditor']).to be_nil
          end
        end
      end

      context 'when user is not an admin' do
        before do
          stub_licensed_features(auditor_user: true)
        end

        it "cannot create user with auditor status" do
          expect do
            post api("/users", user), params: { auditor: true }
          end.not_to change { user.reload.auditor }

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end

  context 'with group SAML' do
    before do
      stub_licensed_features(group_saml: true)
    end

    let(:saml_provider) { create(:saml_provider) }

    it_behaves_like 'POST request permissions for admin mode' do
      let(:path) { "/users" }
      let(:params) { attributes_for(:user, provider: 'group_saml', extern_uid: '67890', group_id_for_saml: saml_provider.group.id) }
    end

    it 'creates user with new identity' do
      post api("/users", admin, admin_mode: true), params: attributes_for(:user, provider: 'group_saml', extern_uid: '67890', group_id_for_saml: saml_provider.group.id)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['identities'].first['extern_uid']).to eq('67890')
      expect(json_response['identities'].first['provider']).to eq('group_saml')
      expect(json_response['identities'].first['saml_provider_id']).to eq(saml_provider.id)
    end

    it 'creates user with new identity without sending reset password email' do
      post api("/users", admin, admin_mode: true), params: attributes_for(:user, reset_password: false, provider: 'group_saml', extern_uid: '67890', group_id_for_saml: saml_provider.group.id)

      expect(response).to have_gitlab_http_status(:created)

      new_user = User.find(json_response['id'])
      expect(new_user.recently_sent_password_reset?).to be(false)
    end

    it 'updates user with new identity' do
      put api("/users/#{user.id}", admin, admin_mode: true), params: { provider: 'group_saml', extern_uid: '67890', group_id_for_saml: saml_provider.group.id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['identities'].first['extern_uid']).to eq('67890')
      expect(json_response['identities'].first['provider']).to eq('group_saml')
      expect(json_response['identities'].first['saml_provider_id']).to eq(saml_provider.id)
    end

    it 'fails to update user with nonexistent identity' do
      put api("/users/#{user.id}", admin, admin_mode: true), params: { provider: 'group_saml', extern_uid: '67890', group_id_for_saml: 15 }
      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']).to eq({ "identities.saml_provider_id" => ["can't be blank"] })
    end

    it 'fails to update user with nonexistent provider' do
      put api("/users/#{user.id}", admin, admin_mode: true), params: { provider: nil, extern_uid: '67890', group_id_for_saml: saml_provider.group.id }
      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']).to eq({ "identities.provider" => ["can't be blank"] })
    end

    it 'contains provisioned_by_group_id parameter' do
      user.update!(provisioned_by_group: saml_provider.group)
      get api("/users/#{user.id}", admin, admin_mode: true)

      expect(json_response).to have_key('provisioned_by_group_id')
    end
  end

  describe 'GET /api/users?auditors=true' do
    context 'querying users who are auditors' do
      before do
        stub_licensed_features(auditor_user: true)
      end

      let_it_be(:auditor_user) { create(:user, :auditor) }

      it 'returns all users' do
        get api("/users", admin, admin_mode: true), params: { auditors: true }
        expect(response).to match_response_schema('public_api/v4/user/basics')
        expect(json_response.size).to eq(1)
        expect(json_response.map { |u| u['id'] }).to include(auditor_user.id)
      end
    end
  end

  describe 'GET /user/:id' do
    context 'when authenticated' do
      context 'as an admin' do
        context 'and user has a plan', :saas do
          let!(:subscription) { create(:gitlab_subscription, :ultimate, namespace: user.namespace) }

          context 'and user is not a trial user' do
            it 'contains plan and trial' do
              get api("/users/#{user.id}", admin, admin_mode: true)

              expect(json_response).to include('plan' => 'ultimate', 'trial' => false)
            end
          end

          context 'and user is a trial user' do
            before do
              subscription.update!(
                trial: true,
                trial_starts_on: Date.current,
                trial_ends_on: 1.month.from_now
              )
            end

            it 'contains plan and trial' do
              get api("/users/#{user.id}", admin, admin_mode: true)

              expect(json_response).to include('plan' => 'ultimate', 'trial' => true)
            end
          end

          it 'contains is_auditor parameter' do
            get api("/users/#{user.id}", admin, admin_mode: true)

            expect(json_response).to have_key('is_auditor')
          end
        end

        context 'and user has no plan' do
          it 'returns `nil` for both plan and trial' do
            get api("/users/#{user.id}", admin, admin_mode: true)

            expect(json_response).to include('plan' => nil, 'trial' => false)
          end
        end

        it "contains scim_identities parameter" do
          get api("/users/#{user.id}", admin, admin_mode: true)

          expect(json_response).to have_key('scim_identities')
        end
      end

      context 'as a user' do
        it 'does not contain plan and trial info' do
          get api("/users/#{user.id}", user)

          expect(json_response).not_to have_key('plan')
          expect(json_response).not_to have_key('trial')
        end

        it 'does not contain is_auditor parameter' do
          get api("/users/#{user.id}", user)

          expect(json_response).not_to have_key('is_auditor')
        end

        it 'does not contain provisioned_by_group_id parameter' do
          get api("/users/#{user.id}", user)

          expect(json_response).not_to have_key('provisioned_by_group_id')
        end

        it "does not contain scim_identities parameter" do
          get api("/users/#{user.id}", user)

          expect(json_response).not_to have_key('scim_identities')
        end
      end
    end

    context 'when not authenticated' do
      it 'does not contain plan and trial info' do
        get api("/users/#{user.id}")

        expect(json_response).not_to have_key('plan')
        expect(json_response).not_to have_key('trial')
      end
    end
  end

  describe 'POST /users/:user_id/personal_access_tokens' do
    context 'when the user is a service account' do
      let(:service_account) { create(:user, :service_account) }
      let(:path) { "/users/#{service_account.id}/personal_access_tokens" }
      let(:admin_mode) { false }
      let(:valid_params) do
        { user_id: service_account.id, name: 'test_token', scopes: %w[read_repository], expires_at: 2.weeks.from_now }
      end

      subject(:call_api) { post api(path, user, admin_mode: admin_mode), params: params }

      context 'when the feature is licensed' do
        before do
          call_api
        end

        context 'when the user is an admin' do
          let(:user) { create(:admin) }

          context 'with required params' do
            let(:params) { valid_params }

            it 'does not allow PAT creation' do
              expect(response).to have_gitlab_http_status(:forbidden)
            end

            context 'when admin mode enabled' do
              let(:admin_mode) { true }

              it 'allows PAT creation' do
                expect(response).to have_gitlab_http_status(:created)
                expect(json_response['user_id']).to eq(service_account.id)
                expect(json_response['name']).to eq('test_token')
                expect(json_response['scopes']).to match_array(%w[read_repository])
              end
            end
          end

          context 'when missing params' do
            let(:params) { {} }

            it 'does not allow PAT creation' do
              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end

        context 'when the user is not an admin' do
          let(:user) { create(:user) }
          let(:params) { valid_params }

          it 'does not allow PAT creation' do
            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end

      context 'when the feature is not licensed', :enable_admin_mode do
        let(:user) { create(:admin) }
        let(:params) { valid_params }

        context 'when free-tier feature flag is enabled' do
          it 'allows PAT creation' do
            call_api

            expect(response).to have_gitlab_http_status(:created)
          end
        end
      end
    end
  end

  describe 'POST /user/personal_access_tokens' do
    let(:name) { 'new pat' }
    let(:description) { 'description' }
    let(:expires_at) { 3.days.from_now }
    let(:scopes) { %w[k8s_proxy] }
    let(:path) { "/user/personal_access_tokens" }
    let(:params) { { name: name, description: description, expires_at: expires_at, scopes: scopes } }

    context 'when disable_personal_access_tokens feature is available' do
      before do
        stub_licensed_features(disable_personal_access_tokens: true)
      end

      context 'when personal access tokens are disabled in settings' do
        before do
          stub_application_setting(disable_personal_access_tokens: true)
        end

        it 'does not create a personal access token' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'when personal access tokens are enabled in settings' do
        before do
          stub_application_setting(disable_personal_access_tokens: false)
        end

        it 'creates a personal access token' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['name']).to eq(name)
          expect(json_response['description']).to eq(description)
          expect(json_response['expires_at']).to eq(expires_at.to_date.iso8601)
          expect(json_response['scopes']).to eq(scopes)
          expect(json_response['id']).to be_present
          expect(json_response['created_at']).to be_present
          expect(json_response['active']).to be_truthy
          expect(json_response['revoked']).to be_falsey
          expect(json_response['token']).to be_present
        end
      end
    end
  end

  describe 'GET /api/users?extern_uid=:extern_uid&provider=scim' do
    context 'querying users by SCIM identity as an admin' do
      let(:instance_scim_user) { create(:user) }
      let!(:instance_scim_identity) { create(:scim_identity, user: instance_scim_user, extern_uid: 'test_uid', group_id: nil) }

      let(:group) { create(:group) }
      let(:group_scim_user) { create(:user) }
      let!(:group_scim_identity) { create(:group_scim_identity, user: group_scim_user, group: group, extern_uid: 'test_uid') }
      let(:group_scim_user_2) { create(:user) }
      let!(:group_scim_identity_2) { create(:group_scim_identity, user: group_scim_user_2, group: group, extern_uid: 'test_uid_2') }

      context 'when Gitlab.com' do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
        end

        it 'returns only users for the extern_uid' do
          non_scim_user = create(:user)

          get api("/users", admin, admin_mode: true), params: { extern_uid: 'test_uid', provider: 'scim' }

          expect(json_response.map { |u| u['id'] }).to include(group_scim_user.id)
          expect(json_response.map { |u| u['id'] }).not_to include(group_scim_user_2.id)
          expect(json_response.map { |u| u['id'] }).not_to include(non_scim_user.id)
        end
      end

      context 'when self managed' do
        it 'returns only users for the extern_uid' do
          non_scim_user = create(:user)

          get api("/users", admin, admin_mode: true), params: { extern_uid: 'test_uid', provider: 'scim' }

          expect(json_response.map { |u| u['id'] }).to include(instance_scim_user.id)
          expect(json_response.map { |u| u['id'] }).not_to include(non_scim_user.id)
        end
      end
    end
  end

  context 'setting profile to private' do
    it_behaves_like 'PUT request permissions for admin mode' do
      let(:path) { "/users/#{user.id}" }
      let(:params) { { private_profile: true } }
    end

    context 'when the ability to make their profile private is disabled for users' do
      before do
        stub_application_setting(make_profile_private: false)
      end

      it 'makes the profile private' do
        put api("/users/#{user.id}", admin, admin_mode: true), params: { private_profile: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['private_profile']).to be true
      end
    end
  end

  context 'setting policy_advanced_editor' do
    context 'policy advanced editor preference' do
      it 'saves advanced policy editor preference' do
        put api("/user/preferences", admin, admin_mode: true), params: { policy_advanced_editor: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['policy_advanced_editor']).to be true
      end

      it 'returns advanced policy editor preference' do
        get api("/user/preferences", admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['policy_advanced_editor']).to be false
      end
    end
  end

  context 'when user is assigned a custom admin role with read_admin_users permission', :enable_admin_mode do
    let_it_be(:custom_role_user) { create(:user) }
    let_it_be(:role) { create(:admin_member_role, :read_admin_users, user: custom_role_user) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    describe 'GET /users' do
      it 'returns users with admin-level fields including email' do
        get api('/users', custom_role_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/user/admins')
      end
    end

    describe 'GET /users/:id' do
      it 'returns the user with admin-level fields' do
        get api("/users/#{user.id}", custom_role_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/user/admin')
      end
    end
  end

  context 'when user is an auditor' do
    let_it_be(:auditor_user) { create(:user, :auditor) }

    before do
      stub_licensed_features(auditor_user: true)
    end

    describe 'GET /users' do
      it 'returns users with admin-level fields including email' do
        get api('/users', auditor_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/user/admins')
      end
    end

    describe 'GET /users/:id' do
      it 'returns the user with admin-level fields' do
        get api("/users/#{user.id}", auditor_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/user/admin')
      end
    end
  end
end

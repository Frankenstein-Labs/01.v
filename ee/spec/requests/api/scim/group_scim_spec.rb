# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Scim::GroupScim, feature_category: :system_access do
  let(:user) { create(:user) }
  let(:group) { identity.group }
  let(:scim_token) { create(:group_scim_auth_access_token, group: group) }

  let_it_be(:password) { User.random_password }
  let_it_be(:access_token) { 'secret_token' }
  let_it_be(:admin_bot) { create(:user, :admin_bot) }

  before do
    stub_licensed_features(group_allowed_email_domains: true, group_saml: true)
    group.add_developer(user)
    create(:saml_provider, group: group, default_membership_role: Gitlab::Access::DEVELOPER)
  end

  def scim_api(url, token: true)
    api(url, user, version: '', access_token: token ? scim_token : nil)
  end

  shared_examples 'SCIM API endpoints' do
    describe 'GET api/scim/v2/groups/:group/Users' do
      context 'without auth token' do
        it 'responds with 401' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id eq \"#{identity.extern_uid}\"", token: false)

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      it 'responds with 404 for a non existent group' do
        get scim_api("scim/v2/groups/#{non_existing_record_id}/Users")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 for a group with no SAML SSO configuration' do
        group.saml_provider.destroy!

        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with paginated users when there is no filter' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['Resources']).not_to be_empty
        expect(json_response['totalResults']).to eq(GroupScimIdentity.count + ScimIdentity.count)
      end

      it 'includes users with inactive scim identities' do
        identity.update!(active: false)

        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['Resources']).not_to be_empty
        expect(json_response['totalResults']).to eq(1)
        expect(json_response['Resources'].pluck('active')).to eq([false])
      end

      it 'includes users without a group membership' do
        group.members.where(user: user).first.destroy!

        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['Resources']).not_to be_empty
        expect(json_response['totalResults']).to eq(1)
      end

      it 'includes users with inactive scim identities who also have no group membership' do
        identity.update!(active: false)
        group.members.where(user: user).first.destroy!

        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['Resources']).not_to be_empty
        expect(json_response['totalResults']).to eq(1)
        expect(json_response['Resources'].pluck('active')).to eq([false])
      end

      it 'responds with an error for unsupported filters' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id ne \"#{identity.extern_uid}\"")

        expect(response).to have_gitlab_http_status(:precondition_failed)
      end

      context 'when existing user matches filter' do
        it 'responds with 200' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id eq \"#{identity.extern_uid}\"")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['Resources']).not_to be_empty
          expect(json_response['totalResults']).to eq(1)
        end

        it 'sets default values as required by the specification' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id eq \"#{identity.extern_uid}\"")

          expect(json_response['schemas']).to eq(['urn:ietf:params:scim:api:messages:2.0:ListResponse'])
          expect(json_response['itemsPerPage']).to eq(20)
          expect(json_response['startIndex']).to eq(1)
        end
      end

      context 'when no user matches filter' do
        it 'responds with 200' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id eq \"nonexistent\"")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['Resources']).to be_empty
          expect(json_response['totalResults']).to eq(0)
        end
      end

      it 'does not expose the groups attribute' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['Resources']).not_to be_empty
        expect(json_response['Resources']).to all(exclude('groups'))
      end
    end

    describe 'GET api/scim/v2/groups/:group/Users/:id' do
      context 'without auth token' do
        it 'responds with 401' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}", token: false)

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      it 'responds with 404 for a non existent group' do
        get scim_api("scim/v2/groups/#{non_existing_record_id}/Users/#{identity.extern_uid}")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 for a group with no SAML SSO configuration' do
        group.saml_provider.destroy!

        get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 if there is no user' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users/123")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when existing user' do
        it 'responds with 200' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(identity.extern_uid)
        end

        it 'does not expose the groups attribute' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).not_to have_key('groups')
        end

        it 'returns a user with an inactive scim identity' do
          identity.update!(active: false)

          get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(identity.extern_uid)
          expect(json_response['active']).to be false
        end

        it 'returns a user without any group memberships' do
          group.members.where(user: user).first.destroy!

          get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(identity.extern_uid)
        end

        it 'returns a user with an inactive scim identity who also has no group membership' do
          identity.update!(active: false)
          group.members.where(user: user).first.destroy!

          get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(identity.extern_uid)
          expect(json_response['active']).to be false
        end
      end
    end

    describe 'POST api/scim/v2/groups/:group/Users' do
      let_it_be(:post_params) do
        {
          externalId: 'test_uid',
          active: nil,
          userName: 'username',
          emails: [
            { primary: true, type: 'work', value: 'work@example.com' }
          ],
          name: { formatted: 'Test Name', familyName: 'Name', givenName: 'Test' },
          access_token: access_token,
          password: password
        }.to_query
      end

      context 'without auth token' do
        it 'responds with 401' do
          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}", token: false)

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      it 'responds with 404 for a non existent group' do
        post scim_api("scim/v2/groups/#{non_existing_record_id}/Users?params=#{post_params}")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 for a group with no SAML SSO configuration' do
        group.saml_provider.destroy!

        post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when a provisioning error occurs' do
        before do
          allow_next_instance_of(::Gitlab::Scim::Group::ProvisioningService) do |instance|
            allow(instance).to receive(:execute).and_return(
              ::Gitlab::Scim::ProvisioningResponse.new(status: :error)
            )
          end

          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'does not expose the password in error response' do
          expect(json_response.fetch('detail')).to match(/"password"\s*=>\s*"\[FILTERED\]"/)
        end

        it 'does not expose the access token in error response' do
          expect(json_response.fetch('detail')).to match(/"access_token"\s*=>\s*"\[FILTERED\]"/)
        end
      end

      context 'without an existing user' do
        let(:new_user) { User.find_by_email('work@example.com') }

        before do
          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'responds with 201' do
          expect(response).to have_gitlab_http_status(:created)
        end

        it 'has the user external ID' do
          expect(json_response['id']).to eq('test_uid')
        end

        it 'has the email' do
          expect(json_response['emails'].first['value']).to eq('work@example.com')
        end

        it 'created the user' do
          expect(new_user).not_to be_nil
        end

        it 'created the member with access level set in saml_provider' do
          member = GroupMember.find_by(user: new_user, group: group)
          expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
        end

        it 'created the identity' do
          expect(group.scim_identities.with_extern_uid('test_uid').first).not_to be_nil
        end

        it 'marks the user as provisioned by the group' do
          expect(new_user.provisioned_by_group).to eq(group)
        end
      end

      context 'when existing user' do
        let(:old_user) { create(:user, email: 'work@example.com') }

        before do
          create(:group_scim_identity, user: old_user, group: group, extern_uid: 'test_uid')
          group.add_guest(old_user)

          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'responds with 201' do
          expect(response).to have_gitlab_http_status(:created)
        end

        it 'has the user external ID' do
          expect(json_response['id']).to eq('test_uid')
        end

        it 'does not mark the user as provisioned' do
          expect(old_user.reload.provisioned_by_group).to be_nil
        end

        it 'does not change the group membership' do
          member = GroupMember.find_by(user: old_user, group: group)
          expect(member.access_level).to eq(::Gitlab::Access::GUEST)
        end
      end

      context 'with a user with an inactive scim identity and no group membership' do
        let(:deprovisioned_user) { create(:user, email: 'work@example.com') }
        let!(:scim_identity) do
          create(:group_scim_identity, user: deprovisioned_user, group: group, extern_uid: 'test_uid', active: false)
        end

        before do
          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'responds with 201' do
          expect(response).to have_gitlab_http_status(:created)
        end

        it 'has the user external ID' do
          expect(json_response['id']).to eq('test_uid')
        end

        it 'does not mark the user as provisioned' do
          expect(deprovisioned_user.reload.provisioned_by_group).to be_nil
        end

        it 'creates a group membership' do
          member = GroupMember.find_by(user: deprovisioned_user, group: group)
          expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
        end

        it 'does not activate the scim identity' do
          expect(scim_identity.reload.active).to be false
        end
      end

      context 'with a user pending asynchronous deprovisioning' do
        let(:user_pending_deletion) { create(:user, email: 'work@example.com') }
        let!(:scim_identity) do
          create(:group_scim_identity, user: user_pending_deletion, group: group, extern_uid: 'test_uid', active: false)
        end

        before do
          create(:members_deletion_schedules, namespace: group, user: user_pending_deletion, scheduled_by: admin_bot)
          group.add_guest(user_pending_deletion)

          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'responds with 409' do
          expect(response).to have_gitlab_http_status(:conflict)
        end

        it 'has an error message' do
          expect(json_response['detail']).to include(
            'User is pending deprovisioning. Please wait for the user to be deprovisioned and try again later.'
          )
        end

        it 'does not mark the user as provisioned' do
          expect(user_pending_deletion.reload.provisioned_by_group).to be_nil
        end

        it 'does not adjust the group membership' do
          member = GroupMember.find_by(user: user_pending_deletion, group: group)
          expect(member.access_level).to eq(::Gitlab::Access::GUEST)
        end

        it 'does not activate the scim identity' do
          expect(scim_identity.reload.active).to be false
        end
      end

      it_behaves_like 'storing arguments in the application context for the API' do
        let(:expected_params) { { root_namespace: group.full_path_components.first } }

        subject { post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}") }
      end

      context 'with allowed domain setting switched on' do
        let(:new_user) { User.find_by_email('work@example.com') }
        let(:member) { GroupMember.find_by(user: new_user, group: group) }

        context 'with different domains' do
          before do
            create(:allowed_email_domain, group: group)
            post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
          end

          it 'created the user' do
            expect(new_user).not_to be_nil
          end

          it 'did not create member' do
            expect(member).to be_nil
          end

          context 'with invalid user params' do
            let(:post_params) do
              {
                externalId: 'test_uid',
                active: nil,
                userName: 'username',
                emails: [
                  { primary: nil, type: 'work', value: '' }
                ],
                name: { formatted: 'Test Name', familyName: 'Name', givenName: 'Test' }
              }.to_query
            end

            it 'returns user error' do
              expect(response).to have_gitlab_http_status(:precondition_failed)
              expect(json_response.fetch('detail')).to include("Email can't be blank")
            end
          end
        end

        context 'with matching domains' do
          before do
            create(:allowed_email_domain, group: group, domain: 'example.com')
            post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
          end

          it 'created the user' do
            expect(new_user).not_to be_nil
          end

          it 'created the member with access level set in saml_provider' do
            expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
          end
        end
      end
    end

    describe 'PATCH api/scim/v2/groups/:group/Users/:id' do
      def call_patch_api(params)
        patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
      end

      context 'without auth token' do
        it 'responds with 401' do
          params = { Operations: [{ op: 'Replace', path: 'active', value: 'False' }] }.to_query

          patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}", token: false)

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      it 'responds with 404 for a non existent group' do
        params = { Operations: [{ op: 'Replace', path: 'id', value: 'new_uid' }] }.to_query

        patch scim_api("scim/v2/groups/#{non_existing_record_id}/Users/#{identity.extern_uid}?#{params}")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 for a group with no SAML SSO configuration' do
        group.saml_provider.destroy!

        params = { Operations: [{ op: 'Replace', path: 'id', value: 'new_uid' }] }.to_query

        call_patch_api(params)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 if there is no user' do
        patch scim_api("scim/v2/groups/#{group.full_path}/Users/123")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'deactivates the scim_identity' do
        params = { Operations: [{ op: 'Replace', path: 'active', value: 'False' }] }.to_query

        call_patch_api(params)

        expect(response).to have_gitlab_http_status(:no_content)
        expect(identity.reload.active).to be false
      end

      context 'when the user is pending removal from the group' do
        before do
          identity.update!(active: false)
          create(:members_deletion_schedules, user: user, namespace: group)
        end

        it 'returns success and leaves the identity inactive' do
          params = { Operations: [{ op: 'Replace', path: 'active', value: 'False' }] }.to_query

          call_patch_api(params)

          expect(response).to have_gitlab_http_status(:no_content)
          expect(identity.reload.active).to be false
        end
      end

      context 'with owner' do
        params = { Operations: [{ op: 'Replace', path: 'active', value: 'False' }] }.to_query

        before do
          group.add_owner(user)
          call_patch_api(params)
        end

        it 'responds with 412' do
          expect(response).to have_gitlab_http_status(:precondition_failed)
        end

        it 'returns the last group owner error' do
          expect(response.body).to include("Error updating #{user.name}")
        end

        it 'does not deactivate the identity' do
          expect(identity.reload.active).to be true
        end
      end

      context 'when reprovisioning user' do
        let_it_be(:params) { { Operations: [{ op: 'Replace', path: 'active', value: 'true' }] }.to_query }

        it 'activates the scim_identity' do
          identity.update!(active: false)

          call_patch_api(params)

          expect(response).to have_gitlab_http_status(:no_content)
          expect(identity.reload.active).to be true
        end

        it 'does not call reprovision service when identity is already active' do
          expect(::Gitlab::Scim::Group::ReprovisioningService).not_to receive(:new)

          call_patch_api(params)

          expect(response).to have_gitlab_http_status(:no_content)
          expect(identity.reload.active).to be true
        end

        context 'when the user is scheduled for deprovision' do
          before do
            identity.update!(active: false)
            create(:members_deletion_schedules, user: user, namespace: group)
          end

          it 'does not reactivate the scim user and returns an error' do
            call_patch_api(params)

            expect(response).to have_gitlab_http_status(:conflict)
            expect(json_response['detail']).to eq(
              'User is pending deprovisioning. Please wait for the user to be deprovisioned and try again later.'
            )
          end
        end
      end

      context 'when existing user' do
        context 'with extern UID' do
          let(:params) { { Operations: [{ op: 'Replace', path: 'id', value: 'new_uid' }] }.to_query }

          it 'updates the extern_uid' do
            call_patch_api(params)

            expect(response).to have_gitlab_http_status(:no_content)
            expect(identity.reload.extern_uid).to eq('new_uid')
          end

          context 'when the identity is inactive' do
            before do
              identity.update!(active: false)
            end

            it 'updates the extern_uid and does not reactivate the user' do
              call_patch_api(params)

              identity.reload
              expect(response).to have_gitlab_http_status(:no_content)
              expect(identity.active).to be false
              expect(identity.extern_uid).to eq('new_uid')
            end
          end
        end

        context 'with user attributes' do
          context 'with name' do
            before do
              params = { Operations: [{ op: 'Replace', path: 'name.formatted', value: 'new_name' }] }.to_query

              call_patch_api(params)
            end

            it 'responds with 204' do
              expect(response).to have_gitlab_http_status(:no_content)
            end

            it 'does not update the name' do
              expect(user.reload.name).not_to eq('new_name')
            end

            it 'responds with an empty response' do
              expect(response.body).to eq('')
            end
          end

          context 'with email' do
            before do
              params = {
                Operations: [
                  {
                    op: 'Replace',
                    path: 'emails[type eq "work"].value',
                    value: 'new@mail.com'
                  }
                ]
              }.to_query

              call_patch_api(params)
            end

            it 'does not update the email' do
              expect(user.reload.unconfirmed_email).not_to eq('new@mail.com')
            end

            it 'responds with 204' do
              expect(response).to have_gitlab_http_status(:no_content)
            end
          end

          context 'with userName' do
            before do
              params = { Operations: [{ op: 'Replace', path: 'userName', value: 'new_username' }] }.to_query

              call_patch_api(params)
            end

            it 'responds with 204' do
              expect(response).to have_gitlab_http_status(:no_content)
            end

            it 'does not update the username' do
              expect(user.reload.username).not_to eq('new_username')
            end

            it 'responds with an empty response' do
              expect(response.body).to eq('')
            end
          end
        end
      end
    end

    describe 'DELETE /scim/v2/groups/:group/Users/:id' do
      context 'without token auth' do
        it 'responds with 401' do
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}", token: false)

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'when existing user' do
        before do
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")
        end

        it 'responds with 204' do
          expect(response).to have_gitlab_http_status(:no_content)
        end

        it 'responds with an empty response' do
          expect(response.body).to eq('')
        end

        it 'deactivates the identity' do
          expect(identity.reload.active).to be false
        end
      end

      context 'when the user is not a group member' do
        before do
          group.members.find_by_user_id(user.id).destroy!
        end

        it 'deactivates the identity' do
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(identity.reload.active).to be false
        end
      end

      context 'with owner' do
        before do
          group.add_owner(user)
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")
        end

        it 'responds with 412' do
          expect(response).to have_gitlab_http_status(:precondition_failed)
        end

        it 'returns the last group owner error' do
          expect(response.body).to include(
            "Could not remove #{user.name} from #{group.name}. Cannot remove last group owner."
          )
        end

        it 'does not deactivate the identity' do
          expect(identity.reload.active).to be true
        end
      end

      context 'with an identity that is already pending deletion' do
        before do
          identity.update!(active: false)
          create(:members_deletion_schedules, namespace: identity.group, user: identity.user)
        end

        it 'responds with success and leaves the identity pending deletion' do
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(response).to have_gitlab_http_status(:no_content)
          expect(response.body).to be_empty
          expect(identity.reload.active).to be false
          schedule = ::Members::DeletionSchedule.find_by(namespace: identity.group, user: identity.user)
          expect(schedule).to be_present
        end
      end

      it 'responds with 404 if there is no user' do
        delete scim_api("scim/v2/groups/#{group.full_path}/Users/123")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 for a non existent group' do
        delete scim_api("scim/v2/groups/#{non_existing_record_id}/Users/#{identity.extern_uid}")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'responds with 404 for a group with no SAML SSO configuration' do
        group.saml_provider.destroy!

        delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'when user with an alphanumeric extern_uid' do
    let(:identity) { create(:group_scim_identity, user: user, extern_uid: generate(:username)) }

    it_behaves_like 'SCIM API endpoints'
  end

  context 'when user with an email extern_uid' do
    let(:identity) { create(:group_scim_identity, user: user, extern_uid: user.email) }

    it_behaves_like 'SCIM API endpoints'
  end

  describe 'Current.organization resolution' do
    let(:organization) { create(:organization) }
    let(:scim_group) { create(:group, organization: organization) }
    let(:identity) { create(:group_scim_identity, user: user, extern_uid: generate(:username), group: scim_group) }

    it 'assigns the organization of the authenticated group' do
      expect(::API::API::LOG_FORMATTER).to receive(:call) do |_severity, _datetime, _, data|
        expect(data.stringify_keys).to include('meta.organization_id' => organization.id)
      end

      get scim_api("scim/v2/groups/#{group.full_path}/Users")

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when an organization is already assigned' do
      let(:other_organization) { create(:organization) }

      before do
        allow(::Current).to receive_messages(organization_assigned: true, organization: other_organization)
      end

      it 'does not overwrite the assigned organization' do
        expect(::Current).not_to receive(:organization=)

        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end

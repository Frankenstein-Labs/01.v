# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Scim::InstanceScim, feature_category: :system_access do
  include LoginHelpers

  let_it_be(:organization) { create(:organization) }
  let(:user) { create(:user, organizations: [organization]) }
  let(:scim_token) { create(:scim_oauth_access_token, group: nil, organization: organization) }

  before do
    stub_licensed_features(instance_level_scim: true)
    stub_basic_saml_config
    allow(Gitlab::Auth::OAuth::Provider).to receive(:providers).and_return([:saml])
  end

  shared_examples 'Not available to SaaS customers' do
    context 'on GitLab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      it 'renders not found' do
        api_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'Instance level SCIM license required' do
    context 'when license is not enabled' do
      before do
        stub_licensed_features(instance_level_scim: false)
      end

      it 'returns not found error' do
        api_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'SCIM token authenticated' do
    context 'without token auth' do
      let(:scim_token) { nil }

      it 'responds with 401' do
        api_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  shared_examples 'SAML SSO must be enabled' do
    it 'responds with 403 when instance SAML SSO not enabled' do
      allow(Gitlab::Auth::Saml::Config).to receive(:enabled?).and_return(false)

      api_request

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  shared_examples 'Invalid extern_uid returns 404' do
    context 'when there is no user associated with extern_uid' do
      let(:extern_uid) { non_existing_record_id }

      it 'responds with 404' do
        api_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'Filtered params in errors' do
    it 'does not expose the password in error response' do
      api_request

      expect(json_response.fetch('detail')).to match(/"password"\s*=>\s*"\[FILTERED\]"/)
    end

    it 'does not expose the access token in error response' do
      api_request

      expect(json_response.fetch('detail')).to match(/"access_token"\s*=>\s*"\[FILTERED\]"/)
    end
  end

  shared_examples 'sets current organization' do
    it 'uses the correct organization' do
      expect(::Current).to receive(:organization=).with(organization).and_call_original

      api_request
    end
  end

  shared_examples 'SCIM API endpoints' do
    describe 'GET api/scim/v2/application/Users' do
      let(:filter_query) { '' }

      subject(:api_request) do
        url = "scim/v2/application/Users#{filter_query}"
        get api(url, user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      it 'responds with paginated users when there is no filter' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['Resources']).not_to be_empty
        expect(json_response['totalResults']).to eq(ScimIdentity.count)
      end

      context 'when the user belongs to no SCIM groups' do
        it 'returns an empty groups array' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)

          user_resource = json_response['Resources'].find { |r| r['id'] == identity.extern_uid }

          expect(user_resource['groups']).to eq([])
        end
      end

      context 'when the user belongs to SCIM groups' do
        let(:scim_group_uid) { SecureRandom.uuid }
        let(:saml_group_name) { 'Engineering' }
        let(:user_resource) do
          json_response['Resources'].find { |r| r['id'] == identity.extern_uid }
        end

        before do
          create(:saml_group_link, saml_group_name: saml_group_name, scim_group_uid: scim_group_uid)
          create(:scim_group_membership, user: user, scim_group_uid: scim_group_uid)
        end

        it 'returns an entry for each SCIM group the user belongs to' do
          other_scim_group_uid = SecureRandom.uuid
          create(:saml_group_link, saml_group_name: 'Marketing', scim_group_uid: other_scim_group_uid)
          create(:scim_group_membership, user: user, scim_group_uid: other_scim_group_uid)

          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(user_resource['groups']).to contain_exactly(
            { 'value' => scim_group_uid, 'display' => saml_group_name, 'type' => 'direct' },
            { 'value' => other_scim_group_uid, 'display' => 'Marketing', 'type' => 'direct' }
          )
        end

        it 'returns the SCIM groups for multiple users' do
          other_user = create(:user, organizations: [organization])
          other_identity = create(:scim_identity, user: other_user, group: nil)

          other_scim_group_uid = SecureRandom.uuid
          create(:saml_group_link, saml_group_name: 'Marketing', scim_group_uid: other_scim_group_uid)
          create(:scim_group_membership, user: other_user, scim_group_uid: other_scim_group_uid)

          api_request

          expect(response).to have_gitlab_http_status(:ok)

          expect(user_resource['groups']).to contain_exactly(
            { 'value' => scim_group_uid, 'display' => saml_group_name, 'type' => 'direct' }
          )

          other_user_resource = json_response['Resources'].find { |r| r['id'] == other_identity.extern_uid }
          expect(other_user_resource['groups']).to contain_exactly(
            { 'value' => other_scim_group_uid, 'display' => 'Marketing', 'type' => 'direct' }
          )
        end

        it 'omits memberships whose SCIM group has no SAML group link' do
          create(:scim_group_membership, user: user, scim_group_uid: SecureRandom.uuid)

          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(user_resource['groups']).to contain_exactly(
            { 'value' => scim_group_uid, 'display' => saml_group_name, 'type' => 'direct' }
          )
        end

        it 'returns one entry per SCIM group when the SCIM group has multiple SAML group links' do
          create(:saml_group_link, saml_group_name: saml_group_name, scim_group_uid: scim_group_uid)

          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(user_resource['groups']).to contain_exactly(
            { 'value' => scim_group_uid, 'display' => saml_group_name, 'type' => 'direct' }
          )
        end

        it 'avoids N+1 queries when the user belongs to multiple SCIM groups' do
          control = ActiveRecord::QueryRecorder.new do
            get api('scim/v2/application/Users', user, version: '', access_token: scim_token)
          end

          2.times do
            additional_scim_group_uid = SecureRandom.uuid
            create(:saml_group_link, scim_group_uid: additional_scim_group_uid)
            create(:scim_group_membership, user: user, scim_group_uid: additional_scim_group_uid)
          end

          expect do
            get api('scim/v2/application/Users', user, version: '', access_token: scim_token)
          end.not_to exceed_query_limit(control)
        end
      end

      context 'when unsupported filters are used' do
        let(:filter_query) { "?filter=id ne \"#{identity.extern_uid}\"" }

        it 'responds with an error' do
          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
        end
      end

      context 'when existing user matches filter' do
        let(:filter_query) { "?filter=id eq \"#{identity.extern_uid}\"" }

        it 'responds with 200' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['Resources']).not_to be_empty
          expect(json_response['totalResults']).to eq(1)
        end

        it 'sets default values as required by the specification' do
          api_request

          expect(json_response['schemas']).to match_array(['urn:ietf:params:scim:api:messages:2.0:ListResponse'])
          expect(json_response['itemsPerPage']).to eq(20)
          expect(json_response['startIndex']).to eq(1)
        end
      end

      context 'when no user matches filter' do
        let(:filter_query) { "?filter=id eq \"#{non_existing_record_id}\"" }

        it 'responds with 200' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['Resources']).to be_empty
          expect(json_response['totalResults']).to eq(0)
        end
      end
    end

    describe 'GET api/scim/v2/application/Users/:id' do
      let(:extern_uid) { identity.extern_uid }

      subject(:api_request) do
        url = "scim/v2/application/Users/#{extern_uid}"
        get api(url, user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'Invalid extern_uid returns 404'
      it_behaves_like 'sets current organization'

      it 'responds with 403 when instance SAML SSO not configured' do
        allow(Gitlab::Auth::Saml::Config).to receive(:enabled?).and_return(false)

        api_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      context 'when there is a user with extern_uid' do
        it 'responds with 200' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(identity.extern_uid)
        end
      end

      context 'when the user belongs to no SCIM groups' do
        it 'returns an empty groups array' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['groups']).to eq([])
        end
      end

      context 'when the user belongs to a SCIM group' do
        let(:scim_group_uid) { SecureRandom.uuid }
        let(:saml_group_name) { 'Engineering' }

        before do
          create(:saml_group_link, saml_group_name: saml_group_name, scim_group_uid: scim_group_uid)
          create(:scim_group_membership, user: user, scim_group_uid: scim_group_uid)
        end

        it 'returns the group in the response' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['groups']).to contain_exactly(
            { 'value' => scim_group_uid, 'display' => saml_group_name, 'type' => 'direct' }
          )
        end
      end
    end

    describe 'POST api/scim/v2/application/Users' do
      let_it_be(:password) { User.random_password }
      let_it_be(:access_token) { 'secret_token' }

      let(:email) { 'work@example.com' }
      let(:external_uid) { 'test_uid' }
      let(:post_params) do
        {
          externalId: external_uid,
          active: nil,
          userName: 'username',
          emails: [
            { primary: true, type: 'work', value: email }
          ],
          name: { formatted: 'Test Name', familyName: 'Name', givenName: 'Test' },
          access_token: access_token,
          password: password
        }.to_query
      end

      subject(:api_request) do
        url = "scim/v2/application/Users?params=#{post_params}"
        post api(url, user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      context 'without an existing user' do
        it 'responds with 201 and the new user attributes' do
          api_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['id']).to eq(external_uid)
          expect(json_response['emails'].first['value']).to eq(email)
        end
      end

      context 'when existing user' do
        it 'responds with 201 and the scim user attributes' do
          create(:user, email: email)

          expect(::Gitlab::Scim::ProvisioningService).to receive(:new).with(
            hash_including(organization_id: organization.id)
          ).and_call_original

          api_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['id']).to eq(external_uid)
          expect(json_response['emails'].first['value']).to eq(email)
        end
      end

      context 'when a provisioning error occurs' do
        before do
          allow_next_instance_of(::Gitlab::Scim::ProvisioningService) do |instance|
            allow(instance).to receive(:execute).and_return(
              ::Gitlab::Scim::ProvisioningResponse.new(status: :error)
            )
          end
        end

        it_behaves_like 'Filtered params in errors'

        it 'returns a 412 response and error message' do
          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
          expect(json_response.fetch('detail')).to match(/Error saving user/)
        end
      end

      context 'when a conflict occurs' do
        before do
          allow_next_instance_of(::Gitlab::Scim::ProvisioningService) do |instance|
            allow(instance).to receive(:execute).and_return(
              ::Gitlab::Scim::ProvisioningResponse.new(status: :conflict)
            )
          end
        end

        it_behaves_like 'Filtered params in errors'

        it 'returns a 409 response and error message' do
          api_request

          expect(response).to have_gitlab_http_status(:conflict)
          expect(json_response.fetch('detail')).to match(/Error saving user/)
        end
      end
    end

    describe 'PATCH api/scim/v2/application/Users/:id' do
      let(:extern_uid) { identity.extern_uid }
      let(:params) { '' }

      subject(:api_request) do
        url = "scim/v2/application/Users/#{extern_uid}?#{params}"
        patch api(url, user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'Invalid extern_uid returns 404'
      it_behaves_like 'sets current organization'

      context 'when params update extern_uid for existing scim identity' do
        let(:new_extern_uid) { 'new_extern_uid' }
        let(:params) do
          {
            Operations: [{ op: 'Replace', path: 'id', value: new_extern_uid }]
          }.to_query
        end

        it 'responds with 204 and updates extern_uid' do
          api_request

          expect(response).to have_gitlab_http_status(:no_content)
          expect(identity.reload.extern_uid).to eq(new_extern_uid)
        end
      end

      context 'when params update other attributes on existing scim identity' do
        let(:params) do
          {
            Operations: [
              { op: 'Replace', path: 'name.formatted', value: 'new_name' },
              { op: 'Replace', path: 'emails[type eq "work"].value', value: 'new@mail.com' },
              { op: 'Replace', path: 'userName', value: 'new_username' }

            ]
          }.to_query
        end

        it 'responds with success but does not update the attributes' do
          api_request

          expect(response).to have_gitlab_http_status(:no_content)
          expect(user.reload.name).not_to eq('new_name')
          expect(user.reload.unconfirmed_email).not_to eq('new@mail.com')
          expect(user.reload.username).not_to eq('new_username')
        end
      end

      context 'when params are invalid' do
        let(:params) do
          { Garbage: 'params' }.to_query
        end

        it 'ignores the params and returns a success response' do
          api_request

          expect(response).to have_gitlab_http_status(:success)
        end
      end

      context 'when extern_uid update fails' do
        let(:new_extern_uid) { 'new_extern_uid' }
        let(:params) do
          {
            Operations: [{ op: 'Replace', path: 'id', value: new_extern_uid }]
          }.to_query
        end

        before do
          allow(ScimIdentity).to receive_message_chain(:for_instance, :with_extern_uid).and_return([identity])
          allow(identity).to receive(:update).and_return(false)
        end

        it 'returns an error' do
          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
          expect(json_response.fetch('detail')).to match(/Error updating/)
          expect(identity.reload.extern_uid).to eq(extern_uid)
        end
      end

      context 'when deprovision fails' do
        let(:params) do
          {
            Operations: [{ op: 'Replace', path: 'active', value: 'false' }]
          }.to_query
        end

        before do
          allow_next_instance_of(::Gitlab::Scim::DeprovisioningService) do |instance|
            allow(instance).to receive(:execute).and_raise(ActiveRecord::RecordInvalid)
          end
        end

        it 'returns an error' do
          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
        end
      end

      context 'when reprovision fails' do
        let(:params) do
          {
            Operations: [{ op: 'Replace', path: 'active', value: 'true' }]
          }.to_query
        end

        before do
          allow_next_instance_of(::Gitlab::Scim::ReprovisioningService) do |instance|
            allow(instance).to receive(:execute).and_raise(ActiveRecord::RecordInvalid)
          end
        end

        it 'returns an error' do
          identity.update!(active: false)

          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
        end
      end

      context 'when param values deactivate scim identity' do
        let(:params) do
          {
            Operations: [{ op: 'Replace', path: 'active', value: 'False' }]
          }.to_query
        end

        it 'deactivates the scim_identity' do
          expect(identity.reload.active).to be true

          api_request

          expect(identity.reload.active).to be false
        end
      end

      context 'when param values reactivate scim identity' do
        let(:params) do
          {
            Operations: [{ op: 'Replace', path: 'active', value: 'true' }]
          }.to_query
        end

        it 'activates the scim_identity' do
          identity.update!(active: false)

          api_request

          expect(identity.reload.active).to be true
        end

        it 'does not call reprovision service when identity is already active' do
          expect(::Gitlab::Scim::ReprovisioningService).not_to receive(:new)

          api_request
        end
      end

      context 'when id param is missing from request' do
        let(:extern_uid) { '' }

        it 'returns method not allowed error' do
          api_request

          expect(response).to have_gitlab_http_status(:method_not_allowed)
        end
      end
    end

    describe 'DELETE /scim/v2/application/Users/:id' do
      let(:extern_uid) { identity.extern_uid }

      subject(:api_request) do
        url = "scim/v2/application/Users/#{extern_uid}"
        delete api(url, user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'Invalid extern_uid returns 404'
      it_behaves_like 'sets current organization'

      context 'when existing user' do
        it 'responds with 204 and deactivates the scim identity' do
          api_request

          expect(response).to have_gitlab_http_status(:no_content)
          expect(identity.reload.active).to be false
        end
      end

      context 'when deprovision fails' do
        before do
          allow_next_instance_of(::Gitlab::Scim::DeprovisioningService) do |instance|
            allow(instance).to receive(:execute).and_raise(ActiveRecord::RecordInvalid)
          end
        end

        it 'returns an error' do
          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
        end
      end
    end
  end

  context 'when user with an alphanumeric extern_uid' do
    let!(:identity) { create(:scim_identity, user: user, extern_uid: generate(:username), group: nil) }

    it_behaves_like 'SCIM API endpoints'
  end

  context 'when user with an email extern_uid' do
    let!(:identity) { create(:scim_identity, user: user, extern_uid: user.email, group: nil) }

    it_behaves_like 'SCIM API endpoints'
  end

  describe 'resource :Groups' do
    shared_context 'with BSO (block seat overages) enabled', :sidekiq_inline do
      before do
        stub_feature_flags(bso_minimal_access_fallback: true)

        stub_licensed_features(
          instance_level_scim: true,
          minimal_access_role: true
        )
      end

      context 'when operation would consume new seats' do
        before do
          allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to receive_messages(
              block_seat_overages?: true,
              seats_available_for?: false # No seats available = would consume new seats
            )
        end

        it 'adds the user with MINIMAL_ACCESS instead of the configured access level' do
          api_request

          expect(response).to be_successful

          member = saml_group_link.group.all_group_members.find_by(user: identity.user)
          expect(member.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
        end
      end

      context 'when operation would NOT consume new seats' do
        before do
          allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to receive_messages(
              block_seat_overages?: true,
              seats_available_for?: true # Seats available = no new consumption
            )
        end

        it 'adds the user with the configured access level' do
          api_request

          expect(response).to be_successful

          member = saml_group_link.group.all_group_members.find_by(user: identity.user)
          expect(member.access_level).to eq(Gitlab::Access::GUEST)
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: false)
        end

        it 'adds the user with the configured access level' do
          api_request

          expect(response).to be_successful

          member = saml_group_link.group.all_group_members.find_by(user: identity.user)
          expect(member.access_level).to eq(Gitlab::Access::GUEST)
        end
      end
    end

    describe 'POST api/scim/v2/application/Groups' do
      let(:group_name) { 'Engineering' }
      let(:scim_group_uid) { SecureRandom.uuid }
      let!(:saml_group_link) { create(:saml_group_link, saml_group_name: group_name) }
      let(:post_params) do
        {
          displayName: group_name,
          externalId: scim_group_uid
        }
      end

      subject(:api_request) do
        post api('scim/v2/application/Groups', user, version: '', access_token: scim_token), params: post_params
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      context 'with valid parameters' do
        it 'responds with 201 and the group attributes' do
          api_request

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['id']).to eq(scim_group_uid)
          expect(json_response['displayName']).to eq(group_name)
        end

        it 'updates the existing group link with SCIM group uid' do
          expect { api_request }.to change { saml_group_link.reload.scim_group_uid }.from(nil).to(scim_group_uid)
        end

        context 'with multiple matching group links' do
          let!(:another_group_link) { create(:saml_group_link, saml_group_name: group_name) }

          it 'updates all matching group links' do
            api_request

            expect(saml_group_link.reload.scim_group_uid).to eq(scim_group_uid)
            expect(another_group_link.reload.scim_group_uid).to eq(scim_group_uid)
          end
        end

        context 'when externalId is not provided' do
          let(:post_params) { { displayName: group_name } }

          it 'generates a UUID and creates the group' do
            api_request

            expect(response).to have_gitlab_http_status(:created)

            expect(json_response['id']).to be_present
            expect(json_response['displayName']).to eq(group_name)

            expect(saml_group_link.reload.scim_group_uid).to eq(json_response['id'])
          end
        end
      end

      context 'when no matching SAML group exists' do
        let(:post_params) do
          {
            displayName: 'nonexistent',
            externalId: scim_group_uid
          }
        end

        it 'returns a 412 precondition failed' do
          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
          expect(json_response['detail']).to include('No matching SAML group found')
        end
      end

      context 'with invalid parameters' do
        context 'when displayName is missing' do
          let(:post_params) { { externalId: scim_group_uid } }

          it 'returns a 400 bad request' do
            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to include('displayName is missing')
          end
        end

        context 'when externalId is not a valid UUID' do
          let(:post_params) { { displayName: group_name, externalId: 'not-a-valid-uuid' } }

          it 'returns a 412 precondition failed' do
            api_request

            expect(response).to have_gitlab_http_status(:precondition_failed)
            expect(json_response['detail']).to include('Invalid UUID for scim_group_uid')
          end
        end
      end
    end

    describe 'GET api/scim/v2/application/Groups/:id' do
      let(:scim_group_uid) { SecureRandom.uuid }
      let!(:saml_group_link) do
        create(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
      end

      subject(:api_request) do
        get api("scim/v2/application/Groups/#{scim_group_uid}", user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      context 'with valid SCIM group ID' do
        it 'responds with 200 and the group attributes' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(scim_group_uid)
          expect(json_response['displayName']).to eq(saml_group_link.saml_group_name)
          expect(json_response['schemas']).to eq(['urn:ietf:params:scim:schemas:core:2.0:Group'])
          expect(json_response['meta']['resourceType']).to eq('Group')
        end

        it 'uses the by_scim_group_uid scope' do
          expect(SamlGroupLink).to receive(:by_scim_group_uid).with(scim_group_uid).and_call_original

          api_request
        end

        it 'returns a valid SCIM Group schema' do
          api_request

          expect(json_response).to include(
            'schemas' => ['urn:ietf:params:scim:schemas:core:2.0:Group'],
            'id' => scim_group_uid,
            'displayName' => saml_group_link.saml_group_name,
            'members' => [],
            'meta' => { 'resourceType' => 'Group' }
          )
        end
      end

      context 'when the group has members' do
        let_it_be(:member_user) { create(:user, name: 'Alice Example') }

        let_it_be(:member_identity) do
          create(:scim_identity, user: member_user, group: nil, extern_uid: 'member-extern-uid')
        end

        before do
          create(:scim_group_membership, user: member_user, scim_group_uid: scim_group_uid)
        end

        it 'returns the members as SCIM member objects' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['members']).to contain_exactly(
            { 'value' => 'member-extern-uid', 'display' => 'Alice Example', 'type' => 'User' }
          )
        end
      end

      context 'with non-existent SCIM group ID' do
        let(:non_existent_scim_group) { 123456789 }

        subject(:api_request) do
          get api("scim/v2/application/Groups/#{non_existent_scim_group}", user, version: '', access_token: scim_token)
        end

        it 'returns a 404 not found' do
          api_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['detail']).to include("Group #{non_existent_scim_group} not found")
        end
      end

      context 'with special characters in SCIM group ID' do
        shared_examples 'returns not found' do |uid|
          subject(:api_request) do
            get api("scim/v2/application/Groups/#{ERB::Util.url_encode(uid)}", user, version: '',
              access_token: scim_token)
          end

          it 'returns 404 not found' do
            api_request

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['detail']).to include("Group #{uid} not found")
          end
        end

        it_behaves_like 'returns not found', 'group/with/slashes'
        it_behaves_like 'returns not found', 'group with spaces'
        it_behaves_like 'returns not found', 'group@with@special@chars'
      end

      context 'when multiple groups have the same SCIM group ID' do
        let!(:another_group_link) { create(:saml_group_link, scim_group_uid: scim_group_uid) }

        it 'returns the first matching group' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(scim_group_uid)
        end
      end

      context 'with invalid SCIM group ID format' do
        subject(:api_request) do
          get api("scim/v2/application/Groups/invalid%20id", user, version: '', access_token: scim_token)
        end

        it 'returns a 404 not found' do
          api_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['detail']).to include('Group invalid id not found')
        end
      end
    end

    describe 'GET api/scim/v2/application/Groups' do
      let(:filter_query) { '' }

      subject(:api_request) do
        url = "scim/v2/application/Groups#{filter_query}"
        get api(url, user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      context 'with groups' do
        before do
          create(:saml_group_link, saml_group_name: 'Engineering', scim_group_uid: SecureRandom.uuid)
          create(:saml_group_link, saml_group_name: 'Marketing', scim_group_uid: SecureRandom.uuid)
        end

        it 'responds with groups' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['Resources'].size).to eq(2)

          group_names = json_response['Resources'].pluck('displayName')
          expect(group_names).to match_array(%w[Engineering Marketing])

          expect(json_response['Resources'].first).to include(
            'id' => be_present,
            'displayName' => be_present,
            'schemas' => include('urn:ietf:params:scim:schemas:core:2.0:Group')
          )
        end

        it 'sets values as required by the specification' do
          api_request

          expect(json_response['schemas']).to match_array(['urn:ietf:params:scim:api:messages:2.0:ListResponse'])
          expect(json_response['itemsPerPage']).to be_present
          expect(json_response['startIndex']).to eq(1)
        end

        context 'with filter parameter' do
          let(:filter_query) { '?filter=displayName%20eq%20"Engineering"' }

          it 'returns only matching groups' do
            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['Resources'].size).to eq(1)
            expect(json_response['Resources'][0]['displayName']).to eq('Engineering')
            expect(json_response['totalResults']).to eq(1)
          end

          context 'with unsupported filter format' do
            let(:filter_query) { '?filter=unsupported%20filter' }

            it 'returns an error for unsupported filter' do
              api_request

              expect(response).to have_gitlab_http_status(:precondition_failed)
              expect(json_response['detail']).to eq('Unsupported Filter')
            end
          end
        end

        context 'with no matching groups' do
          let(:filter_query) { '?filter=displayName%20eq%20"NonExistentGroup"' }

          it 'returns empty resources array' do
            api_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['Resources']).to be_empty
            expect(json_response['totalResults']).to eq(0)
          end
        end
      end

      context 'when groups have members' do
        let_it_be(:user_a) { create(:user, name: 'Alice Example') }
        let_it_be(:user_b) { create(:user, name: 'Bob Example') }

        let(:group_uid_1) { SecureRandom.uuid }
        let(:group_uid_2) { SecureRandom.uuid }

        before do
          create(:scim_identity, user: user_a, group: nil, extern_uid: 'extern-a')
          create(:scim_identity, user: user_b, group: nil, extern_uid: 'extern-b')
          create(:saml_group_link, saml_group_name: 'Engineering', scim_group_uid: group_uid_1)
          create(:scim_group_membership, user: user_a, scim_group_uid: group_uid_1)
          create(:scim_group_membership, user: user_b, scim_group_uid: group_uid_1)
        end

        it 'includes members for each group' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          resource = json_response['Resources'].find { |r| r['displayName'] == 'Engineering' }
          expect(resource['members']).to contain_exactly(
            { 'value' => 'extern-a', 'display' => 'Alice Example', 'type' => 'User' },
            { 'value' => 'extern-b', 'display' => 'Bob Example', 'type' => 'User' }
          )
        end

        it 'does not issue additional queries as more groups with members are returned' do
          control = ActiveRecord::QueryRecorder.new do
            get api('scim/v2/application/Groups', user, version: '', access_token: scim_token)
          end

          create(:saml_group_link, saml_group_name: 'Marketing', scim_group_uid: group_uid_2)
          create(:scim_group_membership, user: user_a, scim_group_uid: group_uid_2)
          create(:scim_group_membership, user: user_b, scim_group_uid: group_uid_2)

          expect do
            get api('scim/v2/application/Groups', user, version: '', access_token: scim_token)
          end.not_to exceed_query_limit(control)
        end
      end

      context 'with excludedAttributes parameter' do
        let(:filter_query) { '?excludedAttributes=members,meta' }

        it 'passes excluded attributes to the presenter' do
          expect(::API::Entities::Scim::Groups).to receive(:represent)
            .with(anything, hash_including(excluded_attributes: %w[members meta]))
            .and_call_original

          api_request
        end

        it 'does not fetch members when they are excluded' do
          expect(::Authn::ScimGroupMembership).not_to receive(:members_by_scim_group_uid)

          api_request

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    describe 'PATCH api/scim/v2/application/Groups/:id' do
      let(:scim_group_uid) { SecureRandom.uuid }
      let!(:saml_group_link) do
        create(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
      end

      let!(:identity) { create(:scim_identity, user: create(:user), group: nil) }

      let(:patch_params) do
        {
          schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
          Operations: [
            {
              op: 'Add',
              path: 'members',
              value: [
                { value: identity.extern_uid }
              ]
            }
          ]
        }
      end

      subject(:api_request) do
        patch api("scim/v2/application/Groups/#{scim_group_uid}", user, version: '', access_token: scim_token),
          params: patch_params
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      context 'with add operation' do
        it 'responds with 204 No Content and schedules the worker' do
          expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [identity.user_id], 'add')

          api_request

          expect(response).to have_gitlab_http_status(:no_content)
        end

        context 'with end-to-end behavior' do
          before do
            allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async) do |scim_group_uid, user_ids, operation|
              Authn::SyncScimGroupMembersWorker.new.perform(scim_group_uid, user_ids, operation)
            end
          end

          it 'adds the user to the group' do
            expect { api_request }.to change { saml_group_link.group.users.include?(identity.user) }
              .from(false).to(true)
          end
        end

        context 'with case-insensitive operation matching' do
          let(:patch_params) do
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              Operations: [
                {
                  op: 'ADD',
                  path: 'MEMBERS',
                  value: [
                    { value: identity.extern_uid }
                  ]
                }
              ]
            }
          end

          it 'schedules the worker with correct parameters' do
            expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
              .with(scim_group_uid, [identity.user_id], 'add')

            api_request

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end

        include_context 'with BSO (block seat overages) enabled'
      end

      context 'with remove operation' do
        before do
          saml_group_link.group.add_member(identity.user, Gitlab::Access::DEVELOPER)
        end

        let(:patch_params) do
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
            Operations: [
              {
                op: 'Remove',
                path: 'members',
                value: [
                  { value: identity.extern_uid }
                ]
              }
            ]
          }
        end

        it 'responds with 204 No Content and schedules the worker' do
          expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [identity.user_id], 'remove')

          api_request

          expect(response).to have_gitlab_http_status(:no_content)
        end

        context 'with end-to-end behavior' do
          before do
            allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async) do |scim_group_uid, user_ids, operation|
              Authn::SyncScimGroupMembersWorker.new.perform(scim_group_uid, user_ids, operation)
            end
          end

          it 'removes the user from the group' do
            user = identity.user
            group = saml_group_link.group

            expect(group.member?(user)).to be_truthy

            api_request

            expect(group.member?(user)).to be_falsey
          end
        end

        context 'with case-insensitive operation matching' do
          let(:patch_params) do
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              Operations: [
                {
                  op: 'REMOVE',
                  path: 'MEMBERS',
                  value: [
                    { value: identity.extern_uid }
                  ]
                }
              ]
            }
          end

          it 'schedules the worker with correct parameters' do
            expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
              .with(scim_group_uid, [identity.user_id], 'remove')

            api_request

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end

        context 'with multiple group links sharing the same SCIM ID' do
          let!(:another_group) { create(:group) }
          let!(:another_group_link) do
            create(:saml_group_link,
              group: another_group,
              saml_group_name: 'engineering',
              scim_group_uid: scim_group_uid)
          end

          before do
            another_group.add_member(identity.user, Gitlab::Access::DEVELOPER)

            allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async) do |scim_group_uid, user_ids, operation|
              Authn::SyncScimGroupMembersWorker.new.perform(scim_group_uid, user_ids, operation)
            end
          end

          it 'removes the user from all the linked groups' do
            user = identity.user
            group = saml_group_link.group
            another_group = another_group_link.group

            expect(group.member?(user)).to be_truthy
            expect(another_group.member?(user)).to be_truthy

            api_request

            expect(group.member?(user)).to be_falsey
            expect(another_group.member?(user)).to be_falsey
          end
        end

        context 'with non-existent user identity' do
          let(:patch_params) do
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              Operations: [
                {
                  op: 'Remove',
                  path: 'members',
                  value: [
                    { value: 'non-existent-identity' }
                  ]
                }
              ]
            }
          end

          it 'responds with 204 No Content but does not schedule the worker with user IDs' do
            expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

            api_request

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end
      end

      context 'with invalid operation parameters' do
        context 'with missing operations array' do
          let(:patch_params) do
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp']
            }
          end

          it 'returns a 400 bad request with operation validation error' do
            api_request
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to include('Operations is missing')
          end
        end

        context 'with empty operations array' do
          let(:patch_params) do
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              Operations: []
            }
          end

          it 'returns a 400 bad request with operation validation error' do
            api_request
            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to include('Operations[0][op] is missing')
          end
        end

        context 'with invalid operation type' do
          let(:patch_params) do
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              Operations: [
                {
                  op: 'InvalidOperation',
                  path: 'members',
                  value: [
                    { value: identity.extern_uid }
                  ]
                }
              ]
            }
          end

          it 'returns a 400 bad request with operation validation error' do
            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to include('Operations[0][op] does not have a valid value')
          end
        end

        context 'with missing required parameters' do
          let(:patch_params) do
            {
              schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              Operations: [
                {
                  path: 'members',
                  value: [
                    { value: identity.extern_uid }
                  ]
                }
              ]
            }
          end

          it 'returns a 400 bad request with missing parameter error' do
            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to include('Operations[0][op] is missing')
          end
        end
      end

      context 'with multiple group links sharing the same SCIM ID' do
        let!(:another_group) { create(:group) }
        let!(:another_group_link) do
          create(:saml_group_link,
            group: another_group,
            saml_group_name: 'engineering',
            scim_group_uid: scim_group_uid)
        end

        before do
          allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async) do |scim_group_uid, user_ids, operation|
            Authn::SyncScimGroupMembersWorker.new.perform(scim_group_uid, user_ids, operation)
          end
        end

        it 'adds the user to all linked groups' do
          expect { api_request }.to change {
            saml_group_link.group.users.include?(identity.user) &&
              another_group.users.include?(identity.user)
          }.from(false).to(true)
        end
      end

      context 'with externalId operation' do
        let(:patch_params) do
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
            Operations: [
              {
                op: 'Add',
                path: 'externalId',
                value: 'new-external-id'
              }
            ]
          }
        end

        it 'responds with 204 No Content without scheduling a worker' do
          expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

          api_request

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      context 'with non-existent SCIM group ID' do
        subject(:api_request) do
          patch api("scim/v2/application/Groups/non-existent-id", user, version: '', access_token: scim_token),
            params: patch_params
        end

        it 'returns a 404 not found' do
          api_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['detail']).to include('Group non-existent-id not found')
        end
      end

      context 'with invalid user identity' do
        let(:patch_params) do
          {
            schemas: ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
            Operations: [
              {
                op: 'Add',
                path: 'members',
                value: [
                  { value: 'non-existent-identity' }
                ]
              }
            ]
          }
        end

        it 'responds with 204 No Content without scheduling a worker' do
          expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

          api_request

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end
    end

    describe 'PUT api/scim/v2/application/Groups/:id' do
      let(:scim_group_uid) { SecureRandom.uuid }
      let!(:saml_group_link) do
        create(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
      end

      let!(:identity) { create(:scim_identity, user: create(:user), group: nil) }

      let(:put_params) do
        {
          schemas: ['urn:ietf:params:scim:schemas:core:2.0:Group'],
          displayName: 'Engineering',
          members: [
            { value: identity.extern_uid, display: identity.user.name }
          ]
        }
      end

      subject(:api_request) do
        put api("scim/v2/application/Groups/#{scim_group_uid}", user, version: '', access_token: scim_token),
          params: put_params
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      context 'with valid parameters' do
        it 'responds with 200 OK and the group' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(scim_group_uid)
          expect(json_response['displayName']).to eq('engineering')
        end

        it 'enqueues a job to replace group members' do
          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [identity.user.id], 'replace')
            .once

          api_request
        end

        it 'does not include members in the response' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('id', 'displayName', 'schemas', 'meta')
          expect(json_response).not_to include('members')
        end

        context 'with existing group members not in the PUT request' do
          let!(:other_user) { create(:user) }
          let!(:other_identity) { create(:scim_identity, user: other_user, extern_uid: 'other-extern-uid', group: nil) }

          before do
            create(:identity, user: other_user, provider: 'scim', saml_provider: nil)
            saml_group_link.group.add_member(other_user, Gitlab::Access::DEVELOPER)
          end

          it 'enqueues a job to replace members (removing existing, adding new)' do
            expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
              .with(scim_group_uid, [identity.user.id], 'replace')
              .once

            api_request
          end
        end

        context 'with multiple group links sharing the same SCIM ID' do
          let!(:another_group) { create(:group) }
          let!(:another_group_link) do
            create(:saml_group_link,
              group: another_group,
              saml_group_name: 'engineering',
              scim_group_uid: scim_group_uid)
          end

          it 'enqueues a single job that will handle all linked groups' do
            expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
              .with(scim_group_uid, [identity.user.id], 'replace')
              .once

            api_request
          end
        end

        context 'with non-SCIM members in the group' do
          let!(:regular_user) { create(:user) }

          before do
            saml_group_link.group.add_member(regular_user, Gitlab::Access::DEVELOPER)
          end

          it 'enqueues a job to replace SCIM members (non-SCIM members handled by worker)' do
            expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
              .with(scim_group_uid, [identity.user.id], 'replace')
              .once

            api_request
          end
        end

        include_context 'with BSO (block seat overages) enabled'
      end

      context 'with empty members array' do
        let(:put_params) do
          {
            schemas: ['urn:ietf:params:scim:schemas:core:2.0:Group'],
            displayName: 'Engineering',
            members: []
          }
        end

        before do
          saml_group_link.group.add_member(identity.user, Gitlab::Access::DEVELOPER)
          create(:identity, user: identity.user, provider: 'scim', saml_provider: nil)
        end

        it 'enqueues a job to replace with empty members (removes all SCIM members)' do
          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [], 'replace')
            .once

          api_request
        end
      end

      context 'with non-existent SCIM group ID' do
        subject(:api_request) do
          put api("scim/v2/application/Groups/non-existent-id", user, version: '', access_token: scim_token),
            params: put_params
        end

        it 'returns a 404 not found' do
          api_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['detail']).to include('Group non-existent-id not found')
        end
      end

      context 'with missing required parameters' do
        let(:put_params) do
          {
            schemas: ['urn:ietf:params:scim:schemas:core:2.0:Group']
          }
        end

        it 'returns a 400 bad request' do
          api_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('displayName is missing')
        end
      end

      context 'with non-existent user identities' do
        let(:put_params) do
          {
            schemas: ['urn:ietf:params:scim:schemas:core:2.0:Group'],
            displayName: 'Engineering',
            members: [
              { value: 'non-existent-identity' }
            ]
          }
        end

        it 'responds with 200 OK' do
          api_request

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'enqueues a job to replace with empty user list' do
          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [], 'replace')
            .once

          api_request
        end
      end
    end

    describe 'DELETE api/scim/v2/application/Groups/:id' do
      let(:scim_group_uid) { SecureRandom.uuid }
      let!(:saml_group_link) do
        create(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
      end

      subject(:api_request) do
        delete api("scim/v2/application/Groups/#{scim_group_uid}", user, version: '', access_token: scim_token)
      end

      it_behaves_like 'Not available to SaaS customers'
      it_behaves_like 'Instance level SCIM license required'
      it_behaves_like 'SCIM token authenticated'
      it_behaves_like 'SAML SSO must be enabled'
      it_behaves_like 'sets current organization'

      context 'when SCIM group exists' do
        it 'responds with 204 No Content' do
          api_request

          expect(response).to have_gitlab_http_status(:no_content)
        end

        it 'calls the deletion service' do
          expect(::Gitlab::Scim::GroupSyncDeletionService).to receive(:new)
            .with(scim_group_uid: scim_group_uid)
            .and_call_original

          api_request
        end

        it 'schedules background cleanup' do
          expect(::Authn::CleanupScimGroupMembershipsWorker).to receive(:perform_async).with(scim_group_uid)

          api_request
        end
      end

      context 'when SCIM group does not exist' do
        let(:non_existent_scim_group) { SecureRandom.uuid }

        subject(:api_request) do
          delete api("scim/v2/application/Groups/#{non_existent_scim_group}", user, version: '',
            access_token: scim_token)
        end

        it 'returns 404 without calling the service' do
          expect(::Gitlab::Scim::GroupSyncDeletionService).not_to receive(:new)

          api_request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['detail']).to include("Group #{non_existent_scim_group} not found")
        end
      end

      context 'when service returns error' do
        before do
          allow_next_instance_of(::Gitlab::Scim::GroupSyncDeletionService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Database error'))
          end
        end

        it 'returns 412 precondition failed' do
          api_request

          expect(response).to have_gitlab_http_status(:precondition_failed)
          expect(json_response['detail']).to include('Database error')
        end
      end
    end
  end
end

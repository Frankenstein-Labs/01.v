# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::LdapGroupLinks, :api, feature_category: :system_access do
  include ApiHelpers

  shared_examples 'resets the stale ldap flag on last link removal' do
    let_it_be(:orphan_group) { create(:group, owners: owner) }
    let_it_be(:orphan_link) do
      orphan_group.ldap_group_links.create!(cn: 'orphan-group', group_access: Gitlab::Access::MAINTAINER, provider: 'ldapmain')
    end

    let_it_be(:member_user) { create(:user) }
    let_it_be_with_reload(:orphaned_member) { create(:group_member, :developer, group: orphan_group, user: member_user, ldap: true) }
    let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

    it "resets the ldap flag for members orphaned by the removal" do
      expect { delete_request }.to change { orphaned_member.reload.ldap? }.from(true).to(false)
    end
  end

  let_it_be(:owner) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let_it_be(:group_with_ldap_links) { create(:group) }
  let_it_be(:group_with_no_ldap_links) { create(:group) }

  let_it_be(:member_role) { create(:member_role, :guest, namespace: group_with_ldap_links) }

  before_all do
    group_with_ldap_links.ldap_group_links.create! cn: 'ldap-group1', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap1'
    group_with_ldap_links.ldap_group_links.create! cn: 'ldap-group2', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap2'
    group_with_ldap_links.ldap_group_links.create! cn: 'ldap-group3', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap2'
    group_with_ldap_links.ldap_group_links.create! cn: 'ldap-group4', group_access: Gitlab::Access::GUEST, member_role_id: member_role.id, provider: 'ldap2'
    group_with_ldap_links.ldap_group_links.create! filter: '(uid=mary)', group_access: Gitlab::Access::DEVELOPER, provider: 'ldap2'
    group_with_ldap_links.ldap_group_links.create! filter: '(uid=john)', group_access: Gitlab::Access::GUEST, member_role_id: member_role.id, provider: 'ldap2'

    group_with_ldap_links.add_owner owner
    group_with_ldap_links.add_member user, Gitlab::Access::DEVELOPER
    group_with_no_ldap_links.add_owner owner
  end

  describe "GET /groups/:id/ldap_group_links" do
    context "when unauthenticated" do
      it "returns authentication error" do
        get api("/groups/#{group_with_ldap_links.id}/ldap_group_links")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "when a less priviledged user" do
      it "returns forbidden" do
        get api("/groups/#{group_with_ldap_links.id}/ldap_group_links", user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when owner of the group but group owners cannot manage LDAP" do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: false)
      end

      it "returns forbidden" do
        get api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when owner of the group" do
      it_behaves_like 'authorizing granular token permissions', :read_ldap_group_link do
        let(:user) { owner }
        let(:boundary_object) { group_with_ldap_links }
        let(:request) do
          get api("/groups/#{group_with_ldap_links.id}/ldap_group_links", personal_access_token: pat)
        end
      end

      it "returns ldap group links" do
        get api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to(
          match([
            a_hash_including('cn' => 'ldap-group1', 'group_access' => 40, 'provider' => 'ldap1'),
            a_hash_including('cn' => 'ldap-group2', 'group_access' => 40, 'provider' => 'ldap2'),
            a_hash_including('cn' => 'ldap-group3', 'group_access' => 40, 'provider' => 'ldap2'),
            a_hash_including('cn' => 'ldap-group4', 'group_access' => 10, 'provider' => 'ldap2'),
            a_hash_including('cn' => nil, 'group_access' => 30, 'provider' => 'ldap2'),
            a_hash_including('cn' => nil, 'group_access' => 10, 'provider' => 'ldap2')
          ]))
      end

      context "when custom roles is enabled" do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it "returns ldap group links with their member_roles" do
          get api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to(
            match([
              a_hash_including('cn' => 'ldap-group1', 'group_access' => 40, 'provider' => 'ldap1'),
              a_hash_including('cn' => 'ldap-group2', 'group_access' => 40, 'provider' => 'ldap2'),
              a_hash_including('cn' => 'ldap-group3', 'group_access' => 40, 'provider' => 'ldap2'),
              a_hash_including('cn' => 'ldap-group4', 'group_access' => 10, 'member_role_id' => member_role.id, 'provider' => 'ldap2'),
              a_hash_including('cn' => nil, 'group_access' => 30, 'provider' => 'ldap2'),
              a_hash_including('cn' => nil, 'group_access' => 10, 'member_role_id' => member_role.id, 'provider' => 'ldap2')
            ]))
        end
      end

      it "returns error if no ldap group links found" do
        get api("/groups/#{group_with_no_ldap_links.id}/ldap_group_links", owner)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe "POST /groups/:id/ldap_group_links" do
    shared_examples 'creates LDAP group link' do
      context "when unauthenticated" do
        it "returns authentication error" do
          params_test = params.merge({ group_access: GroupMember::GUEST, provider: 'ldap3' })
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links"), params: params_test

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when a less priviledged user" do
        it "does not allow less priviledged user to add LDAP group link" do
          params_test = params.merge({ group_access: GroupMember::GUEST, provider: 'ldap3' })
          expect do
            post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", user), params: params_test
          end.not_to change { group_with_ldap_links.ldap_group_links.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context "when owner of the group" do
        it_behaves_like 'authorizing granular token permissions', :create_ldap_group_link do
          let(:user) { owner }
          let(:boundary_object) { group_with_ldap_links }
          let(:request) do
            post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", personal_access_token: pat),
              params: params.merge({ group_access: GroupMember::GUEST, provider: 'ldap3' })
          end
        end

        it "returns ok and add ldap group link" do
          params_test = params.merge({ group_access: GroupMember::GUEST, provider: 'ldap3' })

          expect do
            post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test
          end.to change { group_with_ldap_links.ldap_group_links.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['cn']).to eq(params_test[:cn])
          expect(json_response['filter']).to eq(params_test[:filter])
          expect(json_response['group_access']).to eq(params_test[:group_access])
          expect(json_response['provider']).to eq(params_test[:provider])
        end

        it "returns error if LDAP group link already exists" do
          params_test = params.merge({ group_access: GroupMember::GUEST, provider: 'ldap2' })
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

          expect(response).to have_gitlab_http_status(:conflict)
        end

        it "returns a 400 error when CN or filter is not given" do
          params_test = { group_access: GroupMember::GUEST, provider: 'ldap1' }
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it "returns a 400 error when group access is not given" do
          params_test = params.merge({ provider: 'ldap1' })
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it "returns a 422 error when group access is not valid" do
          params_test = params.merge({ group_access: 11, provider: 'ldap1' })
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('group_access does not have a valid value')
        end
      end
    end

    context "adding a group link via CN" do
      it_behaves_like 'creates LDAP group link' do
        let(:params) { { cn: 'ldap-group3' } }
      end

      context 'and with a member_role' do
        let(:params) { { cn: 'ldap-group3', member_role_id: member_role.id } }
        let(:params_test) { params.merge({ group_access: GroupMember::GUEST, provider: 'ldap3' }) }

        context 'when custom roles is enabled' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          it_behaves_like 'creates LDAP group link'

          it 'returns ldap group link with the member_role' do
            post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

            expect(json_response['member_role_id']).to eq(params_test[:member_role_id])
          end
        end

        context 'when custom roles is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it_behaves_like 'creates LDAP group link'

          it 'returns ldap group link without the member_role' do
            post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

            expect(json_response['member_role_id']).to be_nil
          end
        end
      end
    end

    context "adding a group link via filter" do
      context "when ldap_group_sync_filter feature is available" do
        before do
          stub_licensed_features(ldap_group_sync_filter: true)
        end

        it_behaves_like 'creates LDAP group link' do
          let(:params) { { filter: '(uid=mary)' } }
        end

        context 'and with a member_role' do
          let(:params) { { filter: '(uid=john)', member_role_id: member_role.id } }
          let(:params_test) { params.merge({ group_access: GroupMember::GUEST, provider: 'ldap3' }) }

          context 'when custom roles is enabled' do
            before do
              stub_licensed_features(ldap_group_sync_filter: true, custom_roles: true)
            end

            it_behaves_like 'creates LDAP group link'

            it 'returns ldap group link with the member_role' do
              post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

              expect(json_response['member_role_id']).to eq(params_test[:member_role_id])
            end
          end

          context 'when custom roles is disabled' do
            before do
              stub_licensed_features(ldap_group_sync_filter: true, custom_roles: false)
            end

            it_behaves_like 'creates LDAP group link'

            it 'returns ldap group link without the member_role' do
              post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params_test

              expect(json_response['member_role_id']).to be_nil
            end
          end
        end
      end

      context 'feature is not available' do
        before do
          stub_licensed_features(ldap_group_sync_filter: false)
        end

        it 'returns 404' do
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: { filter: '(uid=mary)', group_access: GroupMember::GUEST, provider: 'ldap3' }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    it 'allows creating Minimal Access group access LDAP group links' do
      expect do
        post(
          api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner),
          params: {
            cn: 'ldap-group',
            group_access: ::Gitlab::Access::MINIMAL_ACCESS,
            provider: 'ldap2'
          }
        )
      end.to change { group_with_ldap_links.ldap_group_links.count }.by(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['group_access']).to eq(::Gitlab::Access::MINIMAL_ACCESS)
    end

    it 'denies creating random group access LDAP group links' do
      expect do
        post(
          api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner),
          params: {
            cn: 'ldap-group',
            group_access: 111,
            provider: 'ldap2'
          }
        )
      end.not_to change { group_with_ldap_links.ldap_group_links.count }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to eq('group_access does not have a valid value')
    end

    context "when owner of the group but group owners cannot manage LDAP" do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: false)
      end

      it "does not allow the owner to add a LDAP group link" do
        expect do
          post(
            api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner),
            params: { cn: 'ldap-group3', group_access: GroupMember::GUEST, provider: 'ldap3' }
          )
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /groups/:id/ldap_group_links/:cn' do
    context "when unauthenticated" do
      it "returns authentication error" do
        delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1")
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "when a less priviledged user" do
      it "does not remove the LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1", user)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when owner of the group but group owners cannot manage LDAP" do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: false)
      end

      it "does not remove the LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1", owner)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when owner of the group" do
      it_behaves_like 'authorizing granular token permissions', :delete_ldap_group_link do
        let(:user) { owner }
        let(:boundary_object) { group_with_ldap_links }
        let(:request) do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1", personal_access_token: pat)
        end
      end

      it "removes ldap group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1", owner)

          expect(response).to have_gitlab_http_status(:no_content)
        end.to change { group_with_ldap_links.ldap_group_links.count }.by(-1)
      end

      it "returns 404 if LDAP group cn not used for a LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1356", owner)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context "when it was the last link for that provider" do
        it_behaves_like 'resets the stale ldap flag on last link removal' do
          let(:delete_request) { delete api("/groups/#{orphan_group.id}/ldap_group_links/orphan-group", owner) }
        end
      end
    end
  end

  describe 'DELETE /groups/:id/ldap_group_links/:provider/:cn' do
    context "when unauthenticated" do
      it "returns authentication error" do
        delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2")
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "when a less priviledged user" do
      it "does not remove the LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2", user)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when owner of the group but group owners cannot manage LDAP" do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: false)
      end

      it "does not remove the LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2", owner)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when owner of the group" do
      it_behaves_like 'authorizing granular token permissions', :delete_ldap_group_link do
        let(:user) { owner }
        let(:boundary_object) { group_with_ldap_links }
        let(:request) do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2",
            personal_access_token: pat)
        end
      end

      it "returns 404 if LDAP group cn not used for a LDAP group link for the specified provider" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap1/ldap-group2", owner)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it "removes ldap group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2", owner)

          expect(response).to have_gitlab_http_status(:no_content)
        end.to change { group_with_ldap_links.ldap_group_links.count }.by(-1)
      end

      context "when it was the last link for that provider" do
        it_behaves_like 'resets the stale ldap flag on last link removal' do
          let(:delete_request) { delete api("/groups/#{orphan_group.id}/ldap_group_links/ldapmain/orphan-group", owner) }
        end
      end
    end
  end

  describe 'DELETE /groups/:id/ldap_group_links' do
    shared_examples 'deletes LDAP group link' do
      context "when unauthenticated" do
        it "returns authentication error" do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links"), params: params
          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when a less priviledged user" do
        it "does not remove the LDAP group link" do
          expect do
            delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links", user), params: params
          end.not_to change { group_with_ldap_links.ldap_group_links.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context "when owner of the group" do
        it_behaves_like 'authorizing granular token permissions', :delete_ldap_group_link do
          let(:user) { owner }
          let(:boundary_object) { group_with_ldap_links }
          let(:request) do
            delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links", personal_access_token: pat),
              params: params
          end
        end

        it "removes ldap group link" do
          expect do
            delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params

            expect(response).to have_gitlab_http_status(:no_content)
          end.to change { group_with_ldap_links.ldap_group_links.count }.by(-1)
        end
      end
    end

    shared_examples 'group link is not found' do
      context "when owner of the group" do
        it "returns 404 if LDAP input not used for a LDAP group link" do
          expect do
            delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: params
          end.not_to change { group_with_ldap_links.ldap_group_links.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context "deleting a group link via CN and provider" do
      it_behaves_like 'deletes LDAP group link' do
        let(:params) { { cn: 'ldap-group3', provider: 'ldap2' } }
      end

      it_behaves_like 'group link is not found' do
        let(:params) { { cn: 'ldap-group1356', provider: 'ldap2' } }
      end
    end

    context "deleting a group link via filter and provider" do
      context "feature is available" do
        before do
          stub_licensed_features(ldap_group_sync_filter: true)
        end

        it_behaves_like 'deletes LDAP group link' do
          let(:params) { { filter: '(uid=mary)', provider: 'ldap2' } }
        end

        it_behaves_like 'group link is not found' do
          let(:params) { { filter: '(uid=mary3)', provider: 'ldap1' } }
        end
      end

      context 'feature is not available' do
        before do
          stub_licensed_features(ldap_group_sync_filter: false)
        end

        it 'returns 404' do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: { filter: '(uid=mary)', provider: 'ldap1' }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context "when owner of the group but group owners cannot manage LDAP" do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: false)
      end

      it "does not remove the LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner),
            params: { cn: 'ldap-group3', provider: 'ldap2' }
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when it was the last link for that provider" do
      it_behaves_like 'resets the stale ldap flag on last link removal' do
        let(:delete_request) do
          delete api("/groups/#{orphan_group.id}/ldap_group_links", owner), params: { cn: 'orphan-group', provider: 'ldapmain' }
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::GroupMembersController, feature_category: :groups_and_projects do
  include ExternalAuthorizationServiceHelpers

  let(:user)  { create(:user) }
  let(:group) { create(:group, :public) }

  before do
    group.add_owner(user)
    sign_in(user)
  end

  describe 'GET /groups/*group_id/-/group_members' do
    let(:params) { {} }

    subject(:get_group_members) do
      get group_group_members_path(group_id: group), params: params
    end

    context 'with banned members' do
      let(:banned_member) { create(:group_member, :developer, group: group) }
      let(:licensed_feature_available) { true }

      before do
        stub_licensed_features(unique_project_download_limit: licensed_feature_available)

        create(:namespace_ban, namespace: group, user: banned_member.user)
      end

      it 'sets @banned to include banned group members' do
        get_group_members

        expect(assigns(:banned).map(&:user_id)).to contain_exactly(banned_member.user.id)
      end

      it 'sets @members not to include banned group members' do
        get_group_members

        expect(assigns(:members).map(&:user_id)).not_to include(banned_member.user.id)
      end

      shared_examples 'assigns @banned and @members correctly' do
        it 'does not assign @banned' do
          get_group_members

          expect(assigns(:banned)).to be_nil
        end

        it 'sets @members to include banned group members' do
          get_group_members

          expect(assigns(:members).map(&:user_id)).to include(banned_member.user.id)
        end
      end

      context 'when licensed feature is not available' do
        let(:licensed_feature_available) { false }

        it_behaves_like 'assigns @banned and @members correctly'
      end

      context 'when sub-group' do
        before do
          group.update!(parent: create(:group))
        end

        it_behaves_like 'assigns @banned and @members correctly'
      end
    end

    context 'with member pending promotions' do
      let!(:pending_member_approvals) do
        create_list(:gitlab_subscription_member_management_member_approval, 2, :for_group_member, member_namespace: group)
      end

      let(:feature_settings) { true }
      let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      before do
        stub_application_setting(enable_member_promotion_management: feature_settings)
        allow(License).to receive(:current).and_return(license)
      end

      context 'with member_promotion management feature enabled' do
        context 'when user can admin group' do
          it 'assigns @pending_promotion_members_count with the correct pending members' do
            get_group_members

            expect(assigns(:pending_promotion_members_count)).to eq(2)
          end
        end

        context 'when user cannot admin group' do
          before do
            group.add_developer(user)
          end

          it 'does not assigns @pending_promotion_members_count' do
            get_group_members

            expect(assigns(:pending_promotion_members_count)).to be_nil
          end
        end
      end

      shared_examples "empty response" do
        it 'assigns @pending_promotion_members_count to be 0' do
          get_group_members

          expect(assigns(:pending_promotion_members_count)).to eq(0)
        end
      end

      context 'with member_promotion management feature setting disabled' do
        let(:feature_settings) { false }

        it_behaves_like "empty response"
      end

      context 'when license is not Ultimate' do
        let(:license) { create(:license, plan: License::STARTER_PLAN) }

        it_behaves_like "empty response"
      end
    end

    it 'avoids N+1 grabbing oncall_schedules and escalation_policies' do
      create(:project, group: group)

      recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { get group_group_members_path(group_id: group), params: params }
      method_invocations = recorder.find_query('app/serializers/base_serializer.rb', 0)

      expect(method_invocations.count).to eq(1)
    end
  end

  describe 'PUT /groups/*group_id/-/group_members/:id/ban' do
    let(:member) { create(:group_member, :developer, group: group) }

    subject(:ban_group_member) do
      put ban_group_group_member_path(group_id: group, id: member)
    end

    before do
      stub_licensed_features(unique_project_download_limit: true)
    end

    context 'when current user is an owner' do
      it 'bans the user' do
        expected_args = { current_user: user, user: member.user, namespace: group }
        expect_next_instance_of(::Users::Abuse::NamespaceBans::CreateService, expected_args) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        ban_group_member
      end

      it 'redirects back to group members page' do
        ban_group_member

        expect(response).to redirect_to(group_group_members_path)
        expect(flash[:notice]).to eq "User was successfully banned."
      end

      context 'when ban fails' do
        let(:error_message) { 'Ban failed' }

        before do
          expected_args = { current_user: user, user: member.user, namespace: group }

          allow_next_instance_of(::Users::Abuse::NamespaceBans::CreateService, expected_args) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
          end
        end

        it 'redirects back to group members page with the error message as alert' do
          ban_group_member

          expect(response).to redirect_to(group_group_members_path(group))
          expect(flash[:alert]).to eq error_message
        end
      end
    end

    context 'when current user is not an owner' do
      before do
        group.add_maintainer(user)
      end

      it 'returns 403' do
        ban_group_member

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when current user is not an owner but can admin_group_member' do
      before do
        stub_licensed_features(custom_roles: true)
        group.add_guest(user).update!(member_role: admin_group_member_role)
      end

      let(:admin_group_member_role) { create(:member_role, :guest, namespace: group, admin_group_member: true) }

      it 'returns 403' do
        ban_group_member

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /groups/*group_id/-/group_members/:id/unban' do
    let(:banned_member) { create(:group_member, :developer, group: group) }
    let!(:namespace_ban) { create(:namespace_ban, namespace: group, user: banned_member.user) }

    subject(:unban_group_member) do
      put unban_group_group_member_path(group_id: group, id: banned_member)
    end

    context 'when current user is an owner' do
      shared_examples 'unbans the user' do
        it 'unbans the user' do
          expect_next_instance_of(::Users::Abuse::NamespaceBans::DestroyService, namespace_ban, user) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          unban_group_member
        end

        it 'redirects back to banned group members page' do
          unban_group_member

          expect(response).to redirect_to(group_group_members_path(group, tab: 'banned'))
          expect(flash[:notice]).to eq "User was successfully unbanned."
        end
      end

      it_behaves_like 'unbans the user'

      context 'when unbanning a subgroup member' do
        let(:subgroup) { create(:group, parent: group) }
        let(:banned_member) { create(:group_member, group: subgroup) }
        let(:namespace_ban) { create(:namespace_ban, namespace: group, user: banned_member.user) }

        it_behaves_like 'unbans the user'
      end

      context 'when member is not banned' do
        before do
          namespace_ban.destroy!
        end

        it 'returns 404' do
          unban_group_member

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when unban fails' do
        let(:error_message) { 'Unban failed' }

        before do
          allow_next_instance_of(::Users::Abuse::NamespaceBans::DestroyService, namespace_ban, user) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
          end
        end

        it 'redirects back to banned group members page with the error message as alert' do
          unban_group_member

          expect(response).to redirect_to(group_group_members_path(group, tab: 'banned'))
          expect(flash[:alert]).to eq error_message
        end
      end
    end

    context 'when user is not an owner' do
      before do
        group.add_maintainer(user)
      end

      it 'returns 404' do
        unban_group_member

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when LDAP sync is enabled for the group' do
      before do
        allow_next_found_instance_of(Group) do |instance|
          allow(instance).to receive(:ldap_synced?).and_return(true)
        end
      end

      it 'still allows the owner to unban the user' do
        expect_next_instance_of(::Users::Abuse::NamespaceBans::DestroyService, namespace_ban, user) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        unban_group_member

        expect(response).to redirect_to(group_group_members_path(group, tab: 'banned'))
      end
    end
  end

  describe 'PUT /groups/*group_id/-/group_members/:id' do
    context 'when group has email domain feature enabled' do
      let(:email) { 'test@gitlab.com' }
      let(:member_user) { create(:user, email: email) }
      let!(:member) { group.add_guest(member_user) }

      let(:params) { { group_member: { access_level: 50 } } }

      before do
        stub_licensed_features(group_allowed_email_domains: true)

        create(:allowed_email_domain, group: group)
      end

      subject(:invite) do
        put group_group_member_path(group_id: group, id: member.id), xhr: true, params: params
      end

      context 'for a user with an email belonging to the allowed domain' do
        it 'returns error status' do
          invite

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'for a user with an un-verified email belonging to a domain different from the allowed domain' do
        let(:email) { 'test@gmail.com' }

        it 'returns error status' do
          invite

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end

        it 'returns error message' do
          invite

          expect(json_response['message']).to eq("The member's email address is not allowed for this group. Check with your administrator.")
        end
      end
    end

    context 'with block seat overages enabled', :saas do
      before do
        create(:gitlab_subscription, :ultimate, namespace: group, seats: 1)
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      it 'rejects promoting a member if there is no billable seat available' do
        member = group.add_guest(create(:user))
        params = { group_member: { access_level: ::Gitlab::Access::DEVELOPER } }

        put group_group_member_path(group_id: group, id: member.id), xhr: true, params: params

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq('Could not update role because there are no available seats in this group')
        expect(member.reload.access_level).to eq(::Gitlab::Access::GUEST)
      end

      it 'promotes a member if there is a billable seat available' do
        group.gitlab_subscription.update!(seats: 2)
        member = group.add_guest(create(:user))
        params = { group_member: { access_level: ::Gitlab::Access::DEVELOPER } }

        put group_group_member_path(group_id: group, id: member.id), xhr: true, params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).not_to include('message')
        expect(member.reload.access_level).to eq(::Gitlab::Access::DEVELOPER)
      end
    end
  end

  describe "GET /groups/*group_id/-/group_members/export_csv" do
    before do
      stub_licensed_features(export_user_permissions: true)
    end

    subject(:export) do
      get export_csv_group_group_members_path(group)
    end

    it 'redirects back to members list' do
      export

      expect(response).to redirect_to(group_group_members_path(group))
    end

    context 'when not signed in' do
      before do
        sign_out(user)
      end

      it 'renders 404' do
        export

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when LDAP sync is enabled' do
      before do
        allow_next_found_instance_of(Group) do |instance|
          allow(instance).to receive(:ldap_synced?).and_return(true)
        end
      end

      it 'redirects back to members list' do
        export

        expect(response).to redirect_to(group_group_members_path(group))
      end
    end
  end

  describe "POST /groups/*group_id/-/group_members/:id/approve_access_request" do
    context 'when block seat overages is enabled', :saas do
      let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:member) { create(:group_member, :access_request, :developer, group: group) }

      before do
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      it 'provides a flash message when not enough seats are available' do
        group.gitlab_subscription.update!(seats: 1)

        post approve_access_request_group_group_member_path(group_id: group, id: member)

        expect(response).to redirect_to(group_group_members_path)
        expect(flash[:alert]).to eq('No seat available')
      end
    end
  end
end

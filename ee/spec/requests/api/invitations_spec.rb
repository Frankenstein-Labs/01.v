# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Invitations, 'EE Invitations', :aggregate_failures, feature_category: :user_profile do
  include GroupAPIHelpers

  let_it_be(:admin) { create(:user, :admin, email: 'admin@example.com') }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:member_role) { create(:member_role, :guest, :instance) }
  let_it_be(:user) { create(:user) }

  let(:url) { "/groups/#{group.id}/invitations" }
  let(:invite_email) { 'restricted@example.org' }

  shared_examples 'restricted email error' do |message, code|
    it 'returns an http error response and the validation message' do
      post api(url, admin, admin_mode: true),
        params: { email: invite_email, access_level: Member::MAINTAINER }

      expect(response).to have_gitlab_http_status(code)
      expect(json_response['message'][invite_email]).to eq message
    end
  end

  shared_examples 'admin signup restrictions email error - denylist' do |message, code|
    before do
      stub_application_setting(domain_denylist_enabled: true)
      stub_application_setting(domain_denylist: ['example.org'])
    end

    it_behaves_like 'restricted email error', message, code
  end

  shared_examples 'admin signup restrictions email error - allowlist' do |message, code|
    before do
      stub_application_setting(domain_allowlist: ['example.com'])
    end

    it_behaves_like 'restricted email error', message, code
  end

  shared_examples 'admin signup restrictions email error - email restrictions' do |message, code|
    before do
      stub_application_setting(email_restrictions_enabled: true)
      stub_application_setting(email_restrictions: '([\+]|\b(\w*example.org\w*)\b)')
    end

    it_behaves_like 'restricted email error', message, code
  end

  shared_examples 'member creation audit event' do
    it 'creates an audit event while creating a new member' do
      params = { email: 'example1@example.com', access_level: Member::DEVELOPER }

      expect do
        post api(url, admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:created)
      end.to change { AuditEventReader.count }.by(1)
    end

    it 'does not create audit event if creating a new member fails' do
      params = { email: '_bogus_', access_level: Member::DEVELOPER }

      expect do
        post api(url, admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
      end.not_to change { AuditEventReader.count }
    end
  end

  shared_examples 'member role assignment during creation' do
    let(:params) do
      { email: invite_email, access_level: Member::GUEST, member_role_id: member_role.id }
    end

    subject(:invite_custom_member) { post api(url, admin, admin_mode: true), params: params }

    context 'with custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'returns success' do
        invite_custom_member

        expect(response).to have_gitlab_http_status(:created)
      end

      it 'creates a new member correctly' do
        expect { invite_custom_member }.to change { source.members.count }.by(1)

        member = Member.last

        expect(member.member_role).to eq(member_role)
        expect(member.access_level).to eq(Member::GUEST)
      end
    end

    context 'without custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'returns success' do
        invite_custom_member

        expect(response).to have_gitlab_http_status(:created)
      end

      it 'creates a new member without the member role' do
        expect { invite_custom_member }.to change { source.members.count }.by(1)

        member = Member.last

        expect(member.member_role).to be_nil
        expect(member.access_level).to eq(Member::GUEST)
      end
    end
  end

  shared_examples 'member role assignment during update' do
    let(:params) do
      { member_role_id: member_role.id }
    end

    subject(:update_custom_member) { put api(url, admin, admin_mode: true), params: params }

    context 'with custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'returns success' do
        update_custom_member

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'updates the invited member correctly' do
        expect { update_custom_member }.to change { member.reload.member_role_id }
          .to(member_role.id)
      end
    end

    context 'without custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'returns success' do
        update_custom_member

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not update the member role' do
        expect { update_custom_member }.not_to change { member.reload.member_role_id }
      end
    end
  end

  describe 'POST /groups/:id/invitations' do
    it_behaves_like 'member creation audit event'
    it_behaves_like 'admin signup restrictions email error - denylist', "The member's email address is not allowed for this group. Go to the &#39;Admin area &gt; New user account restrictions&#39;, and check the &#39;Domain denylist&#39;.", :created

    it_behaves_like 'POST request permissions for admin mode' do
      let(:path) { url }
      let(:params) { { email: 'example1@example.com', access_level: Member::DEVELOPER } }
    end

    context 'when the group is restricted by admin signup restrictions' do
      it_behaves_like 'admin signup restrictions email error - allowlist', "The member's email address is not allowed for this group. Go to the &#39;Admin area &gt; New user account restrictions&#39;, and check &#39;Domains allowed for new users&#39;.", :created
      it_behaves_like 'admin signup restrictions email error - email restrictions', "The member's email address is not allowed for this group. Go to the &#39;Admin area &gt; New user account restrictions&#39;, and check &#39;Email restrictions for new users&#39;.", :created
    end

    context 'when the group is restricted by group signup restriction - allowed domains for signup' do
      before do
        stub_licensed_features(group_allowed_email_domains: true)
        create(:allowed_email_domain, group: group, domain: 'example.com')
      end

      it_behaves_like 'restricted email error', "The member's email address is not allowed for this group. Go to the group’s &#39;Settings &gt; General&#39; page, and check &#39;Restrict membership by email domain&#39;.", :success
    end

    context 'when block seat overages is enabled for the group', :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:owner) { create(:user) }
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_owner(owner)
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      it 'adds the member when there are open seats in the subscription' do
        post api(url, owner), params: { access_level: Member::DEVELOPER, user_id: user.id }

        expect(group.members.map(&:user_id)).to contain_exactly(owner.id, user.id)
        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to eq({ 'status' => 'success' })
      end

      it 'rejects the member when there are not enough seats in the subscription' do
        group.gitlab_subscription.update!(seats: 1)

        post api(url, owner), params: { access_level: Member::DEVELOPER, user_id: user.id }

        expect(group.members.map(&:user_id)).to contain_exactly(owner.id)
        expect(json_response).to eq({
          'status' => 'error',
          'message' => 'There are not enough available seats to invite this many users.',
          'reason' => 'seat_limit_exceeded_error'
        })
      end

      it 'rejects an email invite' do
        group.gitlab_subscription.update!(seats: 1)

        post api(url, owner), params: { access_level: Member::DEVELOPER, email: 'guy@example.com' }

        expect(group.members.map(&:user_id)).to contain_exactly(owner.id)
        expect(json_response).to eq({
          'status' => 'error',
          'message' => 'There are not enough available seats to invite this many users.',
          'reason' => 'seat_limit_exceeded_error'
        })
      end
    end

    context 'when billable promotion management is enabled for the group' do
      let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
      let_it_be(:owner) { create(:user) }
      let_it_be(:new_user) { create(:user) }
      let(:user) { new_user }
      let(:source) { group }
      let(:access_level) { Gitlab::Access::DEVELOPER }

      before do
        source.add_owner(owner)

        stub_application_setting(enable_member_promotion_management: true)
        allow(License).to receive(:current).and_return(license)
      end

      subject(:post_invitations) do
        post api(url, owner), params: { access_level: access_level, user_id: user.id }
      end

      shared_examples "posts invitation successfully" do
        it 'adds member' do
          post_invitations

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to eq({
            'status' => 'success'
          })
        end
      end

      context 'on self managed' do
        context 'when setting is disabled' do
          before do
            stub_application_setting(enable_member_promotion_management: false)
          end

          it_behaves_like "posts invitation successfully"
        end

        context 'when license is not Ultimate' do
          let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

          it_behaves_like "posts invitation successfully"
        end

        shared_examples 'queues user invite for admin approval' do
          it 'queues request' do
            post_invitations

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response).to eq({
              'status' => 'success',
              'queued_users' => {
                user.username => 'Request queued for administrator approval.'
              }
            })
          end
        end

        context 'with new user' do
          context 'when trying to add billable member' do
            it_behaves_like 'queues user invite for admin approval'
          end

          context 'when trying to add a non billable member' do
            let(:access_level) { Gitlab::Access::GUEST }

            it_behaves_like 'posts invitation successfully'
          end
        end

        context 'with existing members' do
          let(:existing_member) { create(:group_member, existing_role, source: source) }

          let(:user) { existing_member.user }

          context 'when trying to change to a billable role' do
            let(:access_level) { Gitlab::Access::MAINTAINER }

            context 'when user is non billable' do
              let(:existing_role) { :guest }

              it_behaves_like 'queues user invite for admin approval'
            end

            context 'when user is billable' do
              let(:existing_role) { :developer }

              it_behaves_like 'posts invitation successfully'
            end
          end

          context 'when trying to change to a non billable role' do
            let(:access_level) { Gitlab::Access::GUEST }

            context 'when user is billable' do
              let(:existing_role) { :maintainer }

              it_behaves_like 'posts invitation successfully'
            end
          end
        end
      end

      context 'on saas', :saas do
        it_behaves_like "posts invitation successfully"
      end
    end

    context 'with free user cap considerations', :saas do
      let_it_be_with_reload(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)
      end

      subject(:post_invitations) do
        post api(url, admin, admin_mode: true),
          params: { email: invite_email, access_level: Member::MAINTAINER }
      end

      shared_examples 'does not add members' do
        it 'does not add the member' do
          expect do
            post_invitations
          end.not_to change { group.members.count }

          msg = "cannot be added since you've reached your #{::Namespaces::FreeUserCap.dashboard_limit} " \
                "member limit for #{group.name}"
          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['status']).to eq('error')
          expect(json_response['message'][invite_email]).to eq(msg)
        end
      end

      context 'when there are at the size limit' do
        it_behaves_like 'does not add members'
      end

      context 'when there are over the size limit' do
        before do
          stub_ee_application_setting(dashboard_limit: 3) # allow us to add a user/member
          group.add_developer(create(:user))
          stub_ee_application_setting(dashboard_limit: 0) # set us up to now be over
        end

        it_behaves_like 'does not add members'
      end

      context 'when there is a seat left' do
        before do
          stub_ee_application_setting(dashboard_limit: 3)
        end

        it 'creates a member' do
          expect { post_invitations }.to change { group.members.count }.by(1)
          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['status']).to eq('success')
        end
      end

      context 'when there are seats left and we add enough to exhaust all seats' do
        before do
          stub_ee_application_setting(dashboard_limit: 1)
        end

        it 'creates one member and errors on the other member', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/3565' do
          expect do
            stranger = create(:user)
            stranger2 = create(:user)
            user_id_list = "#{stranger.id},#{stranger2.id}"

            post api(url, admin, admin_mode: true), params: { user_id: user_id_list, access_level: Member::DEVELOPER }

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['status']).to eq('error')
            expect(json_response['message'][stranger2.username]).to match(/cannot be added since you've reached your/)
          end.to change { group.members.count }.by(1)
        end
      end
    end

    context 'with minimal access level' do
      before do
        stub_licensed_features(minimal_access_role: true)
      end

      context 'when group has no parent' do
        it 'return success' do
          post api(url, admin, admin_mode: true),
            params: { email: invite_email,
                      access_level: Member::MINIMAL_ACCESS }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['status']).to eq("success")
        end
      end

      context 'when group has parent' do
        let(:parent_group) { create(:group) }
        let(:group) { create(:group, parent: parent_group) }

        it 'return error' do
          post api(url, admin, admin_mode: true),
            params: { email: invite_email,
                      access_level: Member::MINIMAL_ACCESS }

          expect(json_response['status']).to eq 'error'
          expect(json_response['message'][invite_email]).to include('Access level is not included in the list')
        end
      end
    end

    context 'when assigning a member role' do
      let(:source) { group }

      it_behaves_like 'member role assignment during creation'
    end
  end

  describe 'POST /projects/:id/invitations' do
    let(:url) { "/projects/#{project.id}/invitations" }

    it_behaves_like 'member creation audit event'

    it_behaves_like 'POST request permissions for admin mode' do
      let(:path) { url }
      let(:params) { { email: 'example1@example.com', access_level: Member::DEVELOPER } }
      let(:failed_status_code) { :not_found }
    end

    context 'when licensed feature for disable_invite_members is available' do
      let(:email) { 'example1@example.com' }
      let(:maintainer) { create(:user) }
      let(:owner) { create(:user) }

      before do
        project.add_maintainer(maintainer)
        project.add_maintainer(owner)
        stub_licensed_features(disable_invite_members: true)
      end

      shared_examples "user is not allowed to invite members" do
        context 'when user is maintainer/owner' do
          it 'returns 403' do
            post api(url, maintainer),
              params: { email: email, access_level: Member::MAINTAINER }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when user is admin' do
          let(:admin_user) { create(:admin) }

          it 'adds a new member by email when admin_mode is enabled', :enable_admin_mode do
            expect do
              post api(url, admin_user),
                params: { email: email, access_level: Member::DEVELOPER }

              expect(response).to have_gitlab_http_status(:created)
            end.to change { project.members.invite.count }.by(1)
          end

          it 'returns 403 when admin_mode is not enabled' do
            post api(url, admin_user),
              params: { email: email, access_level: Member::MAINTAINER }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      shared_examples "user is allowed to invite members" do
        it 'adds a new member by email for owner role' do
          expect do
            post api(url, owner),
              params: { email: email, access_level: Member::MAINTAINER }
            expect(response).to have_gitlab_http_status(:created)
          end.to change { project.members.invite.count }.by(1)
        end

        it 'adds a new member by email for maintainer role' do
          expect do
            post api(url, maintainer),
              params: { email: email, access_level: Member::MAINTAINER }
            expect(response).to have_gitlab_http_status(:created)
          end.to change { project.members.invite.count }.by(1)
        end
      end

      context 'when .com', :saas do
        let_it_be_with_refind(:group) { create(:group_with_plan, plan: :premium_plan) }
        let_it_be_with_refind(:project) { create(:project, namespace: group) }

        context 'when saas feature is available' do
          before do
            stub_saas_features(group_disable_invite_members: true)
          end

          context 'when setting to disable_invite_member is ON' do
            before do
              group.update!(disable_invite_members: true)
            end

            it_behaves_like "user is not allowed to invite members"

            context 'when disable_invite_members application setting is OFF' do
              before do
                stub_application_setting(disable_invite_members: false)
              end

              it_behaves_like "user is not allowed to invite members"
            end
          end

          context 'when setting to disable_invite_member is OFF' do
            before do
              group.update!(disable_invite_members: false)
            end

            it_behaves_like "user is allowed to invite members"
          end
        end

        context 'when saas feature is not available' do
          before do
            stub_saas_features(group_disable_invite_members: false)
            group.update!(disable_invite_members: true)
          end

          it_behaves_like "user is allowed to invite members"
        end
      end

      context 'when self-managed' do
        context 'when setting to disable_invite_member is ON' do
          before do
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like "user is not allowed to invite members"
        end

        context 'when setting to disable_invite_member is OFF' do
          before do
            stub_application_setting(disable_invite_members: false)
          end

          it_behaves_like "user is allowed to invite members"
        end
      end
    end

    context 'when licensed feature disable_invite_members is not available' do
      let(:email) { 'example1@example.com' }
      let(:maintainer) { create(:user) }

      before do
        project.add_maintainer(maintainer)
        stub_licensed_features(disable_invite_members: false)
      end

      context 'when .com', :saas do
        context 'setting to disable_invite_members is ON' do
          before do
            stub_saas_features(group_disable_invite_members: true)
            project.group.update!(disable_invite_members: true)
          end

          it "does not make any difference to invitation of new member" do
            expect do
              post api(url, maintainer),
                params: { email: email, access_level: Member::MAINTAINER }
              expect(response).to have_gitlab_http_status(:created)
            end.to change { project.members.invite.count }.by(1)
          end
        end
      end

      context 'when self-managed' do
        context 'setting to disable_invite_members is ON' do
          before do
            stub_application_setting(disable_invite_members: true)
          end

          it "does not make any difference to invitation of new member" do
            expect do
              post api(url, maintainer),
                params: { email: email, access_level: Member::MAINTAINER }
              expect(response).to have_gitlab_http_status(:created)
            end.to change { project.members.invite.count }.by(1)
          end
        end
      end
    end

    context 'with group membership locked' do
      before do
        group.update!(membership_lock: true)
      end

      it 'returns an error and exception message when group membership lock is enabled' do
        params = { email: 'example1@example.com', access_level: Member::DEVELOPER }

        post api(url, admin, admin_mode: true), params: params

        expect(json_response['message']).to eq 'Members::CreateService::MembershipLockedError'
        expect(json_response['status']).to eq 'error'
        expect(json_response['reason']).to eq 'membership_locked_error'
      end
    end

    context 'when the project is restricted by admin signup restrictions' do
      it_behaves_like 'admin signup restrictions email error - denylist', "The member's email address is not allowed for this project. Go to the &#39;Admin area &gt; New user account restrictions&#39;, and check the &#39;Domain denylist&#39;.", :created
      context 'when the group is restricted by admin signup restrictions' do
        it_behaves_like 'admin signup restrictions email error - allowlist', "The member's email address is not allowed for this project. Go to the &#39;Admin area &gt; New user account restrictions&#39;, and check &#39;Domains allowed for new users&#39;.", :created
        it_behaves_like 'admin signup restrictions email error - email restrictions', "The member's email address is not allowed for this project. Go to the &#39;Admin area &gt; New user account restrictions&#39;, and check &#39;Email restrictions for new users&#39;.", :created
      end
    end

    context "when block seat overages is enabled for the project's group", :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be_with_refind(:project) { create(:project, namespace: group) }
      let_it_be(:owner) { create(:user) }
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_owner(owner)
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      it 'adds the member when there are open seats in the subscription' do
        post api(url, owner), params: { access_level: Member::DEVELOPER, user_id: user.id }

        expect(project.members.map(&:user_id)).to contain_exactly(user.id)
        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to eq({ 'status' => 'success' })
      end

      context 'when there are not enough seats in the subscription' do
        before_all do
          group.gitlab_subscription.update!(seats: 1)
        end

        context 'when the current user is an owner' do
          it 'rejects the member' do
            post api(url, owner), params: { access_level: Member::DEVELOPER, user_id: user.id }

            expect(project.members.map(&:user_id)).to be_empty
            expect(json_response).to eq({
              'status' => 'error',
              'message' => 'There are not enough available seats to invite this many users.',
              'reason' => 'seat_limit_exceeded_error'
            })
          end
        end

        context 'when the current user is not an owner' do
          let_it_be(:maintainer) { create(:user) }

          before do
            project.add_maintainer(maintainer)
          end

          it 'rejects with a relevant message' do
            post api(url, maintainer), params: { access_level: Member::DEVELOPER, user_id: user.id }

            expect(project.members.map(&:user_id)).to contain_exactly(maintainer.id)
            expect(json_response).to eq({
              'status' => 'error',
              'message' => 'There are not enough available seats to invite this many users. Ask a user with the Owner role to purchase more seats.',
              'reason' => 'seat_limit_exceeded_error'
            })
          end

          context 'when adding to a sub group project' do
            let_it_be(:sub_group) { create(:group, parent: group) }
            let_it_be(:sub_group_project) { create(:project, namespace: sub_group) }

            let(:url) { "/projects/#{sub_group_project.id}/invitations" }

            before do
              group.add_maintainer(maintainer)
            end

            it 'rejects with a relevant message' do
              post api(url, maintainer), params: { access_level: Member::DEVELOPER, user_id: user.id }

              expect(project.members.map(&:user_id)).to contain_exactly(maintainer.id)
              expect(json_response).to eq({
                'status' => 'error',
                'message' => 'There are not enough available seats to invite this many users. Ask a user with the Owner role to purchase more seats.',
                'reason' => 'seat_limit_exceeded_error'
              })
            end
          end
        end
      end

      it 'adds the member when the member is already in the group when all the seats are taken' do
        group.gitlab_subscription.update!(seats: 2)
        group.add_guest(user)

        post api(url, owner), params: { access_level: Member::DEVELOPER, user_id: user.id }

        expect(project.members.flat_map { |m| [m.user_id, m.access_level] }).to eq([user.id, Member::DEVELOPER])
        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to eq({ 'status' => 'success' })
      end
    end

    context 'when assigning a member role' do
      let(:source) { project }

      it_behaves_like 'member role assignment during creation'
    end
  end

  describe 'PUT /groups/:id/invitations/:email' do
    let!(:member) do
      create(:group_member, :guest, invite_token: '123', invite_email: invite_email, source: group)
    end

    let(:url) { "/groups/#{group.id}/invitations/#{invite_email}" }
    let(:source) { group }

    it_behaves_like 'member role assignment during update'
  end

  describe 'PUT /projects/:id/invitations/:email' do
    let!(:member) do
      create(:project_member, :guest, invite_token: '123', invite_email: invite_email, source: project)
    end

    let(:url) { "/projects/#{project.id}/invitations/#{invite_email}" }
    let(:source) { project }

    it_behaves_like 'member role assignment during update'
  end

  context 'group with LDAP group link' do
    include LdapHelpers

    let(:group) { create(:group_with_ldap_group_link, :public) }
    let(:owner) { create(:user) }
    let(:developer) { create(:user) }
    let(:invite) { create(:group_member, :invited, source: group, user: developer) }

    before do
      create(:group_member, :owner, group: group, user: owner)
      stub_ldap_setting(enabled: true)
      stub_application_setting(lock_memberships_to_ldap: true)
    end

    describe 'POST /groups/:id/invitations' do
      it 'returns a forbidden response' do
        post api("/groups/#{group.id}/invitations", owner), params: { email: developer.email, access_level: Member::DEVELOPER }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    describe 'PUT /groups/:id/invitations/:email' do
      it 'returns a forbidden response' do
        put api("/groups/#{group.id}/invitations/#{invite.invite_email}", owner), params: { access_level: Member::MAINTAINER }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    describe 'DELETE /groups/:id/invitations/:email' do
      it 'returns a forbidden response' do
        delete api("/groups/#{group.id}/invitations/#{invite.invite_email}", owner)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end

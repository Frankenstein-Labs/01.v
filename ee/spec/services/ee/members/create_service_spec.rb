# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::CreateService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:root_ancestor) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: root_ancestor) }
  let_it_be(:subgroup) { create(:group, parent: root_ancestor) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup) }
  let_it_be_with_reload(:project_users) { create_list(:user, 2) }

  let(:invites) { project_users.map(&:id).join(',') }
  let(:params) do
    {
      user_id: invites,
      access_level: Gitlab::Access::GUEST,
      invite_source: '_invite_source_'
    }
  end

  subject(:execute_service) { described_class.new(user, params.merge({ source: project })).execute }

  before_all do
    project.add_maintainer(user)

    create(:project_member, :invited, project: subgroup_project, created_at: 2.days.ago)
    create(:project_member, :invited, project: subgroup_project)
    create(:group_member, :invited, group: subgroup, created_at: 2.days.ago)
    create(:group_member, :invited, group: subgroup)
  end

  context 'with group plan observing quota limits', :saas do
    let(:plan) { create(:free_plan) }
    let!(:plan_limits) { create(:plan_limits, plan: plan, daily_invites: daily_invites) }
    let!(:subscription) do
      create(
        :gitlab_subscription,
        namespace: root_ancestor,
        hosted_plan: plan
      )
    end

    shared_examples 'quota limit exceeded' do |limit|
      it { expect(execute_service).to include(status: :error, message: "Invite limit of #{limit} per day exceeded.") }
      it { expect { execute_service }.not_to change { Member.count } }
    end

    context 'already exceeded invite quota limit' do
      let(:daily_invites) { 2 }

      it_behaves_like 'quota limit exceeded', 2
    end

    context 'will exceed invite quota limit' do
      let(:daily_invites) { 3 }

      it_behaves_like 'quota limit exceeded', 3
    end

    context 'within invite quota limit' do
      let(:daily_invites) { 5 }

      it { expect(execute_service).to eq({ status: :success }) }

      it do
        execute_service

        expect(project.users).to include(*project_users)
      end
    end

    context 'infinite invite quota limit' do
      let(:daily_invites) { 0 }

      it { expect(subject).to eq({ status: :success }) }

      it do
        execute_service

        expect(project.users).to include(*project_users)
      end
    end
  end

  context 'without a plan' do
    let(:plan) { nil }

    it { expect(execute_service).to eq({ status: :success }) }

    it do
      execute_service

      expect(project.users).to include(*project_users)
    end
  end

  context 'streaming audit event' do
    let(:group) { root_ancestor }
    let(:user_added) { project_users.first }
    let(:invites) { user_added.id }

    it 'audits event with name' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(
          name: 'member_created',
          author: user,
          scope: project,
          target: user_added,
          target_details: user_added.name,
          message: 'Membership created',
          additional_details: hash_including(
            add: 'user_access',
            as: 'Default role: Guest',
            member_role_id: nil
          )
        )
      )

      execute_service
    end

    include_examples 'sends streaming audit event'
  end

  context 'streaming audit event with expiry date' do
    let(:user_added) { project_users.first }
    let(:invites) { user_added.id }

    context 'when member is created with an expiry date' do
      let(:expires_at) { 30.days.from_now }
      let(:params) do
        {
          user_id: invites,
          access_level: Gitlab::Access::GUEST,
          invite_source: '_invite_source_',
          expires_at: expires_at
        }
      end

      subject(:execute_service) { described_class.new(user, params.merge({ source: project })).execute }

      it 'includes expires_at in the audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit) do |args|
          expect(args[:name]).to eq('member_created')
          expect(args[:author]).to eq(user)
          expect(args[:scope]).to eq(project)
          expect(args[:target]).to eq(user_added)
          expect(args[:target_details]).to eq(user_added.name)
          expect(args[:message]).to eq('Membership created')
          expect(args[:additional_details][:add]).to eq('user_access')
          expect(args[:additional_details][:as]).to eq('Default role: Guest')
          expect(args[:additional_details][:member_id]).to be_an(Integer)
          expect(args[:additional_details][:member_role_id]).to be_nil
          expect(args[:additional_details][:expires_at].to_date).to eq(expires_at.to_date)
        end

        execute_service
      end
    end

    context 'when member is created without an expiry date' do
      it 'includes expires_at as nil in the audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'member_created',
            additional_details: hash_including(expires_at: nil)
          )
        )

        execute_service
      end
    end
  end

  context 'with onboarding progress' do
    context 'when member creation is successful' do
      it 'invokes an async onboarding progress update' do
        expect(Onboarding::ProgressService).to receive(:async).with(project.namespace_id, 'user_added')

        execute_service
      end
    end

    context 'when member creation fails' do
      let(:invites) { '' }

      it 'does not invoke an async onboarding progress update' do
        expect(Onboarding::ProgressService).not_to receive(:async)

        execute_service
      end
    end
  end

  context 'for onboarding concerns' do
    let(:onboarding_user) { project_users.first }
    let(:onboarding_enabled?) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled?)
    end

    context 'when user qualifies for being in onboarding' do
      it 'converts the user to an invite registration' do
        onboarding_user.update!(onboarding_in_progress: true, onboarding_status_registration_type: 'free')

        expect do
          execute_service
        end.to change { onboarding_user.reset.onboarding_status_registration_type }.from('free').to('invite')
      end

      context 'when user has finished the welcome step' do
        before do
          onboarding_user.update!(onboarding_status_role: 0, onboarding_in_progress: true)
        end

        it 'finishes onboarding' do
          expect do
            execute_service
          end.to change { onboarding_user.reset.onboarding_in_progress }.from(true).to(false)
        end
      end

      context 'when user has not finished the welcome step' do
        before do
          onboarding_user.update!(onboarding_in_progress: true)
        end

        it 'does not finish onboarding' do
          expect do
            execute_service
          end.not_to change { onboarding_user.reset.onboarding_in_progress }
        end
      end
    end

    context 'when user does not qualify for onboarding' do
      let(:onboarding_enabled?) { false }

      it 'does not convert the user to an invite registration' do
        expect do
          execute_service
        end.not_to change { user.reset.onboarding_status_registration_type }
      end

      context 'when user has finished the welcome step' do
        before do
          user.update!(onboarding_in_progress: true)
        end

        it 'does not finish onboarding' do
          expect do
            execute_service
          end.not_to change { user.reset.onboarding_in_progress }
        end
      end
    end
  end

  context 'with seat availability concerns', :saas do
    let_it_be(:root_ancestor) { create(:group_with_plan, :private, plan: :free_plan) }
    let_it_be_with_refind(:project) { create(:project, group: root_ancestor, maintainers: user) }

    before do
      stub_ee_application_setting(dashboard_limit_enabled: true)
    end

    context 'when creating' do
      context 'when seat is available' do
        before do
          stub_ee_application_setting(dashboard_limit: 3)
        end

        context 'with existing user that is a member in our hierarchy' do
          let(:existing_user) do
            new_project = create(:project, group: root_ancestor)
            create(:project_member, project: new_project).user
          end

          let(:invites) { "#{create(:user).id},#{existing_user.id}" }

          it 'adds the member' do
            expect(execute_service[:status]).to eq(:success)
            expect(project.users).to include existing_user
          end
        end

        context 'when under the dashboard limit' do
          it 'adds the members' do
            expect(execute_service[:status]).to eq(:success)
            expect(project.users).to include(*project_users)
          end
        end
      end

      context 'when seat is not available' do
        it 'does not add members' do
          expect(execute_service[:status]).to eq(:error)
          expect(execute_service[:message]).to match(/: cannot be added since you've reached your /)
          expect(project.users).not_to include(*project_users)
        end
      end
    end

    context 'when updating with no seats left' do
      let(:invites) { invited_member.invite_email }
      let(:invited_member) do
        build(:project_member, :maintainer, :invited, source: project).tap do |record|
          record.member_namespace_id = record.project.project_namespace_id
          record.save!(validate: false)
        end
      end

      before do
        stub_ee_application_setting(dashboard_limit: 1)
      end

      it 'allows updating existing invited member' do
        expect(execute_service[:status]).to eq(:success)
        expect(invited_member.reset.access_level).to eq Gitlab::Access::GUEST
      end
    end
  end

  context 'when part of a group that a free group invited', :saas, :sidekiq_inline do
    context 'when free group is over the limit', :with_trial_types do
      let(:dashboard_limit_enabled) { true }
      let_it_be(:owner) { create(:user) }
      let_it_be(:root_ancestor) do
        create(:group_with_plan, :private, plan: :free_plan, owners: owner)
      end

      let_it_be(:invited_group) do
        create(:group).tap do |g|
          g.add_owner(user)
          create(:group_group_link, { shared_with_group: g, shared_group: root_ancestor })
        end
      end

      before do
        stub_ee_application_setting(dashboard_limit: 3)
        stub_ee_application_setting(dashboard_limit_enabled: dashboard_limit_enabled)
      end

      subject(:execute_service) { described_class.new(user, params.merge({ source: invited_group })).execute }

      it 'triggers an email notification to owners' do
        root_ancestor.each_member_user(access_level: GroupMember::OWNER) do |owner|
          expect(::Namespaces::FreeUserCapMailer)
            .to receive(:over_limit_email).with(owner, root_ancestor).once.and_call_original
        end

        execute_service
      end

      shared_examples 'notification does not get triggered' do
        it 'does not trigger the notification worker' do
          expect(::Namespaces::FreeUserCap::GroupOverLimitNotificationWorker).not_to receive(:perform_async)

          execute_service
        end
      end

      context 'when member source is not a Group' do
        subject(:execute_service) { described_class.new(user, params.merge({ source: project })).execute }

        it_behaves_like 'notification does not get triggered'
      end

      context 'when dashboard limit is not enabled' do
        let(:dashboard_limit_enabled) { false }

        it_behaves_like 'notification does not get triggered'
      end

      context 'when all members added already existed' do
        let(:invites) { [owner.id] }

        before_all do
          invited_group.add_developer(owner)
        end

        it_behaves_like 'notification does not get triggered'
      end

      context 'when all members added are not associated with a user' do
        let(:invites) { ['email@example.org'] }

        it_behaves_like 'notification does not get triggered'
      end
    end
  end

  context 'when group membership is locked' do
    before do
      root_ancestor.update_attribute(:membership_lock, true)
    end

    it 'does not add the given users to the team' do
      expect { execute_service }.not_to change { project.members.count }
    end
  end

  context 'when assigning a member role', feature_category: :permissions do
    let_it_be(:member_role) { create(:member_role, :guest, namespace: root_ancestor, name: 'Custom role') }

    before do
      params[:member_role_id] = member_role.id
    end

    context 'with custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'adds a user to members with custom role assigned' do
        expect { execute_service }.to change { project.members.count }.by(2)

        member = Member.last

        expect(member.member_role).to eq(member_role)
        expect(member.access_level).to eq(Member::GUEST)
      end

      context 'streaming audit event' do
        let(:invites) { project_users.first.id }

        it 'audits event with member_role_id' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'member_created',
              additional_details: hash_including(
                add: 'user_access',
                as: 'Custom role: Custom role',
                member_role_id: member_role.id
              )
            )
          )

          execute_service
        end
      end

      context "member's Authz::UserGroupMembeRole records" do
        let_it_be(:group) { root_ancestor }
        let_it_be(:new_user) { create(:user) }

        let(:params) do
          {
            user_id: new_user.id,
            access_level: Gitlab::Access::GUEST,
            source: group,
            member_role_id: member_role.id,
            invite_source: '_invite_source_'
          }
        end

        subject(:execute_service) { described_class.new(user, params).execute }

        before do
          group.add_owner(user)
        end

        it 'enqueues an ::Authz::UserGroupMemberRoles::UpdateForGroupWorker job' do
          expect(::Authz::UserGroupMemberRoles::UpdateForGroupWorker)
            .to receive(:perform_async)

          execute_service
        end
      end
    end

    context 'without custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'adds a user to members without custom role assigned' do
        expect { execute_service }.to change { project.members.count }.by(2)

        member = Member.last

        expect(member.member_role).to be_nil
        expect(member.access_level).to eq(Member::GUEST)
      end
    end
  end

  context 'with block seat overages enabled', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be(:owner) { create(:user) }
    let_it_be_with_refind(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_refind(:project) { create(:project, group: group) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_licensed_features(custom_roles: true)
      group.add_owner(owner)
      group.gitlab_subscription.update!(seats: 1)
      group.namespace_settings.update!(seat_control: :block_overages)
    end

    it 'notifies the group owner about the rejected membership' do
      params[:access_level] = ::Gitlab::Access::DEVELOPER

      notification_service = double

      expect(::NotificationService).to receive(:new).and_return(notification_service)
      expect(notification_service).to receive(:no_more_seats)
        .with(group, [owner], user, project_users.map(&:name))

      execute_service
    end

    context 'when current user is the owner' do
      let_it_be(:owner) { user }

      it 'does not notify the group owner about the rejected membership' do
        params[:access_level] = ::Gitlab::Access::DEVELOPER

        expect(::NotificationService).not_to receive(:new)

        execute_service
      end
    end

    context 'with invited emails' do
      let(:invites) { ['email@example.com'] }

      it 'does not notify the owner of rejected email invites' do
        params[:access_level] = ::Gitlab::Access::DEVELOPER

        expect(::NotificationService).not_to receive(:new)

        execute_service
      end

      context 'when email is of existing user' do
        let(:invites) { project_users.map(&:email) }

        it 'does not reject membership update for already billable user on billable role' do
          project_member_a = project.add_developer(project_users.first)
          project_member_b = project.add_developer(project_users.second)
          params[:access_level] = ::Gitlab::Access::MAINTAINER

          execute_service

          expect(project_member_a.reload.access_level).to eq ::Gitlab::Access::MAINTAINER
          expect(project_member_b.reload.access_level).to eq ::Gitlab::Access::MAINTAINER
        end
      end
    end

    context 'when we invite a bot user' do
      let(:invites) { create(:user, :bot).id }

      it 'does not reject bot users' do
        params[:access_level] = ::Gitlab::Access::DEVELOPER

        expect { execute_service }.to change { project.members.count }.by(1)
      end
    end

    it 'adds guest users even if there are no seats available' do
      expect { execute_service }.to change { project.members.count }.by(2)
    end

    it 'rejects members with a billable custom role when there are no seats available' do
      custom_role = create(:member_role, namespace: group, base_access_level: Gitlab::Access::GUEST,
        permissions: { remove_project: true })
      params[:member_role_id] = custom_role.id

      expect { execute_service }.not_to change { project.members.count }
    end

    it 'accepts members with a non-billable custom role when there are no seats available' do
      custom_role = create(:member_role, namespace: group, base_access_level: Gitlab::Access::GUEST,
        permissions: { read_code: true })
      params[:member_role_id] = custom_role.id

      expect { execute_service }.to change { project.members.count }.by(2)
    end

    it 'rejects members with a custom role from another namespace' do
      other_group = create(:group)
      custom_role = create(:member_role, namespace: other_group, base_access_level: Gitlab::Access::GUEST,
        permissions: { read_code: true })
      user = create(:user)
      params[:member_role_id] = custom_role.id
      params[:user_id] = user.id.to_s

      result = execute_service

      expect(project.members.count).to eq(1)
      expect(result).to eq({
        status: :error,
        message: "#{user.username}: Member namespace must be in same hierarchy as custom role's namespace"
      })
    end
  end

  context 'with block seat overages enabled for self-managed' do
    let_it_be(:user) { create(:user) }
    let_it_be(:owner) { create(:user) }
    let_it_be_with_refind(:group) { create(:group, owners: owner) }
    let_it_be_with_refind(:project) { create(:project, group: group, maintainers: user) }

    let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
    let(:available_seats) { 1 }
    let(:seat_control_block_overages) { 2 }
    let(:seat_control_off) { 0 }

    before do
      stub_licensed_features(custom_roles: true)
      stub_application_setting(seat_control: seat_control_block_overages)
      allow(License).to receive(:current).and_return(license)
      allow(License).to receive_message_chain(:current, :seats).and_return(available_seats)
    end

    it 'adds guest users even if there are no seats available' do
      params[:access_level] = Gitlab::Access::GUEST

      expect { execute_service }.to change { project.members.count }.by(2)
    end

    it 'rejects members with billable roles when no seats are available' do
      params[:access_level] = Gitlab::Access::DEVELOPER

      expect { execute_service }.not_to change { project.members.count }
      expect(execute_service[:status]).to eq(:error)
      expect(execute_service[:reason]).to eq(:seat_limit_exceeded_error)
    end

    context 'with custom roles' do
      it 'rejects members with a billable custom role when there are no seats available' do
        custom_role = create(:member_role, :instance, :billable)
        params[:member_role_id] = custom_role.id

        expect { execute_service }.not_to change { project.members.count }
        expect(execute_service[:status]).to eq(:error)
        expect(execute_service[:reason]).to eq(:seat_limit_exceeded_error)
      end
    end

    context 'when license excludes guests from active count' do
      let(:license) { create(:license, plan: License::PREMIUM_PLAN) }
      let(:invites) { ['email@example.com'] }

      it 'rejects guest user invite even if there are seats available' do
        params[:access_level] = Gitlab::Access::GUEST

        expect { execute_service }.not_to change { project.members.count }
        expect(execute_service[:status]).to eq(:error)
        expect(execute_service[:reason]).to eq(:seat_limit_exceeded_error)
      end
    end

    context 'when setting is disabled' do
      before do
        stub_application_setting(seat_control: seat_control_off)
      end

      it 'adds members even when no seats are available' do
        params[:access_level] = Gitlab::Access::DEVELOPER

        expect { execute_service }.to change { project.members.count }.by(2)
      end
    end
  end

  context 'with skip_authorization param' do
    before do
      params[:access_level] = Gitlab::Access::OWNER
      params[:skip_authorization] = true
    end

    context 'with current_user' do
      it 'ignores skip_authorization and raises AccessDeniedError' do
        expect { execute_service }.to raise_error(::Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when current_user is nil' do
      let(:user) { nil }

      context 'when skip_authorization param is false' do
        it 'raises AccessDeniedError' do
          params[:skip_authorization] = false

          expect { execute_service }.to raise_error(::Gitlab::Access::AccessDeniedError)
        end
      end

      context 'when skip_authorization param is true' do
        it 'returns success' do
          params[:skip_authorization] = true

          expect(execute_service).to eq({ status: :success })
        end
      end
    end
  end

  context 'with billable promotion management' do
    let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
    let(:params) do
      {
        user_id: invites,
        access_level: Gitlab::Access::DEVELOPER,
        invite_source: '_invite_source_'
      }
    end

    before do
      stub_application_setting(enable_member_promotion_management: true)
      allow(License).to receive(:current).and_return(license)
    end

    shared_examples 'does not trigger event' do
      it 'does not publish a MembershipModifiedByAdminEvent' do
        expect(Gitlab::EventStore)
          .not_to receive(:publish)
                    .with(an_instance_of(::Members::MembershipModifiedByAdminEvent))

        execute_service
      end
    end

    context 'when setting is disabled' do
      before do
        stub_application_setting(enable_member_promotion_management: false)
      end

      it { expect { execute_service }.to change { project.members.count }.by(2) }
    end

    context 'when license is not Ultimate' do
      let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

      it { expect { execute_service }.to change { project.members.count }.by(2) }
    end

    context 'queues member for admin approval' do
      it { expect { execute_service }.not_to change { project.members.count } }

      it do
        expect { execute_service }.to change {
          ::GitlabSubscriptions::MemberManagement::MemberApproval.count
        }.by(2)
      end

      it 'returns queued_users in the response' do
        expect(execute_service).to eq({
          status: :success,
          queued_users: {
            project_users[0].username => 'Request queued for administrator approval.',
            project_users[1].username => 'Request queued for administrator approval.'
          }
        })
      end

      context 'with error and queued users' do
        before do
          root_ancestor.add_owner(project_users[0])
        end

        it 'returns message and queued_users in the response' do
          error_message = "#{project_users[0].username}: Access level should be greater than or equal to " \
            "Owner inherited membership from group #{root_ancestor.name}"

          expect(execute_service).to eq({
            status: :error,
            message: error_message,
            queued_users: {
              project_users[1].username => 'Request queued for administrator approval.'
            }
          })
        end
      end

      it_behaves_like 'does not trigger event'
    end

    context 'when admin modifies members', :enable_admin_mode do
      let_it_be(:user) { create(:admin) }

      shared_examples 'triggers event' do |call_count = 1|
        it 'publishes MembershipModifiedByAdminEvent' do
          allow(Gitlab::EventStore).to receive(:publish).and_call_original
          expect(Gitlab::EventStore)
            .to receive(:publish)
                  .with(an_instance_of(::Members::MembershipModifiedByAdminEvent))
                  .and_call_original
                  .exactly(call_count).times

          execute_service
        end
      end

      context 'when adding user to billable DEVELOPER role' do
        before do
          params[:access_level] = Gitlab::Access::DEVELOPER
        end

        it_behaves_like 'triggers event', 2

        context 'when one member has error' do
          before do
            root_ancestor.add_owner(project_users[0])
          end

          it_behaves_like 'triggers event', 1
        end

        context 'when setting is disabled' do
          before do
            stub_application_setting(enable_member_promotion_management: false)
          end

          it_behaves_like 'does not trigger event'
        end

        context 'when license is not Ultimate' do
          let(:license) { create(:license, plan: License::STARTER_PLAN) }

          it_behaves_like 'does not trigger event'
        end

        context 'when new user not present in system is invited with email' do
          let(:invites) { ['new_user@example.com'] }

          it_behaves_like 'does not trigger event'
        end
      end

      context 'when adding user to a non billable GUEST role' do
        before do
          params[:access_level] = Gitlab::Access::GUEST
        end

        it_behaves_like 'does not trigger event'
      end
    end

    context 'when current_user is nil' do
      let(:user) { nil }

      before do
        params[:skip_authorization] = true
      end

      it_behaves_like 'does not trigger event'
    end

    context 'when saas', :saas do
      before_all do
        root_ancestor.add_owner(user)
      end

      it_behaves_like 'does not trigger event'
    end
  end
end

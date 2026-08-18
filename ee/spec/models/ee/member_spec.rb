# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Member, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax
  include MemberRoleHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:member) { build(:group_member, :developer, source: group, user: user) }
  let_it_be(:sub_group, freeze: false) { create(:group, parent: group) }
  let_it_be(:sub_group_member) { build(:group_member, source: sub_group, user: user) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_member) { build(:project_member, source: project, user: user) }

  describe 'Associations' do
    it { is_expected.to belong_to(:member_role) }
    it { is_expected.to have_many(:member_approvals).class_name('::GitlabSubscriptions::MemberManagement::MemberApproval').inverse_of(:member) }
  end

  describe 'Validation' do
    context 'with seat availability concerns', :saas do
      let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)
      end

      context 'when creating' do
        context 'when seat is available' do
          before do
            stub_ee_application_setting(dashboard_limit: 2)
          end

          context 'with existing user that is a member in our hierarchy' do
            let(:existing_user) do
              new_project = create(:project, group: group)
              create(:project_member, project: new_project).user
            end

            it 'is valid' do
              expect(build(:group_member, source: group, user: existing_user)).to be_valid
            end
          end

          context 'when under the dashboard limit' do
            it 'is valid' do
              expect(build(:group_member, source: group, user: create(:user))).to be_valid
            end
          end
        end

        context 'when seat is not available' do
          it 'is invalid' do
            expect(build(:group_member, source: group, user: create(:user))).to be_invalid
          end
        end
      end

      context 'when updating with no seats left' do
        it 'allows updating existing non-invited member' do
          member = build(:group_member, :owner, source: group, user: user).tap do |record|
            record.save!(validate: false)
          end

          expect do
            member.update!(access_level: Member::DEVELOPER)
          end.to change { member.access_level }.from(Member::OWNER).to(Member::DEVELOPER)
        end

        it 'allows updating existing invited member' do
          invited_member = build(:group_member, :owner, :invited, source: group).tap do |record|
            record.save!(validate: false)
          end

          expect do
            invited_member.update!(access_level: Member::DEVELOPER)
          end.to change { invited_member.access_level }.from(Member::OWNER).to(Member::DEVELOPER)
        end
      end
    end

    context 'member role namespace' do
      let_it_be_with_reload(:member) { create(:group_member, :maintainer) }

      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when no member role is associated' do
        it 'is valid' do
          expect(member).to be_valid
        end
      end

      context 'when member role is associated' do
        context 'when member role is for an instance' do
          it 'is valid' do
            member.member_role = create(:member_role, :instance, base_access_level: member.access_level)

            expect(member).to be_valid
          end
        end

        context 'member role for a group' do
          let_it_be(:member_role) do
            create(:member_role, members: [member], namespace: member.group, base_access_level: member.access_level)
          end

          context 'when member#member_namespace is a group within hierarchy of member_role#namespace' do
            it 'is valid' do
              member.member_namespace = create(:group, parent: member_role.namespace)

              expect(member).to be_valid
            end
          end

          context 'when member#member_namespace is a project within hierarchy of member_role#namespace' do
            it 'is valid' do
              project = create(:project, group: member_role.namespace)
              member.member_namespace = Namespace.find(project.parent_id)

              expect(member).to be_valid
            end
          end

          context 'when member#member_namespace is outside hierarchy of member_role#namespace' do
            it 'is invalid' do
              member.member_namespace = create(:group)

              expect(member).not_to be_valid
              expect(member.errors[:member_namespace]).to include(
                _("must be in same hierarchy as custom role's namespace")
              )
            end
          end
        end
      end

      it_behaves_like 'model with member role relation' do
        subject(:model) { build(:group_member, source: group) }
      end
    end
  end

  describe 'scopes' do
    let_it_be(:member_role) { create(:member_role, :maintainer, namespace: group) }
    let_it_be(:membership_with_custom_role) do
      create(:group_member, group: sub_group, access_level: ::Gitlab::Access::MAINTAINER, member_role: member_role)
    end

    let_it_be(:membership_with_guest_role) do
      create(:group_member, group: sub_group, access_level: ::Gitlab::Access::GUEST)
    end

    let_it_be(:membership_with_maintainer_role) do
      create(:group_member, group: sub_group, access_level: ::Gitlab::Access::MAINTAINER)
    end

    describe '.with_custom_role' do
      subject { described_class.with_custom_role }

      it { is_expected.to contain_exactly(membership_with_custom_role) }
    end

    describe '.with_member_role_id' do
      subject { described_class.with_member_role_id(member_role.id) }

      it { is_expected.to contain_exactly(membership_with_custom_role) }
    end

    describe '.with_static_role' do
      subject { described_class.with_static_role }

      it { is_expected.to contain_exactly(membership_with_guest_role, membership_with_maintainer_role) }
    end

    describe '.count_members_by_role' do
      subject(:result) { described_class.count_members_by_role }

      it { is_expected.to eql(::Gitlab::Access::MAINTAINER => 2, ::Gitlab::Access::GUEST => 1) }
    end

    describe '.count_users_by_role' do
      subject(:result) { described_class.count_users_by_role }

      it { is_expected.to eql(::Gitlab::Access::MAINTAINER => 2, ::Gitlab::Access::GUEST => 1) }
    end

    describe '.distinct_on_user_with_max_access_level' do
      let_it_be(:member_role) { create(:member_role, :instance) }

      let_it_be(:member_with_same_access_level) { create(:group_member, :developer, user: user) }
      let_it_be(:member_with_higher_access_level) { create(:group_member, :maintainer, user: user) }
      let_it_be(:member_with_higher_access_level_and_custom_role) { create(:group_member, :maintainer, user: user, member_role: member_role) }

      subject { described_class.default_scoped.distinct_on_user_with_max_access_level(group).to_a }

      it { is_expected.not_to include member_with_same_access_level }
      it { is_expected.not_to include member_with_higher_access_level }
      it { is_expected.to include member_with_higher_access_level_and_custom_role }
    end

    describe '.order_access_level_desc' do
      it 'orders by the access level' do
        group = create(:group)
        developer = create(:group_member, :developer, group: group)
        maintainer = create(:group_member, :maintainer, group: group)

        expect(group.members.order_access_level_desc).to eq([maintainer, developer])
      end
    end
  end

  describe '.highest_role' do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:user_with_no_membership) { create(:user) }
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: top_level_group) }
    let_it_be(:project) { create(:project, group: subgroup) }

    context 'when user has higher access in subgroup than top level group' do
      let_it_be(:guest_membership_in_top_level_group) { create(:group_member, :guest, group: top_level_group, user: user) }
      let_it_be(:maintainer_membership_in_subgroup) { create(:group_member, :maintainer, group: subgroup, user: user) }

      subject(:highest_role) { described_class.highest_role(user, project) }

      it 'returns the member with the highest access level in the hierarchy' do
        expect(highest_role).to eq(maintainer_membership_in_subgroup)
        expect(highest_role.access_level).to eq(Gitlab::Access::MAINTAINER)
      end
    end

    context 'when user has higher access in top level group than a project' do
      let_it_be(:guest_membership_in_project) { create(:project_member, :guest, project: project, user: user) }
      let_it_be(:maintainer_membership_in_top_level_group) { create(:group_member, :maintainer, group: top_level_group, user: user) }

      subject(:highest_role) { described_class.highest_role(user, project) }

      it 'returns the member with the highest access level in the hierarchy' do
        expect(highest_role).to eq(maintainer_membership_in_top_level_group)
        expect(highest_role.access_level).to eq(Gitlab::Access::MAINTAINER)
      end
    end

    context 'when user has no membership in hierarchy' do
      subject { described_class.highest_role(user_with_no_membership, project) }

      it { is_expected.to be_nil }
    end
  end

  describe '#notification_service' do
    it 'returns a NullNotificationService instance for LDAP users' do
      member = described_class.new

      allow(member).to receive(:ldap).and_return(true)

      expect(member.__send__(:notification_service))
        .to be_instance_of(::EE::NullNotificationService)
    end
  end

  describe '#accept_invite!' do
    let(:user) { create(:user) }

    subject(:accept_invite) { member.accept_invite!(user) }

    shared_examples 'a blocked invite acceptance' do
      it 'does not accept the invite and leaves it pending', :aggregate_failures do
        expect(accept_invite).to be false
        expect(member.reload.invite_token).not_to be_nil
        expect(member.invite_accepted_at).to be_nil
        expect(member.user).to be_nil
      end
    end

    shared_examples 'a successful invite acceptance' do
      it 'accepts the invite with the originally invited role', :aggregate_failures do
        expect(accept_invite).to be true
        expect(member.reload.user).to eq(user)
        expect(member.invite_token).to be_nil
        expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
      end
    end

    context 'when user is not provided' do
      let(:member) { create(:project_member, :developer, :invited, source: project, invite_email: 'user@example.com') }
      let(:user) { nil }

      it_behaves_like 'a blocked invite acceptance'
    end

    context 'when on saas', :saas do
      let_it_be_with_reload(:group, freeze: false) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:project) { create(:project, group: group) }

      let(:member) { create(:project_member, :developer, project: project, invite_email: 'user@example.com', user: nil) }

      before_all do
        group.add_owner(create(:user))
      end

      context 'when restricted access is enabled' do
        before_all do
          group.namespace_settings.update!(seat_control: :block_overages)
        end

        context 'when there are not enough seats' do
          before do
            group.gitlab_subscription.update!(seats: 1)
          end

          it_behaves_like 'a blocked invite acceptance'
        end

        context 'when there are enough seats' do
          before do
            group.gitlab_subscription.update!(seats: 2)
          end

          it_behaves_like 'a successful invite acceptance'
        end
      end

      context 'when restricted access is not enabled' do
        context 'when there are not enough seats' do
          before do
            group.gitlab_subscription.update!(seats: 1)
          end

          it_behaves_like 'a successful invite acceptance'
        end
      end
    end

    context 'when on self-managed' do
      let_it_be(:group) { create(:group, owners: [create(:user)]) }
      let_it_be(:project) { create(:project, group: group) }

      let(:member) { create(:project_member, :developer, source: project, invite_email: 'user@example.com', user: nil) }
      let(:seats_used) { ::User.billable.count }

      # On Ultimate, users are non-billable until they have a billable group or project
      # membership, so a delayed invite acceptance can cause a seat overage even when
      # restricted access is enabled
      #
      # On Premium, users are billable as soon as their account exists, so the overage
      # is caught earlier during account registration rather than at invite acceptance
      let(:license) { create(:license, :ultimate) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      context 'when restricted access is enabled' do
        before do
          stub_application_setting(seat_control: ::EE::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)
        end

        context 'when there are not enough seats' do
          before do
            allow(license).to receive(:seats).and_return(seats_used)
          end

          it_behaves_like 'a blocked invite acceptance'
        end

        context 'when there are enough seats' do
          before do
            allow(license).to receive(:seats).and_return(seats_used + 1)
          end

          it_behaves_like 'a successful invite acceptance'
        end
      end

      context 'when restricted access is not enabled' do
        context 'when there are not enough seats' do
          before do
            allow(license).to receive(:seats).and_return(seats_used)
          end

          it_behaves_like 'a successful invite acceptance'
        end
      end
    end
  end

  describe '#is_using_seat', :aggregate_failures do
    context 'when hosted on GL.com', :saas do
      it 'calls users check for using the gitlab_com seat method' do
        expect(user).to receive(:using_gitlab_com_seat?).with(group).once.and_return true
        expect(user).not_to receive(:using_license_seat?)
        expect(member.is_using_seat).to be_truthy
      end
    end

    context 'when not hosted on GL.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return false
      end

      it 'calls users check for using the License seat method' do
        expect(user).to receive(:using_license_seat?).with(no_args).and_return true
        expect(user).not_to receive(:using_gitlab_com_seat?)
        expect(member.is_using_seat).to be_truthy
      end

      context 'when the member is nil' do
        let_it_be(:member) { build(:group_member, :invited) }

        it 'returns false' do
          expect(member.is_using_seat).to be_falsey
        end
      end
    end
  end

  describe '#source_kind' do
    subject { member.source_kind }

    context 'when source is of Group kind' do
      it { is_expected.to eq('Group') }
    end

    context 'when source is of Sub group kind' do
      let(:member) { sub_group_member }

      it { is_expected.to eq('Sub group') }
    end

    context 'when source is of Project kind' do
      let(:member) { project_member }

      it { is_expected.to eq('Project') }
    end
  end

  describe '#group_saml_identity' do
    shared_examples_for 'member with group saml identity' do
      context 'without saml_provider' do
        it { is_expected.to be_nil }
      end

      context 'with saml_provider enabled' do
        let!(:saml_provider) { create(:saml_provider, group: member.group) }

        context 'when member has no connected identity' do
          it { is_expected.to be_nil }
        end

        context 'when member has connected identity' do
          let!(:group_related_identity) do
            create(:group_saml_identity, user: member.user, saml_provider: saml_provider)
          end

          it 'returns related identity' do
            expect(group_saml_identity).to eq group_related_identity
          end
        end

        context 'when member has connected identity of different group' do
          before do
            create(:group_saml_identity, user: member.user)
          end

          it { is_expected.to be_nil }
        end
      end
    end

    shared_examples_for 'member with group saml identity on the top level' do
      let!(:saml_provider) { create(:saml_provider, group: parent_group) }

      let!(:group_related_identity) do
        create(:group_saml_identity, user: member.user, saml_provider: saml_provider)
      end

      it 'returns related identity' do
        expect(member.group_saml_identity(root_ancestor: true)).to eq group_related_identity
      end
    end

    describe 'for group members' do
      context 'when member is in a top-level group' do
        let_it_be_with_refind(:member) { create(:group_member) }

        subject(:group_saml_identity) { member.group_saml_identity }

        it_behaves_like 'member with group saml identity'
      end

      context 'when member is in a subgroup' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:group) { create(:group, parent: parent_group) }
        let_it_be_with_refind(:member) { create(:group_member, source: group) }

        it_behaves_like 'member with group saml identity on the top level'
      end
    end

    describe 'for project members' do
      context 'when project is nested in a group' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, namespace: group) }
        let_it_be_with_refind(:member) { create(:project_member, source: project) }

        subject(:group_saml_identity) { member.group_saml_identity }

        it_behaves_like 'member with group saml identity'
      end

      context 'when project is nested in a subgroup' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:group) { create(:group, parent: parent_group) }
        let_it_be(:project) { create(:project, namespace: group) }
        let_it_be_with_refind(:member) { create(:project_member, source: project) }

        it_behaves_like 'member with group saml identity on the top level'
      end

      context 'when project is nested in a personal namespace' do
        let_it_be(:project) { create(:project, namespace: create(:user).namespace) }
        let_it_be(:member, freeze: false) { create(:project_member, source: project) }

        it 'returns nothing' do
          expect(member.group_saml_identity(root_ancestor: true)).to be_nil
        end
      end
    end
  end

  describe '#group_scim_identity' do
    shared_examples_for 'member with group scim identity' do
      context 'without saml_provider' do
        it { is_expected.to be_nil }
      end

      context 'with saml_provider enabled' do
        let!(:saml_provider) { create(:saml_provider, group: member.group) }

        context 'when member has no connected identity' do
          it { is_expected.to be_nil }
        end

        context 'when member has connected identity' do
          let!(:group_related_identity) do
            create(:group_scim_identity, user: member.user, group: member.group)
          end

          it 'returns related identity' do
            expect(group_scim_identity).to eq group_related_identity
          end

          context 'when group_scim_identities is preloaded' do
            before do
              member.user.group_scim_identities.load
            end

            it 'returns related identity' do
              expect(group_scim_identity).to eq group_related_identity
            end
          end
        end

        context 'when member has connected identity of different group' do
          before do
            create(:group_scim_identity, user: member.user)
          end

          it { is_expected.to be_nil }
        end
      end
    end

    shared_examples_for 'member with group scim identity on the top level' do
      let!(:saml_provider) { create(:saml_provider, group: parent_group) }

      let!(:group_related_identity) do
        create(:group_scim_identity, user: member.user, group: parent_group)
      end

      it 'does not return identity' do
        expect(member.group_scim_identity).to be_nil
      end
    end

    describe 'for group members' do
      context 'when member is in a top-level group' do
        let_it_be_with_refind(:member) { create(:group_member) }

        subject(:group_scim_identity) { member.group_scim_identity }

        it_behaves_like 'member with group scim identity'
      end

      context 'when member is in a subgroup' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:group) { create(:group, parent: parent_group) }
        let_it_be(:member, freeze: false) { create(:group_member, source: group) }

        it_behaves_like 'member with group scim identity on the top level'
      end
    end

    describe 'for project members' do
      context 'when project is nested in a group' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, namespace: group) }
        let_it_be_with_refind(:member) { create(:project_member, source: project) }

        subject(:group_scim_identity) { member.group_scim_identity }

        it_behaves_like 'member with group scim identity'
      end

      context 'when project is nested in a subgroup' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:group) { create(:group, parent: parent_group) }
        let_it_be(:project) { create(:project, namespace: group) }
        let_it_be(:member, freeze: false) { create(:project_member, source: project) }

        it_behaves_like 'member with group scim identity on the top level'
      end

      context 'when project is nested in a personal namespace' do
        let_it_be(:project) { create(:project, namespace: create(:user).namespace) }
        let_it_be(:member, freeze: false) { create(:project_member, source: project) }

        it 'returns nothing' do
          expect(member.group_scim_identity).to be_nil
        end
      end
    end
  end

  context 'when after_update :post_update_hook' do
    context 'for webhooks', :sidekiq_inline, :saas do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:group_hook) { create(:group_hook, group: group, member_events: true) }
      let_it_be(:user, freeze: false) { create(:user) }

      let(:group_member) { create(:group_member, :developer, group: group, expires_at: 1.day.from_now) }

      it 'executes user_update_for_group event webhook when user role is updated' do
        WebMock.stub_request(:post, group_hook.url)

        group_member.update!(access_level: Gitlab::Access::MAINTAINER)

        expect(WebMock).to have_requested(:post, group_hook.url).with(
          webhook_data(group_member, 'user_update_for_group')
        )
      end

      it 'executes user_update_for_group event webhook when user expiration date is updated' do
        WebMock.stub_request(:post, group_hook.url)

        group_member.update!(expires_at: 2.days.from_now)

        expect(WebMock).to have_requested(:post, group_hook.url).with(
          webhook_data(group_member, 'user_update_for_group')
        )
      end
    end
  end

  context 'check if user cap has been reached', :saas do
    let_it_be_with_refind(:group) do
      create(
        :group_with_plan,
        plan: :ultimate_plan,
        namespace_settings: create(:namespace_settings, seat_control: :user_cap, new_user_signups_cap: 1)
      )
    end

    let_it_be_with_refind(:subgroup) { create(:group, parent: group) }
    let_it_be_with_refind(:project) { create(:project, namespace: group) }
    let_it_be(:user, freeze: false) { create(:user) }

    before_all do
      group.add_developer(create(:user))
    end

    context 'when the user cap has not been reached' do
      before do
        group.namespace_settings.update!(new_user_signups_cap: 10)
      end

      it 'sets the group member to active' do
        group.add_developer(user)

        expect(user.group_members.last).to be_active
      end

      it 'sets the project member to active' do
        project.add_developer(user)

        expect(user.project_members.last).to be_active
      end
    end

    context 'when the user cap has been reached' do
      it 'sets the group member to awaiting' do
        group.add_developer(user)

        expect(user.group_members.last).to be_awaiting
      end

      it 'sets the group member to awaiting when added to a subgroup' do
        subgroup.add_developer(user)

        expect(user.group_members.last).to be_awaiting
      end

      it 'sets the project member to awaiting' do
        project.add_developer(user)

        expect(user.project_members.last).to be_awaiting
      end

      context 'when the user is already an active root group member' do
        it 'sets the group member to active' do
          create(:group_member, :active, group: group, user: user)

          subgroup.add_owner(user)

          expect(user.group_members.last).to be_active
        end
      end

      context 'when the user is already an active subgroup member' do
        it 'sets the group member to active' do
          other_subgroup = create(:group, parent: group)
          create(:group_member, :active, group: other_subgroup, user: user)

          subgroup.add_developer(user)

          expect(user.group_members.last).to be_active
        end
      end

      context 'when the user is already an active project member' do
        it 'sets the group member to active' do
          create(:project_member, :active, project: project, user: user)

          expect { subgroup.add_owner(user) }.to change { ::Member.with_state(:active).count }.by(1)
          expect(user.group_members.last).to be_active
        end
      end
    end

    context 'when user is added to a group-less project' do
      let(:project) { create(:project) }

      it 'adds project member and leaves the state to active' do
        project.add_developer(user)

        expect(user.project_members.last).to be_active
      end
    end
  end

  describe 'when after_create :post_create_hook' do
    context 'for webhooks', :sidekiq_inline, :saas do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:group_hook) { create(:group_hook, group: group, member_events: true) }
      let_it_be(:user, freeze: false) { create(:user) }

      before do
        WebMock.stub_request(:post, group_hook.url)
      end

      it 'executes user_add_to_group event webhook' do
        group_member = create(:group_member, group: group)

        group.add_guest(group_member.user)

        expect(WebMock).to have_requested(:post, group_hook.url).with(
          webhook_data(group_member, 'user_add_to_group')
        )
      end

      context 'for ancestor groups' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:subgroup_hook) { create(:group_hook, group: subgroup, member_events: true) }

        it 'fires two webhooks when parent group has member_events webhook enabled' do
          WebMock.stub_request(:post, subgroup_hook.url)

          subgroup.add_guest(user)

          expect(WebMock).to have_requested(:post, subgroup_hook.url)
          expect(WebMock).to have_requested(:post, group_hook.url)
        end

        it 'fires one webhook when parent group has member_events webhook disabled' do
          group_hook = create(:group_hook, group: group, member_events: false)

          WebMock.stub_request(:post, subgroup_hook.url)

          subgroup.add_guest(user)

          expect(WebMock).to have_requested(:post, subgroup_hook.url)
          expect(WebMock).not_to have_requested(:post, group_hook.url)
        end
      end
    end
  end

  def webhook_data(group_member, event)
    {
      headers: {
        'Content-Type' => 'application/json',
        'User-Agent' => "GitLab/#{Gitlab::VERSION}",
        'X-Gitlab-Event' => 'Member Hook'
      },
      body: {
        created_at: group_member.created_at&.xmlschema,
        updated_at: group_member.updated_at&.xmlschema,
        group_name: group.name,
        group_path: group.path,
        group_id: group.id,
        user_username: group_member.user.username,
        user_name: group_member.user.name,
        user_email: group_member.user.webhook_email,
        user_id: group_member.user.id,
        group_access: group_member.human_access,
        expires_at: group_member.expires_at&.xmlschema,
        group_plan: 'ultimate',
        event_name: event
      }.to_json
    }
  end

  context 'when activating a member', :saas do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:active_member) { create(:group_member, :maintainer, source: group) }
    let_it_be(:active_user) { active_member.user }
    let_it_be(:user) { member.user }

    let(:root_ancestor) { group }

    before do
      allow(root_ancestor).to receive(:user_cap_reached?).and_return(user_cap_reached)
    end

    context 'when limit has been reached and user cap does not apply' do
      let(:user_cap_reached) { false }
      let(:member) { create(:group_member, :awaiting, :maintainer, source: group) }

      it 'activates user' do
        expect do
          member.activate
        end.to change { member.state }.from(described_class::STATE_AWAITING).to(described_class::STATE_ACTIVE)
      end
    end

    context 'when user cap is reached' do
      let(:user_cap_reached) { true }

      let(:member) { create(:group_member, :awaiting, :maintainer, source: group) }

      it 'keeps user awaiting' do
        expect { member.activate }.not_to change { member.state }.from(described_class::STATE_AWAITING)
      end

      context 'when user already has another active membership' do
        context 'with project membership' do
          let(:member) { create(:project_member, :awaiting, :maintainer, source: project, user: active_user) }

          it 'activates member for the same user' do
            expect do
              member.activate
            end.to change { member.state }.from(described_class::STATE_AWAITING).to(described_class::STATE_ACTIVE)
          end
        end

        context 'with sub-group membership' do
          let(:member) { create(:group_member, :awaiting, :maintainer, source: sub_group, user: active_user) }

          it 'activates member for the same user' do
            expect do
              member.activate
            end.to change { member.state }.from(described_class::STATE_AWAITING).to(described_class::STATE_ACTIVE)
          end
        end
      end

      context 'when user has another awaiting membership' do
        let(:member) { create(:project_member, :awaiting, :maintainer, source: project, user: user) }
        let(:root_ancestor) { member.source.root_ancestor }

        it 'keeps the member awaiting' do
          expect { member.activate }.not_to change { member.state }.from(described_class::STATE_AWAITING)
        end
      end
    end
  end

  context 'when setting the member to awaiting' do
    let_it_be_with_refind(:group) { create(:group) }
    let(:member) { create(:group_member, :active, :owner, group: group) }

    context 'when user is the last owner' do
      it 'does not allow the member to be awaiting' do
        expect(member).to be_active

        member.wait

        expect(member).to be_active
      end
    end

    context 'when user is not the last owner' do
      let!(:second_owner) { create(:group_member, :owner, group: group) }

      it 'sets the member to awaiting' do
        expect(member).to be_active

        member.wait

        expect(member).to be_awaiting
      end
    end

    context 'when invite' do
      let_it_be(:member, freeze: false) { create(:group_member, :invited, :active, group: group) }

      it 'sets the member to awaiting' do
        expect(member).to be_active

        member.wait

        expect(member).to be_awaiting
      end
    end
  end

  shared_examples 'maintain_elasticsearch' do |parameter|
    context 'when user exists' do
      let_it_be(:member, freeze: false) { create(:group_member, :owner, group: group) }

      it 'calls track!' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!)

        subject
      end
    end

    context 'when user does not exist' do
      let_it_be(:member, freeze: false) { create(:group_member, :invited, :active, group: group) }

      it 'does not call track!' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

        subject
      end
    end
  end

  describe '#maintaining_elasticsearch?', :elastic, feature_category: :global_search do
    subject { member.maintaining_elasticsearch? }

    context 'when elasticsearch_indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when elasticsearch_indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.maintain_elasticsearch_create', feature_category: :global_search do
    subject { member.maintain_elasticsearch_create }

    include_examples 'maintain_elasticsearch'
  end

  describe '.maintain_elasticsearch_destroy', feature_category: :global_search do
    subject { member.maintain_elasticsearch_destroy }

    include_examples 'maintain_elasticsearch'
  end

  describe '.distinct_awaiting_or_invited_for_group' do
    let_it_be(:other_sub_group) { create(:group, parent: group) }
    let_it_be(:active_group_member) { create(:group_member, group: group) }
    let_it_be(:awaiting_group_member) { create(:group_member, :awaiting, group: group) }
    let_it_be(:awaiting_subgroup_member, freeze: false) { create(:group_member, :awaiting, group: sub_group) }
    let_it_be(:awaiting_other_subgroup_member) { create(:group_member, :awaiting, user: awaiting_subgroup_member.user, group: other_sub_group) }
    let_it_be(:awaiting_project_member) { create(:project_member, :awaiting, project: project) }
    let_it_be(:awaiting_invited_member) { create(:group_member, :awaiting, :invited, group: group) }
    let_it_be(:active_invited_member) { create(:group_member, :invited, group: group) }
    let_it_be(:awaiting_previously_invited_member) do
      member = create(:group_member, :awaiting, :invited, group: group)
      user = create(:user)
      member.accept_invite!(user)

      member
    end

    subject(:results) { described_class.distinct_awaiting_or_invited_for_group(group) }

    it 'returns the correct members' do
      expect(results).to contain_exactly(
        awaiting_group_member,
        awaiting_subgroup_member,
        awaiting_project_member,
        awaiting_invited_member,
        awaiting_previously_invited_member,
        active_invited_member
      )
    end

    it 'does not return additional results for duplicates' do
      create(:group_member, :awaiting, group: sub_group, user: awaiting_group_member.user)
      create(:group_member, :invited, group: sub_group, invite_email: awaiting_invited_member.invite_email)
      create(:group_member, :awaiting, group: sub_group, invite_email: awaiting_previously_invited_member.invite_email, user: awaiting_previously_invited_member.user)

      expect(results.map(&:user_id).compact).to contain_exactly(
        awaiting_group_member.user_id,
        awaiting_subgroup_member.user_id,
        awaiting_project_member.user_id,
        awaiting_previously_invited_member.user_id
      )

      expect(results.map(&:invite_email).compact).to contain_exactly(
        awaiting_invited_member.invite_email,
        active_invited_member.invite_email,
        awaiting_previously_invited_member.invite_email
      )
    end
  end

  describe '.banned_from scope' do
    let!(:group) { create :group }
    let!(:member1) { create :group_member, :developer, source: group }
    let!(:member2) { create :group_member, :developer, source: group }
    let!(:ban) { create :namespace_ban, namespace: group, user: member1.user }

    it 'returns only banned members from the given namespace' do
      expect(described_class.count).to eq 2
      expect(described_class.banned_from(group).map(&:user_id)).to match_array([member1.user_id])
    end
  end

  describe '.not_banned_in scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be(:banned_group_member) { create(:group_member, :banned, :developer, source: group) }
    let_it_be(:banned_project_member) { create(:project_member, :banned, :developer, source: project) }

    let_it_be(:group_member) { create(:group_member, :developer, source: group) }
    let_it_be(:project_member) { create(:project_member, :developer, source: project) }

    subject(:not_banned_in) { described_class.not_banned_in(group) }

    it { is_expected.to exclude banned_group_member }
    it { is_expected.to exclude banned_project_member }
    it { is_expected.to include group_member }
    it { is_expected.to include project_member }
  end

  describe '.elevated_guests scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:member_role_elevating) { create(:member_role, :billable, namespace: group) }
    let_it_be(:member_role_basic) { create(:member_role, :non_billable, namespace: group) }

    let_it_be(:member1) { create(:group_member, :developer, source: group) }
    let_it_be(:member2) { create(:group_member, :guest, source: group, member_role: member_role_elevating) }
    let_it_be(:member3) { create(:group_member, :guest, source: group, member_role: member_role_basic) }

    it 'returns only guests with elevated role' do
      expect(MemberRole).to receive(:occupies_seat).at_least(:once).and_return(MemberRole.where(id: member_role_elevating.id))

      expect(described_class.elevated_guests).to contain_exactly(member2)
    end
  end

  describe '.with_elevated_guests scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:member_role_elevating) { create(:member_role, :billable, namespace: group) }
    let_it_be(:member_role_basic) { create(:member_role, :non_billable, namespace: group) }

    let_it_be(:member1) { create(:group_member, :developer, source: group) }
    let_it_be(:member2) { create(:group_member, :guest, source: group, member_role: member_role_elevating) }
    let_it_be(:member3) { create(:group_member, :guest, source: group, member_role: member_role_basic) }

    it 'returns only members above guest or guests with elevated role' do
      expect(described_class.with_elevated_guests).to match_array([member1, member2])
      expect(described_class.with_elevated_guests).not_to include(member3)
    end
  end

  # TODO: remove when `use_user_group_member_roles_members_page` is rolled out
  # and is being cleaned up, https://gitlab.com/gitlab-org/gitlab/-/issues/576194
  describe '.shared_members', feature_category: :permissions do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:shared_group) { create(:group) }
    let_it_be(:invited_group) { create(:group) }

    where(:user_access, :group_access, :expected_access_level, :expected_member_role) do
      10 | 30 | 10 | ref(:user_role)
      30 | 10 | 10 | ref(:group_role)
      10 | 10 | 10 | ref(:user_role)
    end

    with_them do
      let(:user_role) { create(:member_role, base_access_level: user_access, namespace: invited_group) }
      let(:group_role) { create(:member_role, base_access_level: group_access, namespace: shared_group) }

      let(:member) do
        create(:group_member,
          user: user,
          source: invited_group,
          member_role: user_role,
          access_level: user_access
        )
      end

      before do
        create(:group_group_link,
          group_access: group_access,
          shared_group: shared_group,
          shared_with_group: invited_group,
          member_role: group_role
        )
      end

      subject(:members) do
        described_class
          .shared_members(shared_group)
          .id_in(member.id).to_a
      end

      shared_examples 'invited group members' do
        it 'returns minimum access level and expected member role' do
          expect(members.size).to eq(1)
          expect(members.first.access_level).to eq(expected_access_level)
          expect(members.first.member_role_id).to eq expected_member_role.id
        end

        context 'when user is also a direct member of the group' do
          let_it_be(:role) { create(:member_role, :developer, namespace: shared_group) }

          let_it_be(:direct_member, freeze: false) do
            create(:group_member,
              user: user,
              source: shared_group,
              member_role: role,
              access_level: Gitlab::Access::DEVELOPER
            )
          end

          it 'returns minimum access level and expected member role' do
            expect(members.size).to eq(1)
            expect(members.first.access_level).to eq(expected_access_level)
            expect(members.first.member_role_id).to eq expected_member_role.id
          end
        end
      end

      context 'when custom roles are enabled' do
        before do
          allow(shared_group).to receive(:custom_roles_enabled?).and_return(true)
        end

        context 'when `use_user_group_member_roles_members_page` feature flag is disabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: false)
          end

          it_behaves_like 'invited group members'
        end

        context 'when `use_user_group_member_roles_members_page` feature flag is enabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: true)
          end

          it 'returns minimum access level and nil member role' do
            expect(members.size).to eq(1)
            expect(members.first.access_level).to eq(expected_access_level)
            expect(members.first.member_role_id).to be_nil
          end
        end
      end

      context 'when custom roles are not enabled' do
        before do
          allow(shared_group).to receive(:custom_roles_enabled?).and_return(false)
        end

        it 'returns minimum access level and nil member role' do
          expect(members.size).to eq(1)
          expect(members.first.access_level).to eq(expected_access_level)
          expect(members.first.member_role_id).to be_nil
        end
      end
    end
  end

  describe '.shared_members_with_member_role', feature_category: :permissions do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:shared_group) { create(:group) }
    let_it_be(:invited_group) { create(:group) }

    where(:user_access, :group_access, :expected_member_role) do
      10 | 30 | ref(:user_role)
      30 | 10 | ref(:group_role)
      10 | 10 | ref(:user_role)
    end

    with_them do
      let(:user_role) { create(:member_role, base_access_level: user_access, namespace: invited_group) }
      let(:group_role) { create(:member_role, base_access_level: group_access, namespace: shared_group) }

      let(:member) do
        create(:group_member,
          user: user,
          source: invited_group,
          member_role: user_role,
          access_level: user_access
        )
      end

      before do
        create(:group_group_link,
          group_access: group_access,
          shared_group: shared_group,
          shared_with_group: invited_group,
          member_role: group_role
        )
      end

      subject(:members) do
        described_class
          .id_in(member.id)
          .shared_members_with_member_role(shared_group)
          .to_a
      end

      shared_examples 'invited group members' do
        it 'returns expected member role' do
          expect(members.size).to eq(1)
          expect(members.first.member_role_id).to eq expected_member_role.id
        end

        context 'when user is also a direct member of the group' do
          let_it_be(:role) { create(:member_role, :developer, namespace: shared_group) }

          let_it_be(:direct_member, freeze: false) do
            create(:group_member,
              user: user,
              source: shared_group,
              member_role: role,
              access_level: Gitlab::Access::DEVELOPER
            )
          end

          it 'returns minimum access level and expected member role' do
            expect(members.size).to eq(1)
            expect(members.first.member_role_id).to eq expected_member_role.id
          end
        end
      end

      context 'when custom roles are enabled' do
        before do
          allow(shared_group).to receive(:custom_roles_enabled?).and_return(true)
        end

        context 'when `use_user_group_member_roles_members_page` feature flag is enabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: true)
          end

          it_behaves_like 'invited group members'
        end

        context 'when `use_user_group_member_roles_members_page` feature flag is disabled' do
          before do
            stub_feature_flags(use_user_group_member_roles_members_page: false)
          end

          it 'returns an empty result' do
            expect(members).to be_empty
          end
        end
      end

      context 'when custom roles are not enabled' do
        before do
          allow(shared_group).to receive(:custom_roles_enabled?).and_return(false)
        end

        it 'returns an empty result' do
          expect(members).to be_empty
        end
      end
    end
  end

  describe "user's Authz::UserGroupMemberRole records" do
    shared_examples "updates the user's Authz::UserGroupMemberRole records" do |factory_args = []|
      let_it_be(:member, freeze: false) { create(:group_member, :guest, *factory_args) }

      it 'executes ::Authz::UserGroupMemberRoles::UpdateForGroupMemberService' do
        expect_next_instance_of(::Authz::UserGroupMemberRoles::UpdateForGroupMemberService,
          member, old_values_map: nil) do |service|
          expect(service).to receive(:execute)
        end

        call_method
      end
    end

    describe '#update_user_group_member_roles' do
      subject(:call_method) { member.update_user_group_member_roles }

      it_behaves_like "updates the user's Authz::UserGroupMemberRole records"
    end

    context "after invite is accepted" do
      let(:user) { build(:user, email: member.invite_email) }

      subject(:call_method) { member.accept_invite!(user) }

      it_behaves_like "updates the user's Authz::UserGroupMemberRole records", [:invited]
    end

    context "after access request is granted" do
      subject(:call_method) { member.accept_request(create(:user)) }

      it_behaves_like "updates the user's Authz::UserGroupMemberRole records", [:access_request]
    end
  end
end

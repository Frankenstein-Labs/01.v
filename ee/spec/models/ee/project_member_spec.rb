# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectMember, feature_category: :groups_and_projects do
  it { is_expected.to include_module(EE::ProjectMember) }

  it_behaves_like 'member validations' do
    let(:entity) { create(:project, group: group) }
  end

  context 'validates GMA enforcement' do
    let_it_be(:group) { create(:group_with_managed_accounts, :private) }
    let_it_be(:entity) { create(:project, namespace: group) }

    before do
      stub_feature_flags(group_managed_accounts: true)
    end

    context 'enforced group managed account enabled' do
      before do
        stub_licensed_features(group_saml: true)
      end

      it 'allows adding a user linked to the GMA account as project member' do
        user = create(:user, :group_managed, managing_group: group)
        member = entity.add_developer(user)

        expect(member).to be_valid
      end

      it 'does not allow adding a user not linked to the GMA account as project member' do
        member = entity.add_developer(create(:user))

        expect(member).not_to be_valid
        expect(member.errors.messages[:user]).to include('is not in the group enforcing Group Managed Account')
      end

      it 'allows adding a project bot' do
        member = entity.add_developer(create(:user, :project_bot))

        expect(member).to be_valid
      end
    end

    context 'enforced group managed account disabled' do
      it 'allows adding any user as project member' do
        member = entity.add_developer(create(:user))

        expect(member).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.eligible_approvers_ids_by_project_id_and_custom_roles' do
      let_it_be_with_reload(:project) { create(:project) }

      let_it_be(:guest) { create(:user) }
      let(:custom_roles) { [guest_role_admin_mr] }

      let_it_be(:guest_role_admin_mr) do
        create(:member_role, :guest, :admin_merge_request, namespace: nil, organization: guest.organization)
      end

      let_it_be(:guest_with_role) do
        create(:project_member, :guest, source: project, member_role: guest_role_admin_mr).user
      end

      subject(:approver_ids) do
        described_class
          .eligible_approvers_ids_by_project_id_and_custom_roles(project.id, custom_roles).map(&:user_id)
      end

      it 'returns members with the custom role' do
        expect(approver_ids).to contain_exactly(guest_with_role.id)
      end
    end
  end

  describe '#group_domain_validations' do
    let(:member_type) { :project_member }
    let(:source) { create(:project, namespace: group) }
    let(:subgroup) { create(:group, parent: group) }
    let(:nested_source) { create(:project, namespace: subgroup) }

    it_behaves_like 'member group domain validations', 'project'

    it 'does not validate personal projects' do
      unconfirmed_gitlab_user = create(:user, :unconfirmed, email: 'unverified@gitlab.com')
      member = create(:project, namespace: create(:user).namespace).add_developer(unconfirmed_gitlab_user)

      expect(member).to be_valid
    end
  end

  describe 'security policy project bot validation' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

    it 'allows to be added to project' do
      member = project.add_guest(security_policy_bot)

      expect(member).to be_valid
    end
  end

  describe 'only one security policy bot validation' do
    let_it_be(:user1) { create(:user, :security_policy_bot) }
    let_it_be(:user2) { create(:user, :security_policy_bot) }
    let_it_be(:user3) { create(:user) }
    let_it_be_with_reload(:project) { create(:project) }

    it 'allows only one member of type security_policy_bot' do
      expect { create(:project_member, user: user1, project: project) }.not_to raise_error
      expect { create(:project_member, user: user2, project: project) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { create(:project_member, user: user3, project: project) }.not_to raise_error
    end

    it 'does not throw an error if user is nil' do
      expect { create(:project_member, :invited) }.not_to raise_error
    end
  end

  context 'SSO enforcement for project-provisioned service accounts' do
    let_it_be(:root_group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, namespace: root_group) }
    let_it_be(:saml_provider) { create(:saml_provider, group: root_group, enforced_sso: true) }

    let(:project_sa) do
      create(:user, :service_account).tap do |user|
        user.user_detail.update!(provisioned_by_project_id: project.id)
      end
    end

    before do
      stub_licensed_features(group_saml: true)
    end

    it 'allows adding a project-provisioned SA to its origin project' do
      member = project.add_developer(project_sa)

      expect(member).to be_valid
    end

    it 'does not allow adding a project-provisioned SA to a different project in the same group' do
      other_project = create(:project, namespace: root_group)

      member = other_project.add_developer(project_sa)

      expect(member).not_to be_valid
    end

    it 'does not allow adding a project-provisioned SA to the parent group' do
      member = root_group.add_developer(project_sa)

      expect(member).not_to be_valid
    end
  end

  describe '#membership_enforcer' do
    it 'passes the project to MembershipEnforcer' do
      project = create(:project, group: create(:group))
      member = build(:project_member, source: project)

      expect(Gitlab::Auth::GroupSaml::MembershipEnforcer)
        .to receive(:new).with(project.group, project: project)
        .and_call_original

      member.send(:membership_enforcer)
    end
  end

  describe '#enterprise_user_of_this_group?' do
    let_it_be(:member) { build(:project_member) }

    subject { member.enterprise_user_of_this_group? }

    it { is_expected.to be(false) }
  end

  describe '#state' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }

    describe '#activate!' do
      it "refreshes the user's authorized projects" do
        membership = create(:project_member, :awaiting, source: project, user: user)

        expect(user.authorized_projects).not_to include(project)

        membership.activate!

        expect(user.authorized_projects.reload).to include(project)
      end
    end

    describe '#wait!' do
      it "refreshes the user's authorized projects" do
        membership = create(:project_member, source: project, user: user)

        expect(user.authorized_projects).to include(project)

        membership.wait!

        expect(user.authorized_projects.reload).not_to include(project)
      end
    end
  end

  describe 'delete protected environment acceses cascadingly' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:environment) { create(:environment, project: project) }
    let_it_be(:protected_environment) do
      create(:protected_environment, project: project, name: environment.name)
    end

    let!(:member) { create(:project_member, project: project, user: user) }

    let!(:deploy_access) do
      create(:protected_environment_deploy_access_level, protected_environment: protected_environment, user: user)
    end

    let!(:deploy_access_for_diffent_user) do
      create(:protected_environment_deploy_access_level, protected_environment: protected_environment,
        user: create(:user))
    end

    let!(:deploy_access_for_group) do
      create(:protected_environment_deploy_access_level, protected_environment: protected_environment,
        group: create(:group))
    end

    let!(:deploy_access_for_maintainer_role) do
      create(:protected_environment_deploy_access_level, :maintainer_access,
        protected_environment: protected_environment)
    end

    it 'deletes associated protected environment access cascadingly' do
      expect { member.destroy! }
        .to change { ProtectedEnvironments::DeployAccessLevel.count }.by(-1)

      expect { deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(protected_environment.reload.deploy_access_levels)
        .to include(deploy_access_for_diffent_user, deploy_access_for_group, deploy_access_for_maintainer_role)
    end

    context 'when the user is assiged to multiple protected environments in the same project' do
      let!(:other_protected_environment) { create(:protected_environment, project: project, name: 'staging') }
      let!(:other_deploy_access) do
        create(:protected_environment_deploy_access_level, protected_environment: other_protected_environment,
          user: user)
      end

      it 'deletes all associated protected environment accesses in the project' do
        expect { member.destroy! }
          .to change { ProtectedEnvironments::DeployAccessLevel.count }.by(-2)

        expect { deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { other_deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when the user is assiged to multiple protected environments across different projects' do
      let!(:other_project) { create(:project) }
      let!(:other_protected_environment) { create(:protected_environment, project: other_project, name: 'staging') }
      let!(:other_deploy_access) do
        create(:protected_environment_deploy_access_level, protected_environment: other_protected_environment,
          user: user)
      end

      it 'deletes all associated protected environment accesses in the project' do
        expect { member.destroy! }
          .to change { ProtectedEnvironments::DeployAccessLevel.count }.by(-1)

        expect { deploy_access.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { other_deploy_access.reload }.not_to raise_error
      end
    end
  end

  describe 'deletes member branch access rules cascadingly' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }
    # `freeze: false` is required here: this `let_it_be` subject is mutated
    # in-memory across examples in a way that survives both
    # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
    # association/collection or a non-persisted attribute). Keeping it unfrozen
    # is the only correct cure (see gitlab-org/gitlab#602925).
    let_it_be(:protected_branches, freeze: false) { create_list(:protected_branch, 2, project: project) }

    let!(:member) { create(:project_member, project: project, user: user) }

    it 'deletes all associated merge_access_levels in the project' do
      protected_branches.each do |protected_branch|
        protected_branch.merge_access_levels.create!(user: user)
      end

      expect { member.destroy! }
        .to change { ProtectedBranch::MergeAccessLevel.count }.by(-2)
    end

    it 'deletes all associated push_access_levels in the project' do
      protected_branches.each do |protected_branch|
        protected_branch.push_access_levels.create!(user: user)
      end

      expect { member.destroy! }
        .to change { ProtectedBranch::PushAccessLevel.count }.by(-2)
    end

    context 'when user still has inherited access to the project' do
      let!(:inherited_membership) { group.add_guest(user) }

      it 'does not delete associated merge_access_levels in the project' do
        protected_branches.each do |protected_branch|
          protected_branch.merge_access_levels.create!(user: user)
        end

        expect { member.destroy! }
          .not_to change { ProtectedBranch::MergeAccessLevel.count }
      end

      it 'does not delete associated push_access_levels in the project' do
        protected_branches.each do |protected_branch|
          protected_branch.push_access_levels.create!(user: user)
        end

        expect { member.destroy! }
          .not_to change { ProtectedBranch::PushAccessLevel.count }
      end
    end
  end

  describe '#accept_invite!' do
    let(:member) { create(:project_member, :invited) }
    let(:user) { create(:user) }

    it 'does not accept invite if group locks memberships for projects' do
      expect(member).to receive_message_chain(:source, :membership_locked?).and_return(true)

      member.accept_invite! user

      expect(member.user).to be_nil
      expect(member.invite_accepted_at).to be_nil
      expect(member.invite_token).not_to be_nil
      expect(member).not_to receive(:after_accept_invite)
    end
  end

  describe '#prevent_role_assignement?' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be_with_reload(:current_user) { create(:user) }
    let_it_be_with_reload(:member) do
      create(:project_member, access_level: Gitlab::Access::GUEST, project: project)
    end

    let(:member_role_id) { nil }
    let(:access_level) { Gitlab::Access::GUEST }
    let(:params) { { member_role_id: member_role_id, access_level: access_level } }

    subject(:prevent_assignement?) { member.prevent_role_assignement?(current_user, params) }

    context 'for custom roles assignement' do
      let_it_be(:member_role_current_user) do
        create(:member_role, :maintainer, admin_merge_request: true, namespace: project.namespace)
      end

      let_it_be(:member_role_less_abilities) do
        create(:member_role, :guest, admin_merge_request: true, namespace: project.namespace)
      end

      let_it_be(:member_role_more_abilities) do
        create(:member_role, :guest, admin_merge_request: true, admin_push_rules: true, remove_project: true,
          namespace: project.namespace)
      end

      before_all do
        current_member = project.add_maintainer(current_user)
        current_member.update!(member_role: member_role_current_user)
      end

      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'with the same custom role as current user has' do
        let(:member_role_id) { member_role_current_user.id }

        it 'allows role assignement' do
          expect(prevent_assignement?).to be(false)
        end
      end

      context "with custom role abilities included in the current user's base access" do
        let_it_be(:member_role_included_abilities) do
          create(:member_role, :guest, admin_merge_request: true, admin_push_rules: true, namespace: project.namespace)
        end

        let(:member_role_id) { member_role_included_abilities.id }

        it 'allows role assignement' do
          expect(prevent_assignement?).to be(false)
        end
      end

      context 'with the custom role having less abilities than current user has' do
        let(:member_role_id) { member_role_less_abilities.id }

        it 'returns false' do
          expect(prevent_assignement?).to be(false)
        end
      end

      context 'with the custom role having more abilities than current user has' do
        let(:member_role_id) { member_role_more_abilities.id }

        it 'returns true' do
          expect(prevent_assignement?).to be(true)
        end

        context 'when current user is an admin', :enable_admin_mode do
          before do
            current_user.members.delete_all

            current_user.update!(admin: true)
          end

          it 'returns false' do
            expect(prevent_assignement?).to be(false)
          end
        end
      end

      context 'when member has a custom role with permissions the current user lacks' do
        let_it_be(:member_role) do
          create(:member_role, :maintainer, namespace: project.namespace, read_compliance_dashboard: true)
        end

        let_it_be_with_reload(:member) do
          create(:project_member, :maintainer, project: project, member_role: member_role)
        end

        it { is_expected.to be(true) }
      end

      context 'when member has a custom role with only permissions the current user also has' do
        let_it_be(:member_role) do
          create(:member_role, :maintainer, namespace: project.namespace, manage_merge_request_settings: true)
        end

        let_it_be_with_reload(:member) do
          create(:project_member, :maintainer, project: project, member_role: member_role)
        end

        before do
          project.member(current_user).update!(member_role: member_role)
        end

        it { is_expected.to be(false) }
      end

      context 'when member has no custom role' do
        let_it_be_with_reload(:member) do
          create(:project_member, :maintainer, project: project)
        end

        it { is_expected.to be(false) }
      end
    end
  end
end

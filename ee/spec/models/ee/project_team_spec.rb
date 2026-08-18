# frozen_string_literal: true

require "spec_helper"

RSpec.describe ProjectTeam, feature_category: :groups_and_projects do
  describe '#import_team' do
    let_it_be(:source_project) { create(:project) }
    let_it_be(:target_project) { create(:project) }
    let_it_be(:source_project_developer) { create(:user) { |user| source_project.add_developer(user) } }
    let_it_be(:current_user) { create(:user) { |user| target_project.add_maintainer(user) } }

    subject(:import) { target_project.team.import(source_project, current_user) }

    it 'does not cause N+1 queries when checking user types' do
      control = ActiveRecord::QueryRecorder.new { target_project.team.import(source_project, current_user) }

      create(:user, :security_policy_bot) { |user| source_project.add_guest(user) }

      expect { import }.not_to exceed_query_limit(control)
    end

    context 'when a source project member is a security policy bot' do
      let_it_be(:source_project_security_policy_bot) do
        create(:user, :security_policy_bot) { |user| source_project.add_guest(user) }
      end

      it 'does not import the security policy bot user' do
        import

        expect(target_project.members.find_by(user: source_project_security_policy_bot)).to be_nil
      end
    end

    context 'when a maintainer tries to import a project team with custom roles that have higher privileges' do
      let_it_be(:member_role_with_high_privileges) do
        create(:member_role, :developer, admin_merge_request: true, admin_push_rules: true, remove_project: true,
          namespace: source_project.namespace)
      end

      let_it_be(:source_member_with_custom_role) do
        create(:user).tap do |user|
          member = source_project.add_developer(user)
          member.update!(member_role: member_role_with_high_privileges)
        end
      end

      let_it_be(:current_user_maintainer) do
        create(:user).tap { |user| target_project.add_maintainer(user) }
      end

      before do
        stub_licensed_features(custom_roles: true)
      end

      subject(:import) { target_project.team.import(source_project, current_user_maintainer) }

      it 'adds error to members with custom roles that cannot be assigned' do
        imported_members = import

        prevented_member = imported_members.find { |m| m.user == source_member_with_custom_role }

        expect(prevented_member.errors[:base]).to include("Insufficient permissions to assign this member")
      end

      it 'does not save members with prevented custom role assignments' do
        expect { import }.not_to change {
          target_project.project_members.where(user: source_member_with_custom_role).count
        }
      end
    end
  end

  describe '#add_members' do
    subject(:add_members) { project.team.add_members(users_to_add, :reporter) }

    shared_examples 'adds the users to the team' do
      it 'adds the users to the team' do
        result = add_members

        expect(result.map(&:user_id)).to match_array(users_to_add.map(&:id))
        expect(project.members.map(&:user)).to include(*users_to_add)
      end
    end

    shared_examples 'does not add the users to the team' do
      it 'does not add the users to the team' do
        expect(add_members).to be(false)

        expect(project.members.map(&:user)).not_to include(*users_to_add)
      end
    end

    context 'when group membership is locked' do
      let_it_be_with_reload(:group) { create(:group, membership_lock: true) }
      let_it_be_with_reload(:project) { create(:project, group: group) }

      context 'when users are regular users' do
        let_it_be(:users_to_add) { create_list(:user, 2) }

        it_behaves_like 'does not add the users to the team'
      end

      context 'when all users are project bots' do
        let_it_be(:users_to_add) { create_list(:user, 2, :project_bot) }

        it_behaves_like 'adds the users to the team'
      end

      context 'when all users are security policy bots' do
        let_it_be(:users_to_add) { [create(:user, :security_policy_bot)] }

        it_behaves_like 'adds the users to the team'
      end

      context 'when all users are service accounts with composite identity enforced' do
        let_it_be(:users_to_add) { create_list(:user, 2, :service_account, composite_identity_enforced: true) }

        it_behaves_like 'adds the users to the team'
      end

      context 'when all users are service accounts without composite identity enforced' do
        let_it_be(:users_to_add) { create_list(:user, 2, :service_account) }

        it_behaves_like 'does not add the users to the team'
      end

      context 'when users include a mix of bot and non-bot users' do
        let_it_be(:users_to_add) { [create(:user, :project_bot), create(:user)] }

        it_behaves_like 'does not add the users to the team'
      end
    end

    context 'when group membership is not locked' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }
      let_it_be(:users_to_add) { create_list(:user, 2) }

      it_behaves_like 'adds the users to the team'
    end
  end

  describe '#add_member' do
    let_it_be_with_reload(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:user) { create(:user) }

    context 'when group membership is locked' do
      before do
        group.update_attribute(:membership_lock, true)
      end

      it 'does not add the given user to the team' do
        project.team.add_member(user, :reporter)

        expect(project.members.map(&:user)).not_to include(user)
      end

      context 'when user is a project bot' do
        let_it_be(:project_bot) { create(:user, :project_bot) }

        it 'adds the project bot user to the team' do
          project.team.add_member(project_bot, :maintainer)

          expect(project.members.map(&:user)).to include(project_bot)
        end
      end

      context 'when user is a security policy bot' do
        let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

        it 'adds the project bot user to the team' do
          project.team.add_member(security_policy_bot, :maintainer)

          expect(project.members.map(&:user)).to include(security_policy_bot)
        end
      end

      context 'when user is a service account user with composite identity enforced' do
        let(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

        it 'adds the user to the team' do
          project.team.add_member(service_account, :maintainer)

          expect(project.members.map(&:user)).to include(service_account)
        end
      end

      context 'when user is a service account user without composite identity enforced' do
        let(:service_account) { create(:user, :service_account) }

        it 'does not add the user to the team' do
          project.team.add_member(service_account, :reporter)

          expect(project.members.map(&:user)).not_to include(service_account)
        end
      end
    end
  end

  describe '#members_with_access_level_or_custom_roles' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be(:custom_role) { create(:member_role) }

    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:reporter) { create(:user) }

    let_it_be(:levels) { [] }
    let_it_be(:member_role_ids) { [] }

    before do
      create(:project_member, :developer, project: project, user: developer, member_role: custom_role)
      create(:project_member, :maintainer, project: project, user: maintainer)
      create(:project_member, :reporter, project: project, user: reporter)
    end

    subject(:members_with_access_level_or_custom_roles) do
      project.team.members_with_access_level_or_custom_roles(levels: levels, member_role_ids: member_role_ids)
    end

    context 'when no parameters are provided' do
      it { is_expected.to be_empty }
    end

    context 'when filtering by access level' do
      let_it_be(:levels) { [Gitlab::Access::MAINTAINER] }

      it { is_expected.to contain_exactly(maintainer) }
    end

    context 'when filtering by custom roles' do
      let_it_be(:member_role_ids) { [custom_role.id] }

      it { is_expected.to contain_exactly(developer) }
    end

    context 'when filtering by both access level and custom roles' do
      let_it_be(:levels) { [Gitlab::Access::MAINTAINER] }
      let_it_be(:member_role_ids) { [custom_role.id] }

      it { is_expected.to contain_exactly(developer, maintainer) }
    end

    context 'when filtering with non-existent custom role' do
      let_it_be(:member_roles_id) { [non_existing_record_id] }

      it { is_expected.to be_empty }
    end

    context 'when a group is shared with the project\'s group with a custom role' do
      let_it_be(:shared_group) { create(:group) }
      let_it_be(:shared_group_user) { create(:user) }
      let_it_be(:shared_group_custom_role) { create(:member_role, namespace: group) }

      before do
        create(:group_member, :developer, group: shared_group, user: shared_group_user)

        create(:group_group_link, :guest,
          shared_group: group,
          shared_with_group: shared_group,
          member_role: shared_group_custom_role
        )
      end

      context 'when filtering by the custom role assigned through group sharing' do
        let_it_be(:levels) { [Gitlab::Access::DEVELOPER] }
        let_it_be(:member_role_ids) { [shared_group_custom_role.id] }

        it 'returns users from both project membership and shared group with custom role' do
          expect(members_with_access_level_or_custom_roles).to contain_exactly(developer, shared_group_user)
        end
      end
    end

    context 'when a group is shared with the project with an access level' do
      let_it_be(:shared_group) { create(:group) }
      let_it_be(:shared_group_developer) { create(:user) }
      let_it_be(:shared_group_maintainer) { create(:user) }

      before do
        create(:group_member, :developer, group: shared_group, user: shared_group_developer)
        create(:group_member, :maintainer, group: shared_group, user: shared_group_maintainer)

        create(:project_group_link, :guest, project: project, group: shared_group)
      end

      context 'when filtering by the effective access level (minimum of group share and member access)' do
        let_it_be(:levels) { [Gitlab::Access::GUEST] }
        let_it_be(:member_role_ids) { [] }

        it 'returns users with effective access level matching the filter' do
          expect(members_with_access_level_or_custom_roles).to contain_exactly(
            shared_group_developer,
            shared_group_maintainer
          )
        end
      end

      context 'when filtering by access level higher than the group share access' do
        let_it_be(:levels) { [Gitlab::Access::DEVELOPER] }
        let_it_be(:member_role_ids) { [] }

        it 'does not return users because effective access is limited by group share' do
          expect(members_with_access_level_or_custom_roles).not_to include(
            shared_group_developer,
            shared_group_maintainer
          )
        end
      end
    end

    context 'when user has memberships at both project and group levels with different roles' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:test_project) { create(:project, group: root_group) }
      let_it_be(:user_with_multiple_memberships) { create(:user) }
      let_it_be(:project_only_user) { create(:user) }
      let_it_be(:group_only_user) { create(:user) }
      let_it_be(:another_user_with_multiple_memberships) { create(:user) }
      let_it_be(:group_custom_role) { create(:member_role, namespace: root_group) }
      let_it_be(:project_custom_role) { create(:member_role, namespace: root_group) }

      before do
        create(:project_member, :developer, project: test_project, user: user_with_multiple_memberships,
          member_role: project_custom_role)
        create(:group_member, :developer, group: root_group, user: user_with_multiple_memberships,
          member_role: group_custom_role)

        create(:project_member, :developer, project: test_project, user: project_only_user,
          member_role: project_custom_role)

        create(:group_member, :developer, group: root_group, user: group_only_user,
          member_role: group_custom_role)

        create(:project_member, :maintainer, project: test_project, user: another_user_with_multiple_memberships,
          member_role: project_custom_role)
        create(:group_member, :maintainer, group: root_group, user: another_user_with_multiple_memberships,
          member_role: group_custom_role)
      end

      subject(:members_with_access_level_or_custom_roles) do
        test_project.team.members_with_access_level_or_custom_roles(levels: levels, member_role_ids: member_role_ids)
      end

      context 'when filtering by access level present at both levels' do
        let_it_be(:levels) { [Gitlab::Access::DEVELOPER] }
        let_it_be(:member_role_ids) { [] }

        it 'returns users based on their project membership, not group membership' do
          expect(members_with_access_level_or_custom_roles).to contain_exactly(
            user_with_multiple_memberships,
            group_only_user,
            project_only_user
          )
        end
      end

      context 'when filtering by project-level custom role' do
        let_it_be(:levels) { [] }
        let_it_be(:member_role_ids) { [project_custom_role.id] }

        it 'returns users based on their project membership, not group membership' do
          expect(members_with_access_level_or_custom_roles).to contain_exactly(
            user_with_multiple_memberships,
            project_only_user,
            another_user_with_multiple_memberships
          )
        end
      end

      context 'when filtering by custom role that only exists at group level' do
        let_it_be(:levels) { [] }
        let_it_be(:member_role_ids) { [group_custom_role.id] }

        it 'does not return users with project membership when filtering by group custom role' do
          expect(members_with_access_level_or_custom_roles).to contain_exactly(group_only_user,
            user_with_multiple_memberships, another_user_with_multiple_memberships)
          expect(members_with_access_level_or_custom_roles).not_to include(project_only_user)
        end
      end
    end
  end

  describe '#user_exists_with_access_level_or_custom_roles?' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:custom_role) { create(:member_role) }
    let_it_be(:another_custom_role) { create(:member_role) }

    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:reporter) { create(:user) }
    let_it_be(:guest) { create(:user) }
    let_it_be(:non_member) { create(:user) }

    before do
      create(:project_member, :developer, project: project, user: developer, member_role: custom_role)
      create(:project_member, :maintainer, project: project, user: maintainer)
      create(:project_member, :reporter, project: project, user: reporter)
      create(:project_member, :guest, project: project, user: guest)
    end

    subject(:user_exists) do
      project.team.user_exists_with_access_level_or_custom_roles?(user, levels: levels,
        member_role_ids: member_role_ids)
    end

    context 'when no parameters are provided' do
      let(:levels) { [] }
      let(:member_role_ids) { [] }
      let(:user) { developer }

      it 'returns false' do
        expect(user_exists).to be false
      end
    end

    context 'when filtering by access level' do
      let(:levels) { [Gitlab::Access::MAINTAINER] }
      let(:member_role_ids) { [] }

      context 'when user has the specified access level' do
        let(:user) { maintainer }

        it 'returns true' do
          expect(user_exists).to be true
        end
      end

      context 'when user does not have the specified access level' do
        let(:user) { developer }

        it 'returns false' do
          expect(user_exists).to be false
        end
      end

      context 'when user is not a member of the project' do
        let(:user) { non_member }

        it 'returns false' do
          expect(user_exists).to be false
        end
      end

      context 'when filtering by multiple access levels' do
        let(:levels) { [Gitlab::Access::MAINTAINER, Gitlab::Access::REPORTER] }
        let(:member_role_ids) { [] }

        context 'when user has one of the specified access levels' do
          let(:user) { maintainer }

          it 'returns true' do
            expect(user_exists).to be true
          end
        end

        context 'when user has another of the specified access levels' do
          let(:user) { reporter }

          it 'returns true' do
            expect(user_exists).to be true
          end
        end

        context 'when user does not have any of the specified access levels' do
          let(:user) { guest }

          it 'returns false' do
            expect(user_exists).to be false
          end
        end
      end
    end

    context 'when filtering by custom roles' do
      let(:levels) { [] }
      let(:member_role_ids) { [custom_role.id] }

      context 'when user has the specified custom role' do
        let(:user) { developer }

        it 'returns true' do
          expect(user_exists).to be true
        end
      end

      context 'when user does not have the specified custom role' do
        let(:user) { maintainer }

        it 'returns false' do
          expect(user_exists).to be false
        end
      end

      context 'when user is not a member of the project' do
        let(:user) { non_member }

        it 'returns false' do
          expect(user_exists).to be false
        end
      end

      context 'when filtering by multiple custom roles' do
        let(:member_role_ids) { [custom_role.id, another_custom_role.id] }

        context 'when user has one of the specified custom roles' do
          let(:user) { developer }

          it 'returns true' do
            expect(user_exists).to be true
          end
        end

        context 'when user does not have any of the specified custom roles' do
          let(:user) { maintainer }

          it 'returns false' do
            expect(user_exists).to be false
          end
        end
      end

      context 'when filtering with non-existent custom role' do
        let(:member_role_ids) { [non_existing_record_id] }

        context 'when user is a member' do
          let(:user) { developer }

          it 'returns false' do
            expect(user_exists).to be false
          end
        end
      end
    end

    context 'when filtering by both access level and custom roles' do
      let(:levels) { [Gitlab::Access::MAINTAINER] }
      let(:member_role_ids) { [custom_role.id] }

      context 'when user has the specified access level' do
        let(:user) { maintainer }

        it 'returns true' do
          expect(user_exists).to be true
        end
      end

      context 'when user has the specified custom role' do
        let(:user) { developer }

        it 'returns true' do
          expect(user_exists).to be true
        end
      end

      context 'when user has neither the access level nor the custom role' do
        let(:user) { guest }

        it 'returns false' do
          expect(user_exists).to be false
        end
      end

      context 'when user is not a member of the project' do
        let(:user) { non_member }

        it 'returns false' do
          expect(user_exists).to be false
        end
      end
    end

    context 'when user is nil' do
      let(:levels) { [Gitlab::Access::MAINTAINER] }
      let(:member_role_ids) { [] }
      let(:user) { nil }

      it 'returns false' do
        expect(user_exists).to be false
      end
    end
  end
end

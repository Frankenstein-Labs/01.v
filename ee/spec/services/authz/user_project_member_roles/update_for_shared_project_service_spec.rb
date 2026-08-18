# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserProjectMemberRoles::UpdateForSharedProjectService, feature_category: :permissions do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user) }
  let_it_be(:project) { create(:project) }

  # access_level (developer) should be > project_group_link.group_access (guest)
  # so users are assigned project_group_link.member_role in
  # project_group_link.project instead of member.member_role_id which is nil
  let_it_be(:shared_with_group) do
    create(:group, developers: [user, user2])
  end

  let_it_be(:role) { create(:member_role, :guest) }
  let_it_be_with_reload(:project_group_link) do
    create(:project_group_link, :guest, project: project, group: shared_with_group, member_role: role)
  end

  subject(:execute) do
    described_class.new(project_group_link).execute
    user.reload
    user2.reload
  end

  shared_examples 'logs event data' do |upserted_count:, deleted_count:|
    it 'logs event data' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          shared_project_id: project.id,
          shared_with_group_id: shared_with_group.id,
          'update_user_project_member_roles.event': 'project_group_link created/updated',
          'update_user_project_member_roles.upserted_count': upserted_count,
          'update_user_project_member_roles.deleted_count': deleted_count
        )
      )

      execute
    end
  end

  it 'creates UserProjectMemberRole records for each user in project_group_link.group' do
    expect { execute }.to change {
      [
        user.user_project_member_roles.where(project: project, shared_with_group: shared_with_group,
          member_role: project_group_link.member_role).exists?,
        user2.user_project_member_roles.where(project: project, shared_with_group: shared_with_group,
          member_role: project_group_link.member_role).exists?
      ]
    }.from([false, false]).to([true, true])

    expect(Authz::UserProjectMemberRole.count).to eq(2)
  end

  # Can be removed when https://gitlab.com/groups/gitlab-org/-/epics/19048 is completed
  context 'with duplicate member records' do
    before do
      member = GroupMember.where(user_id: user.id).first
      GroupMember.build(member.attributes.except("id")).save!(validate: false)
    end

    it 'does not attempt to create duplicate records' do
      expect(user.user_project_member_roles.length).to eq 0

      # An ActiveRecord::StatementInvalid "PG::CardinalityViolation ..." error
      # is raised when duplicate member records are not taken into account
      expect { execute }.not_to raise_error

      expect(user.user_project_member_roles.length).to eq 1
    end
  end

  it_behaves_like 'logs event data', upserted_count: 2, deleted_count: 0

  context 'with existing UserProjectMemberRole records' do
    let_it_be(:old_role) { create(:member_role, :guest) }

    before do
      create(:user_project_member_role, user: user, project: project, shared_with_group: shared_with_group,
        member_role: old_role)
      create(:user_project_member_role, user: user2, project: project, shared_with_group: shared_with_group,
        member_role: old_role)
    end

    it 'updates member_role_id of the existing records', :aggregate_failures do
      expect { execute }.to change {
        [
          user.user_project_member_roles.where(project: project,
            shared_with_group: shared_with_group).first.member_role_id,
          user2.user_project_member_roles.where(project: project,
            shared_with_group: shared_with_group).first.member_role_id
        ]
      }.from([old_role.id, old_role.id]).to([role.id, role.id])
    end

    it_behaves_like 'logs event data', upserted_count: 2, deleted_count: 0

    context 'with existing UserProjectMemberRole record shared with another group' do
      let_it_be(:other_group) { create(:group, developers: [user]) }
      let_it_be_with_reload(:other_project_group_link) do
        create(:project_group_link, :guest, project: project, group: other_group, member_role: role)
      end

      let_it_be(:other_record) do
        create(:user_project_member_role, user: user, project: project, shared_with_group: other_group,
          member_role: old_role)
      end

      it 'does not update member_role_id of the other existing record' do
        expect { execute }.not_to change { other_record.reload.member_role_id }
      end

      context 'when member role is removed' do
        before do
          project_group_link.update!(member_role: nil)
        end

        it 'deletes the correct records', :aggregate_failures do
          expect(user.user_project_member_roles.count).to eq 2
          expect(user2.user_project_member_roles.count).to eq 1

          execute

          expect(user.user_project_member_roles.count).to eq 1
          expect(user2.user_project_member_roles).to be_empty

          expect(Authz::UserProjectMemberRole.find(other_record.id)).not_to be_nil
        end

        it_behaves_like 'logs event data', upserted_count: 0, deleted_count: 2
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::DestroyForGroupService, feature_category: :permissions do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be_with_reload(:member) { create(:group_member, :guest, user: user, group: group) }

  subject(:execute) do
    described_class.new(member.user, member.source).execute
    user.reload
  end

  before do
    create(:user_group_member_role, user: user, group: group)
    create(:user_group_member_role, user: user, group: other_group)
  end

  shared_examples 'logs event data' do |deleted_for_group_count: 0, deleted_for_project_count: 0|
    it 'logs event data' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          user_id: user.id,
          group_id: group.id,
          'update_user_group_member_roles.event': 'member deleted',
          'update_user_group_member_roles.upserted_count': 0,
          'update_user_group_member_roles.deleted_count': deleted_for_group_count,
          'update_user_project_member_roles.deleted_count': deleted_for_project_count
        )
      )

      execute
    end
  end

  it 'destroys the UserGroupMemberRole record for the user in the group' do
    expect { execute }.to change {
      [
        user.user_group_member_roles.where(group: group).exists?,
        user.user_group_member_roles.where(group: other_group).exists?
      ]
    }.from([true, true]).to([false, true])
  end

  it_behaves_like 'logs event data', deleted_for_group_count: 1

  context 'when there are groups shared with the group' do
    let_it_be(:shared_group) { create(:group) }
    let_it_be(:shared_group2) { create(:group) }
    let_it_be(:shared_group3) { create(:group) }

    before do
      create(:user_group_member_role, user: user, group: shared_group, shared_with_group: group)
      create(:user_group_member_role, user: user, group: shared_group2, shared_with_group: group)
      create(:user_group_member_role, user: user, group: shared_group3, shared_with_group: other_group)
    end

    it 'destroys UserGroupMemberRole records for the user in the group and in all shared groups to the group' do
      expect { execute }.to change {
        [
          user.user_group_member_roles.where(group: group).exists?,
          user.user_group_member_roles.where(group: shared_group).exists?,
          user.user_group_member_roles.where(group: shared_group2).exists?,
          user.user_group_member_roles.where(group: shared_group3).exists?
        ]
      }.from([true, true, true, true]).to([false, false, false, true])
    end

    it_behaves_like 'logs event data', deleted_for_group_count: 3
  end

  context 'when there are projects shared with the group' do
    let_it_be(:shared_project) { create(:project) }
    let_it_be(:shared_project2) { create(:project) }
    let_it_be(:shared_project3) { create(:project) }

    before do
      create(:user_project_member_role, user: user, project: shared_project, shared_with_group: group)
      create(:user_project_member_role, user: user, project: shared_project2, shared_with_group: group)
      create(:user_project_member_role, user: user, project: shared_project3, shared_with_group: other_group)
    end

    it 'destroys the user\'s UserProjectMemberRole records for all shared projects to the group' do
      expect { execute }.to change {
        [
          user.user_project_member_roles.where(project: shared_project).exists?,
          user.user_project_member_roles.where(project: shared_project2).exists?,
          user.user_project_member_roles.where(project: shared_project3).exists?
        ]
      }.from([true, true, true]).to([false, false, true])
    end

    it_behaves_like 'logs event data', deleted_for_group_count: 1, deleted_for_project_count: 2

    context 'when cache_user_project_member_roles feature flag is disabled' do
      before do
        stub_feature_flags(cache_user_project_member_roles: false)
      end

      it 'does not destroy the user\'s UserProjectMemberRole records' do
        expect { execute }.not_to change { user.user_project_member_roles.count }
      end
    end
  end
end

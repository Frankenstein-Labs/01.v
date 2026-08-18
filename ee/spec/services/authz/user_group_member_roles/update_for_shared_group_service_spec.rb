# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::UpdateForSharedGroupService, feature_category: :permissions do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user) }
  let_it_be(:group) { create(:group) }

  # access_level should be > group_group_link.group_access so users are assigned
  # group_group_link.member_role in group_group_link.shared_group instead of
  # member.member_role_id which is nil
  let_it_be(:shared_with_group) do
    create(:group, developers: [user, user2])
  end

  let_it_be(:role) { create(:member_role, :guest) }
  let_it_be_with_reload(:group_group_link) do
    create(:group_group_link, :guest, shared_group: group, shared_with_group: shared_with_group, member_role: role,
      create_user_group_member_roles: false)
  end

  subject(:execute) do
    described_class.new(group_group_link).execute
    user.reload
    user2.reload
  end

  shared_examples 'logs event data' do |upserted_count:, deleted_count:|
    it 'logs event data' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          shared_group_id: group.id,
          shared_with_group_id: shared_with_group.id,
          'update_user_group_member_roles.event': 'group_group_link created/updated',
          'update_user_group_member_roles.upserted_count': upserted_count,
          'update_user_group_member_roles.deleted_count': deleted_count
        )
      )

      execute
    end
  end

  it 'creates UserGroupMemberRole records for each user in group_group_link.shared_with_group' do
    expect { execute }.to change {
      [
        user.user_group_member_roles.where(group: group, shared_with_group: shared_with_group,
          member_role: group_group_link.member_role).exists?,
        user2.user_group_member_roles.where(group: group, shared_with_group: shared_with_group,
          member_role: group_group_link.member_role).exists?
      ]
    }.from([false, false]).to([true, true])

    expect(Authz::UserGroupMemberRole.count).to eq(2)
  end

  # Can be removed when https://gitlab.com/groups/gitlab-org/-/epics/19048 is completed
  context 'with duplicate member records' do
    before do
      member = GroupMember.where(user_id: user.id).first
      GroupMember.build(member.attributes.except("id")).save!(validate: false)
    end

    it 'does not raise an ActiveRecord::StatementInvalid "PG::CardinalityViolation ..." error' do
      expect(user.user_group_member_roles.length).to eq 0
      expect { execute }.not_to raise_error
      expect(user.user_group_member_roles.length).to eq 1
    end
  end

  context 'with minimal access role', :saas do
    let_it_be(:shared_with_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:minimal_access_role) { create(:member_role, :minimal_access) }
    let_it_be(:member) do
      create(:group_member, :minimal_access, member_role: minimal_access_role, user: user, group: shared_with_group,
        create_user_group_member_roles: false)
    end

    let_it_be_with_reload(:group_group_link) do
      create(:group_group_link, :guest, shared_group: group, shared_with_group: shared_with_group, member_role: role,
        create_user_group_member_roles: false)
    end

    it 'creates UserGroupMemberRole records for each user in group_group_link.shared_with_group' do
      expect { execute }.to change {
        user.user_group_member_roles.where(group: group, shared_with_group: shared_with_group,
          member_role: minimal_access_role).exists?
      }.from(false).to(true)

      expect(Authz::UserGroupMemberRole.count).to eq(1)
    end
  end

  it_behaves_like 'logs event data', upserted_count: 2, deleted_count: 0

  context 'with existing UserGroupMemberRole records' do
    let_it_be(:old_role) { create(:member_role, :guest) }
    # user_group_member_role for user in group_group_link.shared_group through direct
    # membership. Service is expected not to update/delete this record.
    let_it_be(:in_group) do
      create(:user_group_member_role, user: user, group: group, shared_with_group: nil, member_role: old_role)
    end

    before do
      create(:user_group_member_role, user: user, group: group, shared_with_group: shared_with_group,
        member_role: old_role)
      create(:user_group_member_role, user: user2, group: group, shared_with_group: shared_with_group,
        member_role: old_role)
    end

    it 'updates member_role_id of the correct records' do
      expect { execute }.to change {
        [
          user.user_group_member_roles.where(group: group, shared_with_group: shared_with_group).first.member_role_id,
          user2.user_group_member_roles.where(group: group, shared_with_group: shared_with_group).first.member_role_id
        ]
      }.from([old_role.id, old_role.id]).to([role.id, role.id])

      expect(user.user_group_member_roles.find_by(group: group,
        shared_with_group: nil).member_role_id).to eq old_role.id
      expect(Authz::UserGroupMemberRole.count).to eq(3)
    end

    it_behaves_like 'logs event data', upserted_count: 2, deleted_count: 0

    context 'when member role is removed' do
      before do
        group_group_link.update!(member_role: nil)
      end

      it 'deletes the correct records' do
        expect(user.user_group_member_roles.count).to eq 2
        expect(user2.user_group_member_roles.count).to eq 1

        execute

        expect(user.user_group_member_roles.count).to eq 1
        expect(user2.user_group_member_roles).to be_empty

        expect(Authz::UserGroupMemberRole.find(in_group.id)).not_to be_nil
      end

      it_behaves_like 'logs event data', upserted_count: 0, deleted_count: 2
    end
  end
end

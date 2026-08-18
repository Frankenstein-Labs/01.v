# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::UpdateForGroupService, feature_category: :permissions do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group) }

  # Set access_level to GUEST (< group_group_link.group_access i.e. DEVELOPER)
  # so we can assert created/updated user_group_member_role.member_role == member.role
  let_it_be_with_reload(:member) do
    create(:group_member, :guest, member_role: role, user: user, group: group, create_user_group_member_roles: false)
  end

  subject(:execute) do
    described_class.new(member).execute
    user.reload
  end

  before do
    stub_licensed_features(custom_roles: true)
  end

  def create_record(user, group, member_role, shared_with_group: nil)
    attrs = { user: user, group: group, member_role: member_role, shared_with_group: shared_with_group }.compact
    create(:user_group_member_role, attrs)
  end

  def create_group_group_link(group, shared_with_group)
    # Set group_access to DEVELOPER (> member.access_level i.e. GUEST) so we can
    # assert created/updated user_group_member_role.member_role == member.role
    create(:group_group_link, :developer, shared_group: group, shared_with_group: shared_with_group,
      create_user_group_member_roles: false)
  end

  def fetch_records(user, group, member_role)
    user.user_group_member_roles.where(group: group, member_role: member_role)
  end

  shared_examples 'logs event data' do
    |upserted_for_group_count: 0, deleted_for_group_count: 0, upserted_for_project_count: 0,
     deleted_for_project_count: 0|
    it 'logs event data' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          user_id: user.id,
          group_id: group.id,
          'update_user_group_member_roles.event': 'member created/updated',
          'update_user_group_member_roles.upserted_count': upserted_for_group_count,
          'update_user_group_member_roles.deleted_count': deleted_for_group_count,
          'update_user_project_member_roles.upserted_count': upserted_for_project_count,
          'update_user_project_member_roles.deleted_count': deleted_for_project_count
        )
      )

      execute
    end
  end

  it 'creates a UserGroupMemberRole record for the user in the group' do
    expect { execute }.to change {
      fetch_records(user, group, member.member_role).exists?
    }.from(false).to(true)
  end

  it_behaves_like 'logs event data', upserted_for_group_count: 1

  context 'with an existing UserGroupMemberRole record' do
    let_it_be(:old_role) { create(:member_role, :guest, namespace: group) }

    before do
      create_record(user, group, old_role)
    end

    it 'updates member_role_id of the existing record' do
      expect { execute }.to change {
        Authz::UserGroupMemberRole.for_user_in_group(user, group).member_role_id
      }.from(old_role.id).to(role.id)

      expect(user.user_group_member_roles.count).to eq(1)
    end

    context 'when member role is removed' do
      before do
        member.update!(member_role: nil)
      end

      it 'deletes the existing record' do
        expect { execute }.to change { user.user_group_member_roles.count }.from(1).to(0)
      end

      it_behaves_like 'logs event data', deleted_for_group_count: 1
    end
  end

  context 'when there are groups shared to the group' do
    let_it_be(:shared_group) { create(:group) }

    before do
      create_group_group_link(shared_group, group)
    end

    it 'creates UserGroupMemberRole records for the user in the group and in the shared group' do
      expect { execute }.to change {
        [
          fetch_records(user, group, role).exists?,
          fetch_records(user, shared_group, role).exists?
        ]
      }.from([false, false]).to([true, true])
    end

    context 'with minimal access role', :saas do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:role) { create(:member_role, :minimal_access, namespace: group) }
      let_it_be(:member) do
        create(:group_member, :minimal_access, member_role: role, user: user, group: group,
          create_user_group_member_roles: false)
      end

      it 'creates UserGroupMemberRole records for the user in the group and in the shared group' do
        expect { execute }.to change {
          [
            fetch_records(user, group, role).exists?,
            fetch_records(user, shared_group, role).exists?
          ]
        }.from([false, false]).to([true, true])
      end
    end

    it_behaves_like 'logs event data', upserted_for_group_count: 2

    context 'with existing UserGroupMemberRole records' do
      let_it_be(:old_role) { create(:member_role, :guest, namespace: group) }
      let_it_be(:shared_group_role) { create(:member_role, :guest, namespace: shared_group) }

      before do
        create_record(user, group, old_role)
        create_record(user, shared_group, old_role, shared_with_group: group)
      end

      it 'updates member_role_id of the existing records' do
        expect { execute }.to change {
          [
            Authz::UserGroupMemberRole.for_user_in_group(user, group).member_role_id,
            Authz::UserGroupMemberRole
              .where(user: user, group: shared_group).where.not(shared_with_group: nil).first
              .member_role_id
          ]
        }.from([old_role.id, old_role.id]).to([role.id, role.id])

        expect(user.user_group_member_roles.count).to eq(2)
      end

      context 'when member role is removed' do
        before do
          member.update!(member_role: nil)
        end

        it 'deletes the existing records' do
          expect { execute }.to change { user.user_group_member_roles.count }.from(2).to(0)
        end

        it_behaves_like 'logs event data', deleted_for_group_count: 2
      end
    end
  end

  context 'when there are projects shared to the group' do
    let_it_be(:shared_project) { create(:project) }

    before do
      # Set group_access to DEVELOPER (> member.access_level i.e. GUEST) so we can
      # assert created/updated user_group_member_role.member_role == member.role
      create(:project_group_link, :developer, project: shared_project, group: group)
    end

    it 'creates UserProjectMemberRole records for the user in the shared project' do
      expect { execute }.to change {
        user.user_project_member_roles.where(project: shared_project, shared_with_group: group,
          member_role: role).exists?
      }.from(false).to(true)
    end

    it_behaves_like 'logs event data', upserted_for_group_count: 1, upserted_for_project_count: 1

    context 'when cache_user_project_member_roles feature flag is disabled' do
      before do
        stub_feature_flags(cache_user_project_member_roles: false)
      end

      it 'does not create UserProjectMemberRole records for the user' do
        expect { execute }.not_to change { user.user_project_member_roles.count }.from(0)
      end
    end

    context 'with existing UserGroupMemberRole records' do
      let_it_be(:old_role) { create(:member_role, :guest, namespace: group) }

      before do
        attrs = { user: user, project: shared_project, shared_with_group: group, member_role: old_role }
        create(:user_project_member_role, attrs)
      end

      it 'updates member_role_id of the existing records' do
        expect { execute }.to change {
          Authz::UserProjectMemberRole
            .where(user: user, project: shared_project, shared_with_group: group).first
            .member_role_id
        }.from(old_role.id).to(role.id)

        expect(user.user_project_member_roles.count).to eq(1)
      end

      context 'when cache_user_project_member_roles feature flag is disabled' do
        before do
          stub_feature_flags(cache_user_project_member_roles: false)
        end

        it 'does not update the existing records' do
          expect { execute }.not_to change {
            Authz::UserProjectMemberRole
              .where(user: user, project: shared_project, shared_with_group: group).first
              .member_role_id
          }.from(old_role.id)
        end
      end

      context 'when member role is removed' do
        before do
          member.update!(member_role: nil)
        end

        it 'deletes the existing records' do
          expect { execute }.to change { user.user_project_member_roles.count }.from(1).to(0)
        end

        it_behaves_like 'logs event data', deleted_for_project_count: 1

        context 'when cache_user_project_member_roles feature flag is disabled' do
          before do
            stub_feature_flags(cache_user_project_member_roles: false)
          end

          it 'does not delete the existing records' do
            expect { execute }.not_to change { user.user_project_member_roles.count }
          end
        end
      end
    end
  end

  context 'when membership is pending' do
    before do
      create_group_group_link(create(:group), group)

      member.update!(requested_at: Time.zone.now)
    end

    it 'does not create any UserGroupMemberRole record for the user' do
      expect { execute }.not_to change {
        user.user_group_member_roles.count
      }.from(0)
    end
  end

  context 'when membership is inactive' do
    before do
      create_group_group_link(create(:group), group)

      member.update!(state: Member::STATE_AWAITING)
    end

    it 'does not create any UserGroupMemberRole record for the user' do
      expect { execute }.not_to change {
        user.user_group_member_roles.count
      }.from(0)
    end
  end
end

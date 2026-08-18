# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillUserGroupMemberRoles, :sidekiq_inline, feature_category: :permissions do
  let!(:migration_args) do
    {
      start_id: 1,
      end_id: 1000,
      batch_table: :members,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let!(:users) { table(:users) }
  let(:organizations) { table(:organizations) }
  let!(:namespaces) { table(:namespaces) }
  let!(:projects) { table(:projects) }
  let!(:members) { table(:members) }
  let!(:member_roles) { table(:member_roles) }
  let!(:user_group_member_roles) { table(:user_group_member_roles) }

  let!(:user_1) do
    users.create!(
      name: 'user1',
      email: 'user1@example.com',
      projects_limit: 5,
      organization_id: organization.id
    )
  end

  let!(:user_2) do
    users.create!(
      name: 'user2',
      email: 'user2@example.com',
      projects_limit: 5,
      organization_id: organization.id
    )
  end

  let!(:user_3) do
    users.create!(
      name: 'user3',
      email: 'user3@example.com',
      projects_limit: 5,
      organization_id: organization.id
    )
  end

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }

  let!(:group) do
    namespaces.create!(
      name: 'group 1',
      path: 'group-path-1',
      type: 'Group',
      organization_id: organization.id
    )
  end

  let!(:project) do
    projects.create!(
      name: 'project 1',
      path: 'project-path-1',
      namespace_id: group.id,
      project_namespace_id: group.id,
      organization_id: organization.id
    )
  end

  let!(:member_role) do
    member_roles.create!(name: 'Custom role', base_access_level: Gitlab::Access::GUEST,
      organization_id: organization.id)
  end

  let!(:group_member) do
    members.create!(
      user_id: user_1.id,
      source_id: group.id,
      member_namespace_id: group.id,
      access_level: Gitlab::Access::MAINTAINER,
      type: 'GroupMember',
      source_type: 'Namespace',
      notification_level: 3
    )
  end

  let!(:group_member_with_member_role) do
    members.create!(
      user_id: user_2.id,
      source_id: group.id,
      member_namespace_id: group.id,
      access_level: Gitlab::Access::GUEST,
      type: 'GroupMember',
      source_type: 'Namespace',
      member_role_id: member_role.id,
      notification_level: 3
    )
  end

  let!(:invited_group_member) do
    members.create!(
      user_id: nil,
      source_id: group.id,
      member_namespace_id: group.id,
      access_level: Gitlab::Access::GUEST,
      type: 'GroupMember',
      source_type: 'Namespace',
      notification_level: 3,
      member_role_id: member_role.id,
      invite_token: '1234'
    )
  end

  let!(:duplicate_group_member_with_member_role) do
    members.build(
      user_id: user_2.id,
      source_id: group.id,
      member_namespace_id: group.id,
      access_level: Gitlab::Access::GUEST,
      type: 'GroupMember',
      source_type: 'Namespace',
      notification_level: 3,
      member_role_id: member_role.id
    ).tap { |r| r.save!(validate: false) }
  end

  let!(:project_member) do
    members.create!(
      user_id: user_3.id,
      source_id: project.id,
      member_namespace_id: project.project_namespace_id,
      access_level: Gitlab::Access::MAINTAINER,
      type: 'ProjectMember',
      source_type: 'Project',
      notification_level: 3
    )
  end

  subject(:migration) { described_class.new(**migration_args) }

  describe '#perform' do
    it 'does not raise an error' do
      expect { migration.perform }.not_to raise_error
    end

    it 'creates a UserGroupMemberRole record for a user in a group' do
      expect { migration.perform }.to change { user_group_member_roles.count }.by(1)

      expect(fetch_record(group_member, group)).to be_nil

      expect(fetch_record(group_member_with_member_role, group)).to have_attributes(
        user_id: user_2.id,
        group_id: group.id,
        member_role_id: member_role.id,
        shared_with_group_id: nil
      )

      expect(fetch_record(project_member, group)).to be_nil
    end

    context 'when a group invites another group' do
      let!(:group_group_links) { table(:group_group_links) }

      let!(:invited_group) do
        namespaces.create!(
          name: 'shared group 1',
          path: 'shared-group-path-1',
          type: 'Group',
          organization_id: organization.id
        )
      end

      let!(:group_link) do
        group_group_links.create!(
          shared_group_id: group.id,
          shared_with_group_id: invited_group.id,
          group_access: Gitlab::Access::DEVELOPER
        )
      end

      let!(:user_4) do
        users.create!(
          name: 'user4',
          email: 'user4@example.com',
          projects_limit: 5,
          organization_id: organization.id
        )
      end

      let!(:group_member_in_invited_group) do
        members.create!(
          user_id: user_4.id,
          source_id: invited_group.id,
          member_namespace_id: invited_group.id,
          access_level: Gitlab::Access::GUEST,
          member_role_id: member_role.id,
          type: 'GroupMember',
          source_type: 'Namespace',
          notification_level: 3
        )
      end

      it 'creates UserGroupMemberRole records for the user in the group' do
        expect { migration.perform }.to change { user_group_member_roles.count }.by(2)

        expect(fetch_record(group_member_with_member_role, group)).to have_attributes(
          user_id: user_2.id,
          group_id: group.id,
          member_role_id: member_role.id,
          shared_with_group_id: nil
        )

        expect(fetch_record(group_member_in_invited_group, invited_group)).to have_attributes(
          user_id: user_4.id,
          group_id: invited_group.id,
          member_role_id: member_role.id,
          shared_with_group_id: nil
        )

        # This BBM only backfills records for direct membership
        # A follow-up BBM will backfill records for group-sharing
        # https://gitlab.com/gitlab-org/gitlab/-/work_items/520189
        expect(fetch_record(group_member_in_invited_group, group)).to be_nil
      end
    end

    context 'with an existing UserGroupMemberRole record' do
      let!(:member_role_2) do
        member_roles.create!(name: 'Custom role 2', base_access_level: Gitlab::Access::GUEST,
          organization_id: organization.id)
      end

      before do
        user_group_member_roles.create!(
          user_id: user_2.id,
          group_id: group.id,
          member_role_id: member_role_2.id,
          shared_with_group_id: nil
        )
      end

      it 'updates existing UserGroupMemberRole record' do
        expect { migration.perform }.not_to change { user_group_member_roles.count }

        expect(fetch_record(group_member_with_member_role, group)).to have_attributes(
          user_id: user_2.id,
          group_id: group.id,
          member_role_id: member_role.id,
          shared_with_group_id: nil
        )
      end
    end

    context 'when the member is not active' do
      before do
        group_member_with_member_role.update!(state: 1)
        duplicate_group_member_with_member_role.update!(state: 1)
      end

      it 'does not create a UserGroupMemberRole record' do
        expect { migration.perform }.not_to change { user_group_member_roles.count }
      end
    end
  end

  def fetch_record(member, group)
    user_group_member_roles.find_by(user_id: member.user_id, group_id: group.id)
  end
end

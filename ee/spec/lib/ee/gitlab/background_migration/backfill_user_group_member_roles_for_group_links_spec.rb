# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillUserGroupMemberRolesForGroupLinks, feature_category: :permissions do
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

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }

  let!(:group) do
    namespaces.create!(
      name: 'group 1',
      path: 'group-path-1',
      type: 'Group',
      organization_id: organization.id
    )
  end

  let!(:member_role_1) do
    member_roles.create!(name: 'Custom role', base_access_level: Gitlab::Access::GUEST,
      organization_id: organization.id)
  end

  let!(:member_role_2) do
    member_roles.create!(name: 'Custom role 2', base_access_level: Gitlab::Access::GUEST,
      organization_id: organization.id)
  end

  subject(:migration) { described_class.new(**migration_args) }

  describe '#perform' do
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

      let!(:group_member_in_invited_group) do
        members.create!(
          user_id: user_1.id,
          source_id: invited_group.id,
          member_namespace_id: invited_group.id,
          access_level: Gitlab::Access::GUEST,
          type: 'GroupMember',
          source_type: 'Namespace',
          notification_level: 3
        )
      end

      let!(:group_member_in_invited_group_with_nil_user_id) do
        members.create!(
          user_id: nil,
          source_id: invited_group.id,
          member_namespace_id: invited_group.id,
          access_level: Gitlab::Access::GUEST,
          type: 'GroupMember',
          source_type: 'Namespace',
          notification_level: 3,
          invite_token: '1234'
        )
      end

      let!(:duplicate_group_member_in_invited_group) do
        members.build(
          user_id: user_1.id,
          source_id: invited_group.id,
          member_namespace_id: invited_group.id,
          access_level: Gitlab::Access::GUEST,
          type: 'GroupMember',
          source_type: 'Namespace',
          notification_level: 3
        ).tap { |r| r.save!(validate: false) }
      end

      context 'when the group is invited without a member role' do
        context 'when the user in the invited group has a member role' do
          before do
            group_member_in_invited_group.update!(member_role_id: member_role_1.id)
          end

          it 'does not raise an error' do
            expect { migration.perform }.not_to raise_error
          end

          it 'creates UserGroupMemberRole records for the user in the group' do
            expect { migration.perform }.to change { user_group_member_roles.count }.by(1)

            expect(fetch_record(group_member_in_invited_group, group, invited_group)).to have_attributes(
              user_id: user_1.id,
              group_id: group.id,
              member_role_id: member_role_1.id,
              shared_with_group_id: invited_group.id
            )
          end

          context 'when user is already a direct member of the inviter group' do
            before do
              user_group_member_roles.create!(
                user_id: user_1.id,
                group_id: group.id,
                member_role_id: member_role_2.id,
                shared_with_group_id: nil
              )
            end

            it 'creates a UserGroupMemberRole record for the user in the group' do
              expect { migration.perform }.to change { user_group_member_roles.count }.by(1)

              expect(fetch_record(group_member_in_invited_group, group, invited_group)).to have_attributes(
                user_id: user_1.id,
                group_id: group.id,
                member_role_id: member_role_1.id,
                shared_with_group_id: invited_group.id
              )
            end
          end
        end

        context 'when the user in the invited group does not have a member role' do
          before do
            group_member_in_invited_group.update!(member_role_id: nil)
          end

          it 'does not create a UserGroupMemberRole record' do
            expect { migration.perform }.not_to change { user_group_member_roles.count }

            expect(fetch_record(group_member_in_invited_group, group, invited_group)).to be_nil
          end
        end
      end

      context 'when the group is invited with a member role' do
        before do
          group_link.update!(member_role_id: member_role_2.id)
        end

        context 'when the user in the invited group has a member role' do
          before do
            group_member_in_invited_group.update!(member_role_id: member_role_1.id)
          end

          it 'creates a UserGroupMemberRole record for the user in the group' do
            expect { migration.perform }.to change { user_group_member_roles.count }.by(1)

            expect(fetch_record(group_member_in_invited_group, group, invited_group)).to have_attributes(
              user_id: user_1.id,
              group_id: group.id,
              member_role_id: member_role_1.id,
              shared_with_group_id: invited_group.id
            )
          end
        end

        # learn more about computed member roles when groups are invited
        # https://docs.gitlab.com/user/custom_roles/#assign-a-custom-role-to-an-invited-group
        context 'when the user in the invited group has a computed member role' do
          before do
            group_member_in_invited_group.update!(
              member_role_id: nil,
              access_level: Gitlab::Access::MAINTAINER
            )
          end

          it 'creates a UserGroupMemberRole record for the user in the group' do
            expect { migration.perform }.to change { user_group_member_roles.count }.by(1)

            expect(fetch_record(group_member_in_invited_group, group, invited_group)).to have_attributes(
              user_id: user_1.id,
              group_id: group.id,
              member_role_id: member_role_2.id,
              shared_with_group_id: invited_group.id
            )
          end
        end

        context 'when the user in the invited group does not have a computed member role' do
          before do
            group_member_in_invited_group.update!(
              member_role_id: nil,
              access_level: Gitlab::Access::GUEST
            )
          end

          it 'does not create a UserGroupMemberRole record' do
            expect { migration.perform }.not_to change { user_group_member_roles.count }
          end
        end
      end
    end
  end

  def fetch_record(member, group, invited_group)
    user_group_member_roles.find_by(
      user_id: member.user_id,
      group_id: group.id,
      shared_with_group_id: invited_group.id
    )
  end
end

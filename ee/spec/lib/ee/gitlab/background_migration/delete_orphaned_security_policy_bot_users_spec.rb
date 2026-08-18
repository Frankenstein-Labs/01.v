# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::DeleteOrphanedSecurityPolicyBotUsers, feature_category: :security_policy_management do
  let(:users_table) { table(:users) }
  let(:members_table) { table(:members) }
  let(:ghost_user_migrations_table) { table(:ghost_user_migrations) }
  let(:namespaces_table) { table(:namespaces) }
  let(:projects_table) { table(:projects) }

  subject(:perform_migration) do
    described_class.new(
      start_id: users_table.minimum(:id),
      end_id: users_table.maximum(:id),
      batch_table: :users,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    ).perform
  end

  describe '#perform' do
    let!(:organization) { table(:organizations).create!(name: 'Default', path: 'default') }
    let!(:namespace) { namespaces_table.create!(name: 'test', path: 'test', organization_id: organization.id) }
    let!(:project) do
      projects_table.create!(name: 'test', path: 'test', namespace_id: namespace.id, project_namespace_id: namespace.id,
        organization_id: organization.id)
    end

    context 'when there are orphaned security policy bot users' do
      let!(:orphaned_security_policy_bot) do
        users_table.create!(
          username: 'security-policy-bot-1',
          email: 'security-policy-bot-1@example.com',
          name: 'Security Policy Bot 1',
          user_type: 10, # security_policy_bot
          projects_limit: 0,
          organization_id: organization.id
        )
      end

      let!(:orphaned_security_policy_bot_2) do
        users_table.create!(
          username: 'security-policy-bot-2',
          email: 'security-policy-bot-2@example.com',
          name: 'Security Policy Bot 2',
          user_type: 10, # security_policy_bot
          projects_limit: 0,
          organization_id: organization.id
        )
      end

      it 'deletes orphaned security policy bot users' do
        expect { perform_migration }.to change { users_table.count }.by(-2)

        expect(users_table.find_by(id: orphaned_security_policy_bot.id)).to be_nil
        expect(users_table.find_by(id: orphaned_security_policy_bot_2.id)).to be_nil
      end
    end

    context 'when security policy bot users have project memberships' do
      let!(:security_policy_bot_with_membership) do
        users_table.create!(
          username: 'security-policy-bot-with-membership',
          email: 'security-policy-bot-with-membership@example.com',
          name: 'Security Policy Bot With Membership',
          user_type: 10, # security_policy_bot
          projects_limit: 0,
          organization_id: organization.id
        )
      end

      let!(:project_member) do
        members_table.create!(
          user_id: security_policy_bot_with_membership.id,
          source_id: project.id,
          source_type: 'Project',
          type: 'ProjectMember',
          access_level: 30, # Developer
          notification_level: 3,
          member_namespace_id: namespace.id
        )
      end

      it 'does not delete security policy bot users with project memberships' do
        expect { perform_migration }.not_to change { users_table.count }

        expect(users_table.find_by(id: security_policy_bot_with_membership.id)).to be_present
      end
    end

    context 'when security policy bot users have ghost user migrations' do
      let!(:security_policy_bot_with_ghost_migration) do
        users_table.create!(
          username: 'security-policy-bot-with-ghost',
          email: 'security-policy-bot-with-ghost@example.com',
          name: 'Security Policy Bot With Ghost Migration',
          user_type: 10, # security_policy_bot
          projects_limit: 0,
          organization_id: organization.id
        )
      end

      let!(:ghost_user_migration) do
        ghost_user_migrations_table.create!(
          user_id: security_policy_bot_with_ghost_migration.id,
          initiator_user_id: security_policy_bot_with_ghost_migration.id,
          hard_delete: false
        )
      end

      it 'does not delete security policy bot users with ghost user migrations' do
        expect { perform_migration }.not_to change { users_table.count }

        expect(users_table.find_by(id: security_policy_bot_with_ghost_migration.id)).to be_present
      end
    end

    context 'when there are non-security-policy-bot users' do
      let!(:regular_user) do
        users_table.create!(
          username: 'regular-user',
          email: 'regular-user@example.com',
          name: 'Regular User',
          user_type: 0, # human
          projects_limit: 10,
          organization_id: organization.id
        )
      end

      let!(:project_bot) do
        users_table.create!(
          username: 'project-bot',
          email: 'project-bot@example.com',
          name: 'Project Bot',
          user_type: 6, # project_bot
          projects_limit: 0,
          organization_id: organization.id
        )
      end

      it 'does not delete non-security-policy-bot users' do
        expect { perform_migration }.not_to change { users_table.count }

        expect(users_table.find_by(id: regular_user.id)).to be_present
        expect(users_table.find_by(id: project_bot.id)).to be_present
      end
    end

    context 'when there are mixed scenarios' do
      let!(:orphaned_security_policy_bot) do
        users_table.create!(
          username: 'orphaned-security-policy-bot',
          email: 'orphaned-security-policy-bot@example.com',
          name: 'Orphaned Security Policy Bot',
          user_type: 10, # security_policy_bot
          projects_limit: 0,
          organization_id: organization.id
        )
      end

      let!(:security_policy_bot_with_membership) do
        users_table.create!(
          username: 'security-policy-bot-with-membership',
          email: 'security-policy-bot-with-membership@example.com',
          name: 'Security Policy Bot With Membership',
          user_type: 10, # security_policy_bot
          projects_limit: 0,
          organization_id: organization.id
        )
      end

      let!(:project_member) do
        members_table.create!(
          user_id: security_policy_bot_with_membership.id,
          source_id: project.id,
          source_type: 'Project',
          type: 'ProjectMember',
          access_level: 30, # Developer
          notification_level: 3,
          member_namespace_id: namespace.id
        )
      end

      let!(:regular_user) do
        users_table.create!(
          username: 'regular-user',
          email: 'regular-user@example.com',
          name: 'Regular User',
          user_type: 0, # human
          projects_limit: 10,
          organization_id: organization.id
        )
      end

      it 'only deletes orphaned security policy bot users' do
        expect { perform_migration }.to change { users_table.count }.by(-1)

        expect(users_table.find_by(id: orphaned_security_policy_bot.id)).to be_nil
        expect(users_table.find_by(id: security_policy_bot_with_membership.id)).to be_present
        expect(users_table.find_by(id: regular_user.id)).to be_present
      end
    end
  end
end

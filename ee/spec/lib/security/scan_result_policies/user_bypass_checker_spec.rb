# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UserBypassChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:normal_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:custom_role) { create(:member_role, namespace: project.namespace) }

  let(:security_policy) do
    create(:security_policy, linked_projects: [project], content: { bypass_settings: {} })
  end

  let(:checker) do
    described_class.new(
      bypass_settings: security_policy.bypass_settings,
      project: project,
      current_user: normal_user
    )
  end

  describe '#bypass_scope' do
    subject(:bypass_scope) { checker.bypass_scope }

    context 'when user is nil' do
      let(:normal_user) { nil }

      it 'returns nil' do
        expect(bypass_scope).to be_nil
      end
    end

    context 'when no bypass methods return true' do
      it 'returns nil' do
        expect(bypass_scope).to be_nil
      end
    end

    context 'when users_can_bypass? returns true' do
      before do
        security_policy.update!(content: { bypass_settings: { users: [{ id: normal_user.id }] } })
      end

      it 'returns :user' do
        expect(bypass_scope).to eq(:user)
      end
    end

    context 'when roles_can_bypass? returns true' do
      before do
        create(:project_member, :maintainer, project: project, user: normal_user)
        security_policy.update!(content: { bypass_settings: { roles: ['maintainer'] } })
      end

      it 'returns :role' do
        expect(bypass_scope).to eq(:role)
      end
    end

    context 'when groups_can_bypass? returns true' do
      before do
        group.add_member(normal_user, Gitlab::Access::DEVELOPER)
        security_policy.update!(content: { bypass_settings: { groups: [{ id: group.id }] } })
      end

      it 'returns :group' do
        expect(bypass_scope).to eq(:group)
      end
    end

    context 'when multiple bypass methods return true' do
      before do
        security_policy.update!(content: {
          bypass_settings: {
            users: [{ id: normal_user.id }],
            groups: [{ id: group.id }]
          }
        })
        group.add_member(normal_user, Gitlab::Access::DEVELOPER)
      end

      it 'prioritizes user bypass' do
        expect(bypass_scope).to eq(:user)
      end
    end
  end

  describe '#users_can_bypass?' do
    subject(:users_can_bypass?) { checker.send(:users_can_bypass?) }

    context 'when user is a project bot' do
      let(:normal_user) { create(:user, :project_bot) }

      before do
        security_policy.update!(content: { bypass_settings: { users: [{ id: normal_user.id }] } })
      end

      it 'returns false' do
        expect(users_can_bypass?).to be false
      end
    end

    context 'when user is a service account' do
      let(:normal_user) { create(:service_account) }

      before do
        security_policy.update!(content: { bypass_settings: { users: [{ id: normal_user.id }] } })
      end

      it { is_expected.to be false }
    end

    context 'when user_ids is blank' do
      it { is_expected.to be false }
    end

    context 'when user is not in the allowed users list' do
      before do
        security_policy.update!(content: { bypass_settings: { users: [{ id: create(:user).id }] } })
      end

      it { is_expected.to be false }
    end

    context 'when user is in the allowed users list' do
      before do
        security_policy.update!(content: { bypass_settings: { users: [{ id: normal_user.id }] } })
      end

      it { is_expected.to be true }
    end
  end

  describe '#groups_can_bypass?' do
    subject(:groups_can_bypass?) { checker.send(:groups_can_bypass?) }

    context 'when group_ids is blank' do
      it { is_expected.to be false }
    end

    context 'when user is not a member of the allowed group' do
      before do
        security_policy.update!(content: { bypass_settings: { groups: [{ id: group.id }] } })
      end

      it { is_expected.to be false }
    end

    context 'when user is a member of the allowed group' do
      before do
        group.add_member(normal_user, Gitlab::Access::DEVELOPER)
        security_policy.update!(content: { bypass_settings: { groups: [{ id: group.id }] } })
      end

      it { is_expected.to be true }
    end
  end

  describe '#roles_can_bypass?' do
    subject(:roles_can_bypass?) { checker.send(:roles_can_bypass?) }

    context 'when both default_roles and custom_role_ids are blank' do
      it { is_expected.to be false }
    end

    context 'when default_roles is provided' do
      before do
        security_policy.update!(content: { bypass_settings: { roles: ['maintainer'] } })
      end

      context 'when user has the required role' do
        before do
          create(:project_member, :maintainer, project: project, user: normal_user)
        end

        it { is_expected.to be true }
      end

      context 'when user does not have the required role' do
        it { is_expected.to be false }
      end
    end

    context 'when owner role is provided' do
      before do
        security_policy.update!(content: { bypass_settings: { roles: ['owner'] } })
      end

      context 'when user has the owner role' do
        before do
          create(:project_member, :owner, project: project, user: normal_user)
        end

        it { is_expected.to be true }
      end

      context 'when user does not have the owner role' do
        it { is_expected.to be false }
      end
    end

    context 'when custom_role_ids is provided' do
      before do
        security_policy.update!(content: { bypass_settings: { custom_roles: [{ id: custom_role.id }] } })
      end

      context 'when user has the required custom role' do
        before do
          create(:project_member, :developer, project: project, user: normal_user)
          member = project.members.find_by(user: normal_user)
          member.update!(member_role: custom_role)
        end

        it 'returns true' do
          expect(roles_can_bypass?).to be true
        end
      end

      context 'when user does not have the required custom role' do
        before do
          create(:project_member, :developer, project: project, user: normal_user)
        end

        it { is_expected.to be false }
      end
    end

    context 'when both default_roles and custom_role_ids are provided' do
      before do
        create(:project_member, :maintainer, project: project, user: normal_user)
        member = project.members.find_by(user: normal_user)
        member.update!(member_role: custom_role)
        security_policy.update!(content: {
          bypass_settings: {
            roles: ['maintainer'],
            custom_roles: [{ id: custom_role.id }]
          }
        })
      end

      it { is_expected.to be true }
    end
  end
end

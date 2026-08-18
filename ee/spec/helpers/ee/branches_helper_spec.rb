# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchesHelper, feature_category: :source_code_management do
  describe '#access_levels_data' do
    subject(:access_levels_data) { helper.access_levels_data(access_levels) }

    context 'when access_levels is nil' do
      let(:access_levels) { nil }

      it { is_expected.to be_empty }
    end

    context 'when access levels are provided' do
      let(:group) { create(:group) }
      let!(:project) { create(:project) }
      let!(:protected_branch) { create(:protected_branch, :developers_can_merge, :maintainers_can_push, project: project) }
      let!(:user) { create(:user, maintainer_of: project) }
      let!(:deploy_key) { create(:deploy_key, write_access_to: project, user: user) }

      let(:merge_level) { protected_branch.merge_access_levels.first }
      let(:push_level) { protected_branch.push_access_levels.first }
      let(:deploy_key_push_level) { create(:protected_branch_push_access_level, protected_branch: protected_branch, deploy_key: deploy_key) }
      let(:user_push_level) { create(:protected_branch_push_access_level, protected_branch: protected_branch, user: user) }
      let(:group_push_level) { create(:protected_branch_push_access_level, protected_branch: protected_branch, group: group) }
      let(:access_levels) { [merge_level, push_level, deploy_key_push_level, user_push_level, group_push_level] }

      before do
        create(:project_group_link, group: group, project: project)
      end

      it 'returns the correct array' do
        expected_array = [
          { id: merge_level.id, type: :role, access_level: Gitlab::Access::DEVELOPER },
          { id: push_level.id, type: :role, access_level: Gitlab::Access::MAINTAINER },
          { id: deploy_key_push_level.id, type: :deploy_key, deploy_key_id: deploy_key.id },
          { id: user_push_level.id, type: :user, user_id: user.id, username: user.username, name: user.name, avatar_url: user.avatar_url },
          { id: group_push_level.id, type: :group, group_id: group.id }
        ]

        expect(access_levels_data).to eq(expected_array)
      end

      context 'with a member_role access level' do
        let_it_be(:root_group) { create(:group) }
        let_it_be_with_reload(:project_with_group) { create(:project, group: root_group) }
        let(:protected_branch_with_group) do
          create(:protected_branch, :developers_can_merge, project: project_with_group, default_access_level: false)
        end

        let(:member_role) { create(:member_role, namespace: root_group) }
        let(:member_role_push_level) do
          create(:protected_branch_push_access_level, protected_branch: protected_branch_with_group,
            member_role: member_role)
        end

        let(:access_levels) { [member_role_push_level] }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'returns id, type :member_role, and member_role_id' do
          expect(access_levels_data).to eq([
            { id: member_role_push_level.id, type: :member_role, member_role_id: member_role.id }
          ])
        end
      end
    end
  end

  describe '#preselected_push_access_levels_data' do
    subject(:preselected_push_access_levels_data) do
      helper.preselected_push_access_levels_data(access_levels, can_push)
    end

    let(:access_levels) { [instance_double(ProtectedBranch::PushAccessLevel)] }

    context 'when can_push is false' do
      let(:can_push) { false }

      it { is_expected.to contain_exactly(id: nil, type: :role, access_level: Gitlab::Access::NO_ACCESS) }
    end

    context 'when can_push is true' do
      let(:can_push) { true }

      it 'calls access_levels_data method' do
        expect(helper).to receive(:access_levels_data).with(access_levels)

        preselected_push_access_levels_data
      end
    end
  end
end

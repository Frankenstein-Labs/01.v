# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::Settings::BranchRulesHelper, feature_category: :source_code_management do
  include Devise::Test::ControllerHelpers

  let_it_be(:project) { create(:project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- build_stubbed cannot be used with real policy checks that require DB-persisted membership
  let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- build_stubbed cannot be used with real policy checks that require DB-persisted membership
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user_namespace) { build_stubbed(:user_namespace) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#group_protected_branches_licensed_and_can_admin?' do
    let(:root_ancestor) { group }
    let(:group_protected_branches_licensed) { true }
    let(:can_admin_group) { true }

    subject { helper.group_protected_branches_licensed_and_can_admin?(project) }

    before do
      stub_licensed_features(group_protected_branches: group_protected_branches_licensed)
      allow(project).to receive(:root_ancestor).and_return(root_ancestor)
      allow(user).to receive(:can?).with(:admin_group, group).and_return(can_admin_group)
    end

    it { is_expected.to be(true) }

    context 'when project has no group' do
      let(:root_ancestor) { user_namespace }

      it { is_expected.to be(false) }
    end

    context 'when group_protected_branches is not licensed' do
      let(:group_protected_branches_licensed) { false }

      it { is_expected.to be(false) }
    end

    context 'when user cannot admin_group' do
      let(:can_admin_group) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '#group_branch_rules_path' do
    let(:root_ancestor) { group }
    let(:group_repo_settings_path_with_anchor) do
      group_settings_repository_path(group, anchor: 'js-protected-branches-settings')
    end

    subject { helper.group_branch_rules_path(project) }

    before do
      allow(project).to receive(:root_ancestor).and_return(root_ancestor)
    end

    it { is_expected.to eq(group_repo_settings_path_with_anchor) }

    context 'when project has no group' do
      let(:root_ancestor) { user_namespace }

      it { is_expected.to eq('') }
    end
  end

  describe '#branch_rules_data' do
    subject(:data) { helper.branch_rules_data(project) }

    context 'when features are licensed' do
      before do
        stub_licensed_features(
          external_status_checks: true,
          merge_request_approvers: true,
          code_owner_approval_required: true,
          protected_refs_for_users: true,
          custom_roles: true
        )
      end

      context 'when user has permission to view the features' do
        before do
          allow(helper).to receive(:can?).and_return(true)
        end

        it 'returns branch rules data with all features shown' do
          expect(data).to match({
            project_path: project.full_path,
            protected_branches_path: project_settings_repository_path(project,
              anchor: 'js-protected-branches-settings'),
            approval_rules_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-approval-settings'),
            branch_rules_path: project_settings_repository_path(project, anchor: 'branch-rules'),
            status_checks_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-settings'),
            branches_path: project_branches_path(project),
            show_status_checks: 'true',
            show_approvers: 'true',
            show_code_owners: 'true',
            show_enterprise_access_levels: 'true',
            custom_roles_for_protected_branches_enabled: 'true',
            allow_multi_rule: 'false',
            can_edit: 'true',
            project_id: project.id,
            rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
            can_admin_protected_branches: 'true',
            can_read_squash_option: 'true',
            can_update_squash_option: 'true',
            can_admin_group_protected_branches: 'false',
            group_settings_repository_path: '',
            security_policies_path: project_security_policies_path(project)
          })
        end
      end

      context 'when user does not have permission to view the features' do
        before do
          allow(helper).to receive(:can?).and_return(false)
        end

        it 'returns branch rules data with all gated features hidden' do
          expect(data).to match({
            project_path: project.full_path,
            protected_branches_path: project_settings_repository_path(project,
              anchor: 'js-protected-branches-settings'),
            approval_rules_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-approval-settings'),
            branch_rules_path: project_settings_repository_path(project, anchor: 'branch-rules'),
            status_checks_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-settings'),
            branches_path: project_branches_path(project),
            show_status_checks: 'false',
            show_approvers: 'false',
            show_code_owners: 'true',
            show_enterprise_access_levels: 'true',
            custom_roles_for_protected_branches_enabled: 'true',
            allow_multi_rule: 'false',
            can_edit: 'false',
            project_id: project.id,
            rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
            can_admin_protected_branches: 'false',
            can_read_squash_option: 'false',
            can_update_squash_option: 'false',
            can_admin_group_protected_branches: 'false',
            group_settings_repository_path: '',
            security_policies_path: project_security_policies_path(project)
          })
        end
      end

      context 'when the custom_roles_for_protected_branches feature flag is disabled' do
        before do
          stub_feature_flags(custom_roles_for_protected_branches: false)
          allow(helper).to receive(:can?).and_return(true)
        end

        it { is_expected.to include(custom_roles_for_protected_branches_enabled: 'false') }
      end

      context 'when custom_roles is not licensed' do
        before do
          stub_licensed_features(custom_roles: false)
          allow(helper).to receive(:can?).and_return(true)
        end

        it { is_expected.to include(custom_roles_for_protected_branches_enabled: 'false') }
      end

      describe 'show_status_checks' do
        context 'when user is a developer' do
          let_it_be(:developer) { create(:user, developer_of: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- build_stubbed cannot be used with real policy checks that require DB-persisted membership

          before do
            allow(helper).to receive(:current_user).and_return(developer)
          end

          it { is_expected.to include(show_status_checks: 'false') }
        end

        context 'when user is a maintainer' do
          before_all do
            project.add_maintainer(user)
          end

          it { is_expected.to include(show_status_checks: 'true') }
        end
      end

      describe 'show_approvers' do
        context 'when user is not a member' do
          let_it_be(:non_member) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- build_stubbed cannot be used with real policy checks that require DB-persisted membership

          before do
            allow(helper).to receive(:current_user).and_return(non_member)
          end

          it { is_expected.to include(show_approvers: 'false') }
        end

        context 'when user is a guest' do
          before_all do
            project.add_guest(user)
          end

          it { is_expected.to include(show_approvers: 'true') }
        end
      end
    end

    context 'when features are not licensed' do
      before do
        stub_licensed_features(
          external_status_checks: false,
          merge_request_approvers: false,
          code_owner_approval_required: false,
          protected_refs_for_users: false,
          custom_roles: true
        )
      end

      context 'when user has permission to view the features' do
        before do
          allow(helper).to receive(:can?).and_return(true)
        end

        it 'returns branch rules data with all gated features hidden' do
          expect(data).to match({
            project_path: project.full_path,
            protected_branches_path: project_settings_repository_path(project,
              anchor: 'js-protected-branches-settings'),
            approval_rules_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-approval-settings'),
            branch_rules_path: project_settings_repository_path(project, anchor: 'branch-rules'),
            status_checks_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-settings'),
            branches_path: project_branches_path(project),
            show_status_checks: 'false',
            show_approvers: 'false',
            show_code_owners: 'false',
            show_enterprise_access_levels: 'false',
            custom_roles_for_protected_branches_enabled: 'true',
            allow_multi_rule: 'false',
            can_edit: 'true',
            project_id: project.id,
            rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
            can_admin_protected_branches: 'true',
            can_read_squash_option: 'true',
            can_update_squash_option: 'true',
            can_admin_group_protected_branches: 'false',
            group_settings_repository_path: '',
            security_policies_path: project_security_policies_path(project)
          })
        end
      end

      context 'when user does not have permission to view the features' do
        before do
          allow(helper).to receive(:can?).and_return(false)
        end

        it 'returns branch rules data with all gated features hidden' do
          expect(data).to match({
            project_path: project.full_path,
            protected_branches_path: project_settings_repository_path(project,
              anchor: 'js-protected-branches-settings'),
            approval_rules_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-approval-settings'),
            branch_rules_path: project_settings_repository_path(project, anchor: 'branch-rules'),
            status_checks_path: project_settings_merge_requests_path(project,
              anchor: 'js-merge-request-settings'),
            branches_path: project_branches_path(project),
            show_status_checks: 'false',
            show_approvers: 'false',
            show_code_owners: 'false',
            show_enterprise_access_levels: 'false',
            custom_roles_for_protected_branches_enabled: 'true',
            allow_multi_rule: 'false',
            can_edit: 'false',
            project_id: project.id,
            rules_path: expose_path(api_v4_projects_approval_rules_path(id: project.id)),
            can_admin_protected_branches: 'false',
            can_read_squash_option: 'false',
            can_update_squash_option: 'false',
            can_admin_group_protected_branches: 'false',
            group_settings_repository_path: '',
            security_policies_path: project_security_policies_path(project)
          })
        end
      end
    end

    context 'when project has a group' do
      let_it_be(:group) { build_stubbed(:group) }
      let_it_be(:project_with_group) { build_stubbed(:project, group: group) }

      subject(:data) { helper.branch_rules_data(project_with_group) }

      before do
        allow(helper).to receive(:can?).and_return(false)
      end

      it 'includes group settings repository path' do
        expect(data[:group_settings_repository_path]).to eq(
          group_settings_repository_path(group, anchor: 'js-protected-branches-settings')
        )
      end
    end
  end
end

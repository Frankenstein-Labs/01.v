# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestPolicy, :aggregate_failures, factory_default: :keep, feature_category: :code_review_workflow do
  include ProjectForksHelper
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:namespace) { create_default(:namespace).freeze }

  let_it_be(:guest, freeze: false) { create(:user) }
  let_it_be(:developer, freeze: false) { create(:user) }
  let_it_be(:planner, freeze: false) { create(:user) }
  let_it_be(:maintainer, freeze: false) { create(:user) }
  let_it_be(:reporter, freeze: false) { create(:user) }
  let_it_be(:security_manager, freeze: false) { create(:user) }
  let_it_be(:admin, freeze: false) { create(:admin) }

  let_it_be(:fork_guest) { create(:user) }
  let_it_be(:fork_developer) { create(:user) }
  let_it_be(:fork_maintainer) { create(:user) }

  let_it_be_with_reload(:project) do
    create(:project, :internal,
      guests: guest,
      planners: planner,
      developers: developer,
      maintainers: maintainer,
      reporters: reporter,
      security_managers: security_manager
    )
  end

  let(:owner) { project.owner }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  subject(:policy) { described_class.new(user, merge_request) }

  context 'for a merge request within the same project' do
    before do
      enable_admin_mode!(admin)
    end

    context 'when overwriting approvers is disabled on the project' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      where(:user) do
        [
          ref(:guest),
          ref(:developer),
          ref(:maintainer),
          ref(:admin),
          ref(:fork_guest),
          ref(:fork_developer),
          ref(:fork_maintainer)
        ]
      end

      with_them do
        specify { expect_disallowed(:update_approvers) }
      end
    end

    context 'when overwriting approvers is enabled on the project' do
      context 'when approval_rules_editable_by is true' do
        before do
          allow(merge_request).to receive(:approval_rules_editable_by?).and_return(true)
        end

        where(:user, :allowed) do
          ref(:developer)       | true
          ref(:maintainer)      | true
          ref(:admin)           | true
          ref(:guest)           | false
          ref(:fork_guest)      | false
          ref(:fork_developer)  | false
          ref(:fork_maintainer) | false
        end

        with_them do
          specify { allowed ? expect_allowed(:update_approvers) : expect_disallowed(:update_approvers) }
        end
      end

      context 'when approval_rules_editable_by is false' do
        before do
          allow(merge_request).to receive(:approval_rules_editable_by?).at_least(:once).and_return(false)
        end

        where(:user) do
          [
            ref(:guest),
            ref(:developer),
            ref(:maintainer),
            ref(:admin),
            ref(:fork_guest),
            ref(:fork_developer),
            ref(:fork_maintainer)
          ]
        end

        with_them do
          specify { expect_disallowed(:update_approvers) }
        end
      end
    end
  end

  context 'for a merge request from a fork' do
    let(:forked_project) { fork_project(project) }
    let(:fork_merge_request) { create(:merge_request, author: fork_developer, source_project: forked_project, target_project: project) }
    let(:merge_request) { fork_merge_request }

    before do
      forked_project.add_guest(fork_guest)
      forked_project.add_developer(fork_developer)
      forked_project.add_maintainer(fork_maintainer)

      enable_admin_mode!(admin)
    end

    context 'when approval_rules_editable_by is true' do
      before do
        allow(merge_request).to receive(:approval_rules_editable_by?).and_return(true)
      end

      context 'when overwriting approvers is disabled on the target project' do
        before do
          project.update!(disable_overriding_approvers_per_merge_request: true)
        end

        where(:user, :allowed) do
          ref(:guest)           | false
          ref(:developer)       | true
          ref(:maintainer)      | true
          ref(:admin)           | true
          ref(:fork_guest)      | false
          ref(:fork_developer)  | true # Author
          ref(:fork_maintainer) | false
        end

        with_them do
          specify { allowed ? expect_allowed(:update_approvers) : expect_disallowed(:update_approvers) }
        end
      end

      context 'when overwriting approvers is disabled on the source project' do
        before do
          forked_project.update!(disable_overriding_approvers_per_merge_request: true)
        end

        where(:user, :allowed) do
          ref(:developer)       | true
          ref(:maintainer)      | true
          ref(:fork_developer)  | true # Author
          ref(:admin)           | true
          ref(:guest)           | false
          ref(:fork_guest)      | false
          ref(:fork_maintainer) | false
        end

        with_them do
          specify { allowed ? expect_allowed(:update_approvers) : expect_disallowed(:update_approvers) }
        end
      end

      context 'when overwriting approvers is enabled on the target project' do
        where(:user, :allowed) do
          ref(:developer)       | true
          ref(:maintainer)      | true
          ref(:fork_developer)  | true # Author
          ref(:admin)           | true
          ref(:guest)           | false
          ref(:fork_guest)      | false
          ref(:fork_maintainer) | false
        end

        with_them do
          specify { allowed ? expect_allowed(:update_approvers) : expect_disallowed(:update_approvers) }
        end
      end
    end

    context 'when approval_rules_editable_by is false' do
      before do
        allow(merge_request).to receive(:approval_rules_editable_by?).and_return(false)
      end

      where(:user) do
        [
          ref(:guest),
          ref(:developer),
          ref(:maintainer),
          ref(:admin),
          ref(:fork_guest),
          ref(:fork_developer),
          ref(:fork_maintainer)
        ]
      end

      with_them do
        specify { expect_disallowed(:update_approvers) }
      end
    end
  end

  context 'for a merge request on a protected branch' do
    let_it_be(:approver_group) { create(:group) }
    let_it_be_with_reload(:project2) { create(:project, :internal) }
    let(:branch_name) { 'feature' }
    let(:protected_branch) { create(:protected_branch, project: project2, name: branch_name) }
    let(:merge_request) do
      create(:merge_request, source_project: project2, target_project: project2, target_branch: branch_name)
    end

    let(:permission) { :approve_merge_request }

    where(:role, :allowed) do
      :guest      | false
      :planner    | true
      :reporter   | true
      :developer  | true
      :maintainer | true
    end

    with_them do
      let(:user) { public_send(role) }
      let(:access_level) { Gitlab::Access.const_get(role.to_s.upcase, false) }

      context 'when the role nor the group is added' do
        it { expect_disallowed(permission) }
      end

      context 'when a group-level approval rule exists' do
        let(:approval_project_rule) do
          create :approval_project_rule, project: project2, approvals_required: 1
        end

        context 'when the merge request targets the protected branch' do
          before do
            approval_project_rule.protected_branches << protected_branch
            approval_project_rule.groups << approver_group
          end

          context 'when the user is not a group member' do
            it { expect_disallowed(permission) }
          end

          context 'when the user is a group member' do
            before do
              approver_group.add_member(user, access_level)
            end

            specify { allowed ? expect_allowed(permission) : expect_disallowed(permission) }
          end
        end

        context 'when the user has permission for a different protected branch' do
          let(:protected_branch2) do
            create(:protected_branch, project: project2, name: branch_name, code_owner_approval_required: true)
          end

          before do
            approval_project_rule.protected_branches << protected_branch2
            approval_project_rule.groups << approver_group
          end

          it { expect_disallowed(permission) }
        end

        context 'when the protected branch name is a wildcard' do
          let(:wildcard_protected_branch) { create(:protected_branch, project: project2, name: '*-stable') }

          before do
            approval_project_rule.protected_branches << wildcard_protected_branch
            approval_project_rule.groups << approver_group
            approver_group.add_member(user, access_level)
          end

          context 'when the user has permission for the wildcarded branch' do
            let_it_be(:branch_name) { '13-4-stable' }

            specify { allowed ? expect_allowed(permission) : expect_disallowed(permission) }
          end

          context 'when the user does not have permission for the wildcarded branch' do
            let_it_be(:branch_name) { '13-4-pre' }

            it { expect_disallowed(permission) }
          end
        end
      end
    end
  end

  context 'for a merge request on a branch protected at the group level' do
    let_it_be(:approver_group) { create(:group) }
    let_it_be(:root_group, freeze: false) { create(:group) }
    let_it_be_with_reload(:group_project) { create(:project, :internal, group: root_group) }
    let(:branch_name) { 'feature' }
    let(:protected_branch) do
      create(:protected_branch, :group_level, group: root_group, name: branch_name)
    end

    let(:merge_request) do
      create(:merge_request, source_project: group_project, target_project: group_project, target_branch: branch_name)
    end

    let(:permission) { :approve_merge_request }

    let(:approval_project_rule) do
      create :approval_project_rule, project: group_project, approvals_required: 1
    end

    let(:user) { reporter }

    before do
      approval_project_rule.protected_branches << protected_branch
      approval_project_rule.groups << approver_group
    end

    context 'when the user is not a group member' do
      it { expect_disallowed(permission) }
    end

    context 'when the user is a group member' do
      before_all do
        approver_group.add_reporter(reporter)
      end

      it { expect_allowed(permission) }
    end
  end

  context 'for a merge request on a branch protected at both the project and group levels' do
    let_it_be(:approver_group) { create(:group) }
    let_it_be(:root_group, freeze: false) { create(:group) }
    let_it_be_with_reload(:group_project) { create(:project, :internal, group: root_group) }
    let(:branch_name) { 'feature' }
    let(:project_protected_branch) do
      create(:protected_branch, project: group_project, name: branch_name)
    end

    let(:group_protected_branch) do
      create(:protected_branch, :group_level, group: root_group, name: branch_name)
    end

    let(:merge_request) do
      create(:merge_request, source_project: group_project, target_project: group_project, target_branch: branch_name)
    end

    let(:permission) { :approve_merge_request }

    let(:approval_project_rule) do
      create :approval_project_rule, project: group_project, approvals_required: 1
    end

    let(:user) { reporter }

    before_all do
      approver_group.add_reporter(reporter)
    end

    before do
      # The group-level record matches the branch but carries no approval rule;
      # only the project-level record is linked to the rule.
      group_protected_branch
      approval_project_rule.protected_branches << project_protected_branch
      approval_project_rule.groups << approver_group
    end

    it { expect_allowed(permission) }
  end

  context 'for a group-level protected branch shared across sibling projects' do
    let_it_be(:approver_group) { create(:group) }
    let_it_be(:root_group, freeze: false) { create(:group) }
    let_it_be_with_reload(:project_a) { create(:project, :internal, group: root_group) }
    let_it_be_with_reload(:project_b) { create(:project, :internal, group: root_group) }
    let(:branch_name) { 'feature' }

    let(:group_protected_branch) do
      create(:protected_branch, :group_level, group: root_group, name: branch_name)
    end

    # The rule lives on project_a, linked to the shared group-level protected branch.
    let(:approval_project_rule) do
      create(:approval_project_rule, project: project_a, approvals_required: 1)
    end

    # The MR is on project_b; the user has no membership in project_b.
    let(:merge_request) do
      create(:merge_request, source_project: project_b, target_project: project_b, target_branch: branch_name)
    end

    let(:user) { reporter }

    before_all do
      approver_group.add_reporter(reporter)
    end

    before do
      approval_project_rule.protected_branches << group_protected_branch
      approval_project_rule.groups << approver_group
    end

    it 'does not let a sibling project rule grant approval on this project MR' do
      expect(project_b.all_protected_branches.map(&:id)).to include(group_protected_branch.id)
      expect(project_b.member?(reporter)).to be(false)

      expect_disallowed(:approve_merge_request)
    end
  end

  context 'when checking for namespace in read only state' do
    context 'when namespace is in a read only state' do
      before do
        allow(merge_request.target_project.namespace).to receive(:read_only?).and_return(true)
      end

      context 'for a maintainer' do
        let(:user) { maintainer }

        it { expect_disallowed(:update_merge_request) }
      end

      context 'for a developer' do
        let(:user) { developer }

        it { expect_allowed(:approve_merge_request) }
      end
    end

    context 'when namespace is not in a read only state' do
      before do
        allow(merge_request.target_project.namespace).to receive(:read_only?).and_return(false)
      end

      context 'for a maintainer' do
        let(:user) { maintainer }

        specify do
          expect_allowed(
            :approve_merge_request,
            :update_merge_request,
            :reopen_merge_request,
            :create_note
          )
        end
      end
    end
  end

  shared_examples 'external_status_check_access' do
    using RSpec::Parameterized::TableSyntax

    where(:role, :licensed, :allowed) do
      :guest      | false  | false
      :reporter   | false  | false
      :developer  | false  | false
      :maintainer | false  | false
      :owner      | false  | false
      :admin      | false  | false
      :guest      | true   | ref(:allowed_for_guest)
      :reporter   | true   | ref(:allowed_for_reporter)
      :developer  | true   | true
      :maintainer | true   | true
      :owner      | true   | true
      :admin      | true   | true
    end

    with_them do
      let(:user) { public_send(role) }

      before do
        stub_licensed_features(external_status_checks: licensed)
        enable_admin_mode!(user) if role.eql?(:admin)
      end

      specify { allowed ? expect_allowed(permission) : expect_disallowed(permission) }
    end
  end

  describe 'retry_failed_status_checks' do
    let(:permission) { :retry_failed_status_checks }
    let(:allowed_for_reporter) { false }
    let(:allowed_for_guest) { false }

    it_behaves_like 'external_status_check_access'
  end

  describe 'read_external_status_check_response' do
    let(:permission) { :read_external_status_check_response }
    let(:allowed_for_reporter) { true }

    context 'when project is internal' do
      let_it_be_with_reload(:project) { create(:project, :internal, guests: guest, reporters: reporter, developers: developer, maintainers: maintainer) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      context 'when user is external' do
        let(:allowed_for_guest) { false }

        before do
          user.update!(external: true)
        end

        it_behaves_like 'external_status_check_access'
      end

      context 'when user is internal' do
        let(:allowed_for_guest) { true }

        before do
          user.update!(external: false)
        end

        it_behaves_like 'external_status_check_access'
      end
    end

    context 'when project is private' do
      let_it_be_with_reload(:project) { create(:project, :private, guests: guest, reporters: reporter, developers: developer, maintainers: maintainer) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      let(:allowed_for_guest) { false }

      it_behaves_like 'external_status_check_access'
    end
  end

  describe 'provide_status_check_response' do
    let(:permission) { :provide_status_check_response }
    let(:allowed_for_reporter) { false }
    let(:allowed_for_guest) { false }

    it_behaves_like 'external_status_check_access'
  end

  describe 'create_merge_request_approval_rules' do
    let(:user) { owner }

    where(:coverage_license_enabled, :report_approver_license_enabled, :allowed) do
      false | false | false
      true  | true  | true
      false | true  | true
      true  | false | true
    end

    with_them do
      before do
        stub_licensed_features(
          coverage_check_approval_rule: coverage_license_enabled,
          report_approver_rules: report_approver_license_enabled
        )
      end

      specify { allowed ? expect_allowed(:create_merge_request_approval_rules) : expect_disallowed(:create_merge_request_approval_rules) }
    end
  end

  describe 'force_evaluate_merge_request_security_policy' do
    where(:role, :licensed, :allowed) do
      :guest            | true  | false
      :reporter         | true  | false
      :security_manager | true  | true
      :developer        | true  | true
      :maintainer       | true  | true
      :owner            | true  | true
      :security_manager | false | false
      :developer        | false | false
      :maintainer       | false | false
      :owner            | false | false
    end

    with_them do
      let(:user) { public_send(role) }

      before do
        stub_licensed_features(security_orchestration_policies: licensed)
      end

      specify do
        allowed ? expect_allowed(:force_evaluate_merge_request_security_policy) : expect_disallowed(:force_evaluate_merge_request_security_policy)
      end
    end
  end

  describe "Custom roles `admin_merge_request` ability" do
    let_it_be(:project, freeze: false) { create(:project, :private, :in_group) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    let(:ability) { :approve_merge_request }
    let(:resource) { merge_request }
    let(:resource_parent) { project.group }
    let(:user) { guest }

    context 'when the `custom_roles` feature is enabled' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when user has the admin_merge_request permission' do
        context 'with a custom role' do
          let_it_be(:custom_role) { create(:member_role, :guest, namespace: project.group, admin_merge_request: true) }
          let_it_be(:project_member) { create(:project_member, :guest, member_role: custom_role, project: project, user: guest) }

          it 'enables the `approve_merge_request` ability' do
            expect_allowed(ability)
          end
        end

        context 'as a developer+' do
          it_behaves_like 'does not call custom role query', [:developer, :maintainer, :owner]
        end
      end

      context 'when user does not have the admin_merge_request permission' do
        context 'with a custom role' do
          let_it_be(:custom_role) { create(:member_role, :guest, namespace: project.group, admin_merge_request: false) }
          let_it_be(:project_member) { create(:project_member, :guest, member_role: custom_role, project: project, user: guest) }

          it 'disables the `approve_merge_request` ability' do
            expect_disallowed(ability)
          end
        end
      end
    end

    context 'when the `custom_roles` feature is disabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'disables the `approve_merge_request` ability' do
        expect_disallowed(ability)
      end
    end
  end

  describe 'access_generate_commit_message' do
    let(:user) { owner }

    where(:duo_features_enabled, :allowed_to_use, :allowed) do
      true  | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        allow(project)
          .to receive_message_chain(:project_setting, :duo_features_enabled?)
          .and_return(duo_features_enabled)

        allow(user).to receive(:allowed_to_use?)
          .with(:generate_commit_message, licensed_feature: :generate_commit_message).and_return(allowed_to_use)
      end

      specify { allowed ? expect_allowed(:access_generate_commit_message) : expect_disallowed(:access_generate_commit_message) }
    end
  end

  describe 'access_summarize_review' do
    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }
    let(:user) { can_read_mr ? reporter : nil }

    where(:duo_features_enabled, :feature_flag_enabled, :llm_authorized, :can_read_mr, :allowed) do
      true  | true  | true  | true  | true
      true  | true  | true  | false | false
      true  | false | true  | true  | false
      true  | true  | false | true  | false
      false | true  | true  | true  | false
    end

    with_them do
      before do
        # Setup Duo features
        allow(project)
          .to receive_message_chain(:project_setting, :duo_features_enabled?)
          .and_return(duo_features_enabled)

        # Setup feature flag
        stub_feature_flags(summarize_my_code_review: feature_flag_enabled)

        # Setup LLM authorizer
        allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
        allow(authorizer).to receive(:allowed?).and_return(llm_authorized)
      end

      specify { allowed ? expect_allowed(:access_summarize_review) : expect_disallowed(:access_summarize_review) }
    end
  end

  describe 'with nil user and a public project' do
    let(:group) { create(:group) }
    let(:project) { create(:project, :public) }
    let(:protected_branch) { create(:protected_branch, project: project, name: 'master') }
    let(:merge_request) { build(:merge_request, project: project, target_branch: 'master') }
    let(:user) { nil }

    before do
      rule = create(:approval_project_rule, project: project, approvals_required: 1)
      rule.protected_branches << protected_branch
      rule.groups << group
      rule.save!
    end

    it 'disallows approve_merge_request' do
      expect_disallowed(:approve_merge_request)
    end

    it 'does not query all_protected_branches' do
      expect(project).not_to receive(:all_protected_branches)

      expect_disallowed(:approve_merge_request)
    end
  end
end

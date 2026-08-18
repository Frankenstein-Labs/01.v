# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalProjectRulePolicy, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:approval_rule) { create(:approval_project_rule, project: project) }

  context 'when user can admin project' do
    subject { described_class.new(project.creator, approval_rule) }

    it { expect_allowed(:modify_approvers_rules) }
    it { expect_allowed(:create_approval_rule) }
    it { expect_allowed(:update_approval_rule) }
    it { expect_allowed(:delete_approval_rule) }
  end

  context 'when user is an auditor' do
    let_it_be(:auditor) { create(:user, :auditor) }

    subject { described_class.new(auditor, approval_rule) }

    it { expect_allowed(:read_approval_rule) }
    it { expect_disallowed(:modify_approvers_rules) }
    it { expect_disallowed(:create_approval_rule) }
    it { expect_disallowed(:update_approval_rule) }
    it { expect_disallowed(:delete_approval_rule) }
  end

  context 'when user cannot admin project' do
    let_it_be(:user) { create(:user) }

    before_all do
      project.add_developer(user)
    end

    subject { described_class.new(user, approval_rule) }

    it { expect_disallowed(:modify_approvers_rules) }
    it { expect_disallowed(:create_approval_rule) }
    it { expect_disallowed(:update_approval_rule) }
    it { expect_disallowed(:delete_approval_rule) }
  end

  context 'when the instance-level approval rule lock is enabled' do
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }

    let(:user) { maintainer }

    subject { described_class.new(user, approval_rule) }

    before do
      stub_application_setting(disable_overriding_approvers_per_merge_request: true)
    end

    context 'with the admin_merge_request_approvers_rules license' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: true)
      end

      it { expect_disallowed(:modify_approvers_rules) }
      it { expect_disallowed(:create_approval_rule) }
      it { expect_disallowed(:update_approval_rule) }
      it { expect_disallowed(:delete_approval_rule) }

      context 'when the user is an instance admin', :enable_admin_mode do
        let(:user) { create(:admin) }

        it { expect_allowed(:modify_approvers_rules) }
        it { expect_allowed(:create_approval_rule) }
        it { expect_allowed(:update_approval_rule) }
        it { expect_allowed(:delete_approval_rule) }
      end
    end

    context 'without the admin_merge_request_approvers_rules license' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: false)
      end

      it { expect_allowed(:modify_approvers_rules) }
      it { expect_allowed(:create_approval_rule) }
      it { expect_allowed(:update_approval_rule) }
      it { expect_allowed(:delete_approval_rule) }
    end
  end

  context 'when only the project-level override setting is enabled' do
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }

    let(:user) { maintainer }

    subject { described_class.new(user, approval_rule) }

    before do
      stub_licensed_features(admin_merge_request_approvers_rules: true)
      project.update!(disable_overriding_approvers_per_merge_request: true)
    end

    it { expect_allowed(:modify_approvers_rules) }
    it { expect_allowed(:create_approval_rule) }
    it { expect_allowed(:update_approval_rule) }
    it { expect_allowed(:delete_approval_rule) }
  end

  context 'when a merge request approval policy prevents editing approval rules' do
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let_it_be(:policy) do
      create(:security_policy,
        :prevent_editing_approval_rules,
        security_orchestration_policy_configuration: configuration,
        linked_projects: [project])
    end

    let(:user) { maintainer }

    subject { described_class.new(user, approval_rule) }

    before do
      stub_licensed_features(admin_merge_request_approvers_rules: true, security_orchestration_policies: true)
    end

    it { expect_allowed(:modify_approvers_rules) }
    it { expect_allowed(:create_approval_rule) }
    it { expect_allowed(:update_approval_rule) }
    it { expect_allowed(:delete_approval_rule) }
  end
end

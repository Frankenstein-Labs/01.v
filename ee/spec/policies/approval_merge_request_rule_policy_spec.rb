# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalMergeRequestRulePolicy, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :private, disable_overriding_approvers_per_merge_request: false) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  let(:user) { developer }
  let(:approval_rule) { build(:approval_merge_request_rule, merge_request: merge_request) }

  subject(:permissions) { described_class.new(user, approval_rule) }

  before do
    approval_rule.merge_request&.project&.clear_memoization(:disable_overriding_approvers_per_merge_request)
  end

  context 'when user is an auditor' do
    let_it_be(:auditor) { create(:user, :auditor) }
    let(:approval_rule) { build(:approval_merge_request_rule, merge_request: merge_request) }

    subject { described_class.new(auditor, approval_rule) }

    before do
      allow(approval_rule).to receive(:user_defined?).and_return(true)
    end

    it { expect_allowed(:read_approval_rule) }
    it { expect_disallowed(:create_approval_rule) }
    it { expect_disallowed(:update_approval_rule) }
    it { expect_disallowed(:delete_approval_rule) }
  end

  describe 'approval rule permissions' do
    context 'when approval rule is user_defined' do
      before do
        allow(approval_rule).to receive(:user_defined?).and_return(true)
      end

      context 'and user can update_approvers (maintainer)' do
        let(:user) { maintainer }

        it { expect_allowed(:create_approval_rule) }
        it { expect_allowed(:update_approval_rule) }
        it { expect_allowed(:delete_approval_rule) }
      end

      context 'and user is a Developer who is the MR author' do
        let_it_be(:developer_author) { create(:user, developer_of: project) }
        let_it_be(:mr_authored_by_developer, freeze: false) do
          create(:merge_request, source_project: project, source_branch: 'feature_conflict', author: developer_author)
        end

        let(:user) { developer_author }
        let(:approval_rule) { build(:approval_merge_request_rule, merge_request: mr_authored_by_developer) }

        it { expect_allowed(:create_approval_rule) }
        it { expect_allowed(:update_approval_rule) }
        it { expect_allowed(:delete_approval_rule) }
      end

      context 'and user is a Developer who is the MR assignee' do
        let_it_be(:developer_assignee, freeze: false) { create(:user, developer_of: project) }
        let_it_be(:mr_assigned_to_developer, freeze: false) do
          create(:merge_request, source_project: project, source_branch: 'feature_one', assignees: [developer_assignee])
        end

        let(:user) { developer_assignee }
        let(:approval_rule) { build(:approval_merge_request_rule, merge_request: mr_assigned_to_developer) }

        it { expect_allowed(:create_approval_rule) }
        it { expect_allowed(:update_approval_rule) }
        it { expect_allowed(:delete_approval_rule) }
      end

      context 'and user cannot update_approvers (plain developer, not author/assignee)' do
        let(:user) { developer }

        it { expect_disallowed(:create_approval_rule) }
        it { expect_disallowed(:update_approval_rule) }
        it { expect_disallowed(:delete_approval_rule) }
      end
    end

    context 'when instance-level approval rule lock is enabled' do
      let(:user) { maintainer }

      before do
        allow(approval_rule).to receive(:user_defined?).and_return(true)
      end

      context 'with admin_merge_request_approvers_rules license' do
        before do
          stub_licensed_features(admin_merge_request_approvers_rules: true)
          stub_application_setting(disable_overriding_approvers_per_merge_request: true)
        end

        it { expect_disallowed(:create_approval_rule) }
        it { expect_disallowed(:update_approval_rule) }
        it { expect_disallowed(:delete_approval_rule) }

        context 'when user is admin', :enable_admin_mode do
          let(:user) { create(:admin) }

          it { expect_disallowed(:create_approval_rule) }
          it { expect_disallowed(:update_approval_rule) }
          it { expect_disallowed(:delete_approval_rule) }
        end

        context 'when user is a Developer who is the MR author' do
          let_it_be(:developer_author) { create(:user, developer_of: project) }
          let_it_be(:mr_authored_by_developer, freeze: false) do
            create(
              :merge_request,
              source_project: project,
              source_branch: 'add_images_and_changes',
              author: developer_author
            )
          end

          let(:user) { developer_author }
          let(:approval_rule) { build(:approval_merge_request_rule, merge_request: mr_authored_by_developer) }

          it { expect_disallowed(:create_approval_rule) }
          it { expect_disallowed(:update_approval_rule) }
          it { expect_disallowed(:delete_approval_rule) }
        end
      end

      context 'without admin_merge_request_approvers_rules license' do
        before do
          stub_licensed_features(admin_merge_request_approvers_rules: false)
          stub_application_setting(disable_overriding_approvers_per_merge_request: true)
        end

        it { expect_allowed(:create_approval_rule) }
        it { expect_allowed(:update_approval_rule) }
        it { expect_allowed(:delete_approval_rule) }
      end
    end

    context 'when approval rule is not user_defined' do
      before do
        allow(approval_rule).to receive(:user_defined?).and_return(false)
      end

      context 'and user can update_approvers' do
        let(:user) { maintainer }

        it { expect_disallowed(:create_approval_rule) }
        it { expect_disallowed(:update_approval_rule) }
        it { expect_disallowed(:delete_approval_rule) }
      end

      context 'and user cannot update_approvers' do
        let(:user) { developer }

        it { expect_disallowed(:create_approval_rule) }
        it { expect_disallowed(:update_approval_rule) }
        it { expect_disallowed(:delete_approval_rule) }
      end
    end
  end
end

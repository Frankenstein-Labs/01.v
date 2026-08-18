# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ApprovalGroupRulePolicy, feature_category: :source_code_management do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:approval_rule) { create(:approval_group_rule, group: group) }

  subject(:permissions) { described_class.new(user, approval_rule) }

  context 'when user is a group owner' do
    it { expect_allowed(:read_approval_rule) }
    it { expect_allowed(:create_approval_rule) }
    it { expect_allowed(:update_approval_rule) }
    it { expect_allowed(:delete_approval_rule) }
  end

  context 'when user is an auditor' do
    let_it_be(:user) { create(:user, :auditor) }

    it { expect_allowed(:read_approval_rule) }
    it { expect_disallowed(:create_approval_rule) }
    it { expect_disallowed(:update_approval_rule) }
    it { expect_disallowed(:delete_approval_rule) }
  end

  context 'when user is not a group member' do
    let_it_be(:user) { create(:user) }

    it { expect_disallowed(:read_approval_rule) }
    it { expect_disallowed(:create_approval_rule) }
    it { expect_disallowed(:update_approval_rule) }
    it { expect_disallowed(:delete_approval_rule) }
  end

  context 'when the instance-level approval rule lock is enabled' do
    before do
      stub_application_setting(disable_overriding_approvers_per_merge_request: true)
    end

    context 'with the admin_merge_request_approvers_rules license' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: true)
      end

      it { expect_allowed(:read_approval_rule) }
      it { expect_disallowed(:create_approval_rule) }
      it { expect_disallowed(:update_approval_rule) }
      it { expect_disallowed(:delete_approval_rule) }

      context 'when the user is an instance admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        it { expect_allowed(:read_approval_rule) }
        it { expect_allowed(:create_approval_rule) }
        it { expect_allowed(:update_approval_rule) }
        it { expect_allowed(:delete_approval_rule) }
      end
    end

    context 'without the admin_merge_request_approvers_rules license' do
      before do
        stub_licensed_features(admin_merge_request_approvers_rules: false)
      end

      it { expect_allowed(:read_approval_rule) }
      it { expect_allowed(:create_approval_rule) }
      it { expect_allowed(:update_approval_rule) }
      it { expect_allowed(:delete_approval_rule) }
    end
  end
end

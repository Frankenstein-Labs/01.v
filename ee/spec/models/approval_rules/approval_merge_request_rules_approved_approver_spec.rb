# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ApprovalMergeRequestRulesApprovedApprover, feature_category: :source_code_management do
  subject { build(:approval_merge_request_rules_approved_approver) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:approval_merge_request_rule) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:approval_merge_request_rule) }
  end
end

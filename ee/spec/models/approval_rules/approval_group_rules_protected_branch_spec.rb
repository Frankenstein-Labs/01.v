# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ApprovalGroupRulesProtectedBranch, feature_category: :source_code_management do
  subject { build(:approval_group_rules_protected_branch) }

  describe 'associations' do
    it { is_expected.to belong_to(:protected_branch) }
    it { is_expected.to belong_to(:approval_group_rule) }
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:protected_branch) }
    it { is_expected.to validate_presence_of(:approval_group_rule) }
  end
end

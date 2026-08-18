# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::GroupApprovalRule, feature_category: :source_code_management do
  subject(:hash) { described_class.new(approval_rule).as_json }

  let_it_be(:approval_rule) { create(:approval_group_rule) }

  it 'exposes attributes' do
    expect(hash.keys).to match_array(%i[
      id
      name
      rule_type
      report_type
      eligible_approvers
      approvals_required
      users
      groups
      contains_hidden_groups
      applies_to_all_protected_branches
    ])
  end

  context 'when multiple_approval_rules feature is available' do
    before do
      stub_licensed_features(multiple_approval_rules: true)
    end

    it 'exposes protected branches' do
      expect(hash.has_key?(:protected_branches)).to be_truthy
    end
  end

  context 'when multiple_approval_rules feature is not available' do
    it 'does not protected branches' do
      expect(hash.has_key?(:protected_branches)).to be_falsy
    end
  end
end

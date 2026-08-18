# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulesApproverGroup, type: :model, feature_category: :code_review_workflow do
  describe 'associations' do
    it { is_expected.to belong_to(:approval_rule) }
    it { is_expected.to belong_to(:group) }
  end
end

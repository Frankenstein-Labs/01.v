# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicyMergeRequestBypassEvent, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:security_policy) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:merge_request) }
  end

  describe 'validations' do
    subject { build(:approval_policy_merge_request_bypass_event, security_policy: create(:security_policy)) }

    it { is_expected.to validate_presence_of(:reason) }
    it { is_expected.to validate_length_of(:reason).is_at_most(1024) }
    it { is_expected.to validate_uniqueness_of(:project_id).scoped_to([:merge_request_id, :security_policy_id]) }
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::SecurityPolicyRequirement, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:compliance_framework_security_policy).optional(false) }
    it { is_expected.to belong_to(:compliance_requirement).optional(false) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace_id) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:compliance_framework_security_policy) }
  end
end

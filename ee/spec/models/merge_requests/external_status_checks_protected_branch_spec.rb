# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ExternalStatusChecksProtectedBranch, feature_category: :compliance_management do
  subject { build(:external_status_checks_protected_branch) }

  describe 'associations' do
    it { is_expected.to belong_to(:external_status_check) }
    it { is_expected.to belong_to(:protected_branch) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:external_status_check) }
    it { is_expected.to validate_presence_of(:protected_branch) }
  end
end

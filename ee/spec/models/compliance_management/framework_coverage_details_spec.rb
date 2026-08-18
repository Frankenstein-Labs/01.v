# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::FrameworkCoverageDetails, feature_category: :compliance_management do
  let(:framework) { create(:compliance_framework) }

  subject(:framework_coverage_details) { described_class.new(framework) }

  describe 'class inclusions' do
    it 'includes GlobalID::Identification' do
      expect(described_class.included_modules).to include(GlobalID::Identification)
    end
  end

  describe 'attribute readers' do
    it { is_expected.to respond_to(:id) }
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:color) }
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::SecurityGuideline, feature_category: :static_application_security_testing do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scan).class_name('Security::Ascp::Scan') }
    it { is_expected.to belong_to(:security_context).class_name('Security::Ascp::SecurityContext') }
  end

  describe 'validations' do
    subject { build(:security_ascp_security_guideline) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:scan) }
    it { is_expected.to validate_presence_of(:security_context) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:operation) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:severity_if_violated).with_values(low: 0, medium: 1, high: 2, critical: 3) }
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:scan1) { create(:security_ascp_scan, project: project, scan_sequence: 1) }
    let_it_be(:scan2) { create(:security_ascp_scan, project: project, scan_sequence: 2) }

    describe '.at_scan' do
      it 'returns guidelines for the given scan' do
        component1 = create(:security_ascp_component, project: project, scan: scan1)
        component2 = create(:security_ascp_component, project: project, scan: scan2)
        context1 = create(:security_ascp_security_context,
          project: project,
          scan: scan1,
          component: component1)
        context2 = create(:security_ascp_security_context,
          project: project,
          scan: scan2,
          component: component2)

        guideline1 = create(:security_ascp_security_guideline,
          project: project,
          scan: scan1,
          security_context: context1)
        create(:security_ascp_security_guideline,
          project: project,
          scan: scan2,
          security_context: context2)

        expect(described_class.at_scan(scan1.id)).to contain_exactly(guideline1)
      end
    end
  end
end

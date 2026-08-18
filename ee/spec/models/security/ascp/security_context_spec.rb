# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::SecurityContext, feature_category: :static_application_security_testing do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scan).class_name('Security::Ascp::Scan') }
    it { is_expected.to belong_to(:component).class_name('Security::Ascp::Component') }
    it { is_expected.to have_many(:guidelines).class_name('Security::Ascp::SecurityGuideline') }
  end

  describe 'validations' do
    subject { build(:security_ascp_security_context) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:scan) }
    it { is_expected.to validate_presence_of(:component) }
    it { is_expected.to validate_uniqueness_of(:component_id).scoped_to(:project_id, :scan_id) }
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:scan1) { create(:security_ascp_scan, project: project, scan_sequence: 1) }
    let_it_be(:scan2) { create(:security_ascp_scan, project: project, scan_sequence: 2) }

    describe '.at_scan' do
      it 'returns security contexts for the given scan' do
        component1 = create(:security_ascp_component, project: project, scan: scan1)
        component2 = create(:security_ascp_component, project: project, scan: scan2)

        context1 = create(:security_ascp_security_context,
          project: project,
          scan: scan1,
          component: component1)
        create(:security_ascp_security_context,
          project: project,
          scan: scan2,
          component: component2)

        expect(described_class.at_scan(scan1.id)).to contain_exactly(context1)
      end
    end
  end
end

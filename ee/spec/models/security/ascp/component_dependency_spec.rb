# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::ComponentDependency, feature_category: :static_application_security_testing do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:component).class_name('Security::Ascp::Component') }
    it { is_expected.to belong_to(:dependency).class_name('Security::Ascp::Component') }
  end

  describe 'validations' do
    subject { build(:security_ascp_component_dependency) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:component) }
    it { is_expected.to validate_presence_of(:dependency) }

    describe 'different_components validation' do
      let_it_be(:project) { create(:project) }
      let_it_be(:scan) { create(:security_ascp_scan, project: project) }
      let_it_be(:component) { create(:security_ascp_component, project: project, scan: scan) }

      it 'is invalid when component and dependency are the same' do
        dependency = build(:security_ascp_component_dependency,
          project: project,
          component: component,
          dependency: component)

        expect(dependency).not_to be_valid
        expect(dependency.errors[:dependency]).to include('cannot be the same as component')
      end

      it 'is valid when component and dependency are different' do
        other_component = create(:security_ascp_component, project: project, scan: scan)
        dependency = build(:security_ascp_component_dependency,
          project: project,
          component: component,
          dependency: other_component)

        expect(dependency).to be_valid
      end
    end
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:scan1) { create(:security_ascp_scan, project: project, scan_sequence: 1) }
    let_it_be(:scan2) { create(:security_ascp_scan, project: project, scan_sequence: 2) }

    describe '.at_scan' do
      it 'returns dependencies where the component belongs to the given scan' do
        component1 = create(:security_ascp_component, project: project, scan: scan1)
        component2 = create(:security_ascp_component, project: project, scan: scan1)
        component3 = create(:security_ascp_component, project: project, scan: scan2)
        component4 = create(:security_ascp_component, project: project, scan: scan2)

        dep1 = create(:security_ascp_component_dependency,
          project: project,
          component: component1,
          dependency: component2)
        create(:security_ascp_component_dependency,
          project: project,
          component: component3,
          dependency: component4)

        expect(described_class.at_scan(scan1.id)).to contain_exactly(dep1)
      end
    end
  end
end

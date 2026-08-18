# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::Component, feature_category: :static_application_security_testing do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scan).class_name('Security::Ascp::Scan') }
    it { is_expected.to have_one(:security_context).class_name('Security::Ascp::SecurityContext') }
    it { is_expected.to have_many(:vulnerability_finding_ascp_component_links).class_name('Vulnerabilities::AscpComponentLink') }
    it { is_expected.to have_many(:vulnerability_findings).through(:vulnerability_finding_ascp_component_links) }
    it { is_expected.to have_many(:dependencies).class_name('Security::Ascp::ComponentDependency') }
    it { is_expected.to have_many(:dependents).class_name('Security::Ascp::ComponentDependency') }
  end

  describe 'validations' do
    subject { build(:security_ascp_component) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:scan) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:sub_directory) }
    it { is_expected.to validate_uniqueness_of(:sub_directory).scoped_to(:project_id, :scan_id) }
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:scan1) { create(:security_ascp_scan, project: project, scan_sequence: 1) }
    let_it_be(:scan2) { create(:security_ascp_scan, project: project, scan_sequence: 2) }

    describe '.by_project' do
      it 'returns components for the given project' do
        component = create(:security_ascp_component, project: project, scan: scan1)
        create(:security_ascp_component) # different project

        expect(described_class.by_project(project.id)).to contain_exactly(component)
      end
    end

    describe '.at_scan' do
      it 'returns components for the given scan' do
        component1 = create(:security_ascp_component, project: project, scan: scan1)
        create(:security_ascp_component, project: project, scan: scan2)

        expect(described_class.at_scan(scan1.id)).to contain_exactly(component1)
      end
    end
  end

  describe '.pluck_id_and_sub_directory' do
    let_it_be(:project) { create(:project) }
    let_it_be(:scan) { create(:security_ascp_scan, project: project) }
    let_it_be(:component) { create(:security_ascp_component, project: project, scan: scan, sub_directory: 'app') }

    let(:limit) { 1 }

    subject(:id_and_sub_directories) { described_class.at_scan(scan.id).pluck_id_and_sub_directory(limit) }

    it 'returns id and sub_directory tuples' do
      expect(id_and_sub_directories).to contain_exactly([component.id, 'app'])
    end

    context 'when there are more records than requested' do
      before_all do
        create(:security_ascp_component, project: project, scan: scan, sub_directory: 'lib')
      end

      it 'returns at most the given number of tuples' do
        expect(id_and_sub_directories.length).to eq(limit)
      end
    end
  end
end

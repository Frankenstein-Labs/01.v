# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingRemediation, feature_category: :vulnerability_management do
  it { is_expected.to belong_to(:finding).class_name('Vulnerabilities::Finding').required }
  it { is_expected.to belong_to(:remediation).class_name('Vulnerabilities::Remediation').required }

  describe '.by_finding_id' do
    let(:finding_1) { create(:vulnerabilities_finding) }
    let!(:remediation) { create(:vulnerabilities_remediation, findings: [finding_1]) }

    subject { described_class.by_finding_id(finding_1.id) }

    it { is_expected.to eq(remediation.finding_remediations) }
  end

  context 'with loose foreign key on vulnerability_findings_remediations.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:finding_1) { create(:vulnerabilities_finding, project_id: parent.id) }
      let_it_be(:remediation) { create(:vulnerabilities_remediation, findings: [finding_1], project_id: parent.id) }
      let_it_be(:model) { finding_1.finding_remediations.first }
    end
  end
end

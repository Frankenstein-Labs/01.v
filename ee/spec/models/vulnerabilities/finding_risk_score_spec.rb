# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingRiskScore, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required(true) }
    it { is_expected.to belong_to(:finding).required(true) }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:risk_score).is_greater_than_or_equal_to(0.0) }
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, project: project) }
    let_it_be(:another_finding) { create(:vulnerabilities_finding, project: project) }
    let_it_be(:finding_risk_score) { create(:vulnerability_finding_risk_score, project: project, finding: finding) }
    let_it_be(:another_finding_risk_score) do
      create(:vulnerability_finding_risk_score, project: project, finding: another_finding)
    end

    describe '.for_finding' do
      it 'returns refs for the specified finding' do
        expect(described_class.for_finding(finding.id)).to contain_exactly(finding_risk_score)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Finding::Evidence, feature_category: :vulnerability_management do
  it { is_expected.to validate_presence_of(:data) }
  it { is_expected.to validate_length_of(:data).is_at_most(16_000_000) }
  it { is_expected.to belong_to(:finding).required }

  context 'with loose foreign key on vulnerability_finding_evidences.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilties_finding_evidence, project_id: parent.id) }
    end
  end

  describe '.by_finding_id' do
    let!(:finding) { create(:vulnerabilities_finding) }
    let!(:evidence) { create(:vulnerabilties_finding_evidence, finding: finding) }
    let!(:another_evidence) { create(:vulnerabilties_finding_evidence) }

    subject { described_class.by_finding_id(finding.id) }

    it { is_expected.to contain_exactly(evidence) }
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::PipelineSecurityReportFindingsResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:pipeline) { create(:ci_pipeline, :success, project: project) }

  describe '#resolve' do
    subject(:resolve_query) { resolve(described_class, obj: pipeline, args: params) }

    let_it_be(:low_security_finding) { build(:security_finding, :with_finding_data, severity: :low) }
    let_it_be(:critical_security_finding) { build(:security_finding, :with_finding_data, severity: :critical) }
    let_it_be(:high_security_finding) { build(:security_finding, :with_finding_data, severity: :high) }

    let(:params) { {} }

    let(:mock_finder) { instance_double(::Security::FindingsFinder, execute: returned_findings) }

    before do
      allow(::Security::FindingsFinder).to receive(:new).and_return(mock_finder)
    end

    context 'when given severities' do
      let(:params) { { severity: ['low'] } }
      let(:returned_findings) { [low_security_finding] }

      it 'returns security findings of the given severities' do
        is_expected.to contain_exactly(low_security_finding)
      end
    end

    context 'when given scanner' do
      let(:params) { { scanner: [high_security_finding.scanner.external_id] } }
      let(:returned_findings) { [high_security_finding] }

      it 'returns security findings of the given scanner' do
        is_expected.to contain_exactly(high_security_finding)
      end
    end

    context 'when given report types' do
      let(:params) { { report_type: %i[dast sast] } }
      let(:returned_findings) { [critical_security_finding, low_security_finding] }

      it 'returns vulnerabilities of the given report types' do
        is_expected.to contain_exactly(critical_security_finding, low_security_finding)
      end
    end

    context 'when given states' do
      let(:params) { { sort: 'severity_desc', state: %w[detected confirmed] } }
      let(:returned_findings) { [critical_security_finding, high_security_finding, low_security_finding] }

      it 'returns findings with descending severity' do
        is_expected.to eq(returned_findings)
      end
    end

    context 'when given sorting order' do
      context 'when direction is descending' do
        let(:params) { { sort: 'severity_desc' } }
        let(:returned_findings) { [critical_security_finding, high_security_finding, low_security_finding] }

        it 'returns findings with descending severity' do
          is_expected.to eq(returned_findings)
        end
      end

      context 'when direction is ascending' do
        let(:params) { { sort: 'severity_asc' } }
        let(:returned_findings) { [low_security_finding, high_security_finding, critical_security_finding] }

        it 'returns findings with descending severity' do
          is_expected.to eq(returned_findings)
        end
      end
    end
  end
end

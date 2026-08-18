# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  let(:base_vulnerability) { build(:security_finding) }
  let(:base_report) { build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability]) }

  let(:head_vulnerability) do
    build(:security_finding, uuid: base_vulnerability.uuid)
  end

  let(:head_report) { build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability]) }
  let(:base_params) { { base_report:, head_report: } }
  let(:params) { base_params }

  before do
    stub_feature_flags(security_mr_reports_tab_full_data_set: false)
  end

  subject(:report_comparer) { described_class.new(project, params) }

  describe '#base_report_out_of_date' do
    context 'with base pipeline older than one week' do
      let(:pipeline) { build(:ci_pipeline, created_at: 1.week.ago - 60.seconds) }
      let(:base_report) { build(:ci_reports_security_aggregated_findings, pipeline: pipeline) }

      it 'is out of date' do
        expect(report_comparer.base_report_out_of_date).to be true
      end
    end

    context 'with base pipeline less than one week old' do
      let(:pipeline) { build(:ci_pipeline, created_at: 1.week.ago + 60.seconds) }
      let(:base_report) { build(:ci_reports_security_aggregated_findings, pipeline: pipeline) }

      it 'is not out of date' do
        expect(report_comparer.base_report_out_of_date).to be false
      end
    end
  end

  describe '#added' do
    let(:new_vuln) { build(:security_finding) }
    let(:low_vuln) { build(:security_finding, severity: Enums::Vulnerability.severity_levels[:low]) }

    context 'with new vulnerability' do
      let!(:head_report) do
        build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability, new_vuln])
      end

      it 'returns the new vulnerability' do
        expect(report_comparer.added).to match_array([new_vuln])
      end
    end

    context 'with a dismissed Vulnerability on the default branch' do
      let_it_be(:dismissed_vulnerability) { create(:vulnerability, :dismissed, :with_finding) }
      let(:dismissed_on_default_branch) do
        build(
          :security_finding,
          uuid: dismissed_vulnerability.finding.uuid
        )
      end

      let(:head_report) do
        build(:ci_reports_security_aggregated_findings,
          findings: [dismissed_on_default_branch, new_vuln, head_vulnerability])
      end

      it 'doesnt report the dismissed Vulnerability' do
        expect(report_comparer.added).not_to include(dismissed_on_default_branch)
        expect(report_comparer.added).to contain_exactly(new_vuln)
      end
    end

    describe 'number of findings' do
      let(:head_report) do
        build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability, new_vuln, low_vuln])
      end

      before do
        stub_const("#{described_class}::MAX_FINDINGS_COUNT", 1)
      end

      it 'returns no more than `MAX_FINDINGS_COUNT`' do
        expect(report_comparer.added).to eq([new_vuln])
      end
    end

    describe 'metric tracking' do
      let(:head_report) do
        build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability, new_vuln, low_vuln])
      end

      it 'measures the execution time of the uuid gathering query' do
        expect(Gitlab::Metrics).to receive(:measure)
                                    .with(described_class::VULNERABILITY_FILTER_METRIC_KEY)
                                    .and_call_original

        report_comparer.added
      end
    end
  end

  describe '#fixed' do
    let(:new_vuln) { build(:security_finding) }
    let(:low_vuln) { build(:security_finding, severity: Enums::Vulnerability.severity_levels[:low]) }

    context 'with fixed vulnerability' do
      let!(:base_report) do
        build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability, new_vuln])
      end

      it 'returns the fixed vulnerability' do
        expect(report_comparer.fixed).to match_array([new_vuln])
      end

      context 'when scan mode is partial' do
        let(:params) { base_params.merge(scan_mode: 'partial') }

        it 'does not return fixed findings' do
          expect(report_comparer.fixed).to be_empty
        end
      end
    end

    context 'with a dismissed Vulnerability on the default branch' do
      let_it_be(:dismissed_vulnerability) { create(:vulnerability, :dismissed, :with_finding) }
      let(:dismissed_on_default_branch) do
        build(
          :security_finding,
          uuid: dismissed_vulnerability.finding.uuid
        )
      end

      let(:base_report) do
        build(:ci_reports_security_aggregated_findings,
          findings: [dismissed_on_default_branch, new_vuln, base_vulnerability])
      end

      it 'doesnt report the dismissed Vulnerability' do
        expect(report_comparer.fixed).not_to include(dismissed_on_default_branch)
        expect(report_comparer.fixed).to contain_exactly(new_vuln)
      end
    end

    describe 'number of findings' do
      let(:base_report) do
        build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability, new_vuln, low_vuln])
      end

      before do
        stub_const("#{described_class}::MAX_FINDINGS_COUNT", 1)
      end

      it 'returns no more than `MAX_FINDINGS_COUNT`' do
        expect(report_comparer.fixed).to eq([new_vuln])
      end
    end

    describe 'metric tracking' do
      let(:base_report) do
        build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability, new_vuln, low_vuln])
      end

      it 'measures the execution time of the uuid gathering query' do
        expect(Gitlab::Metrics).to receive(:measure)
                                    .with(described_class::VULNERABILITY_FILTER_METRIC_KEY)
                                    .and_call_original

        report_comparer.fixed
      end
    end
  end

  describe 'with security_mr_reports_tab_full_data_set feature flag enabled' do
    let(:new_vuln) { build(:security_finding) }
    let(:low_vuln) { build(:security_finding, severity: Enums::Vulnerability.severity_levels[:low]) }

    before do
      stub_feature_flags(security_mr_reports_tab_full_data_set: project)
      stub_const("#{described_class}::MAX_FINDINGS_COUNT", 1)
    end

    context 'when there are more added findings than the legacy MAX_FINDINGS_COUNT cap' do
      let(:head_report) do
        build(:ci_reports_security_aggregated_findings, findings: [head_vulnerability, new_vuln, low_vuln])
      end

      it 'returns every undismissed added finding' do
        expect(report_comparer.added).to contain_exactly(new_vuln, low_vuln)
      end
    end

    context 'when there are more fixed findings than the legacy MAX_FINDINGS_COUNT cap' do
      let(:base_report) do
        build(:ci_reports_security_aggregated_findings, findings: [base_vulnerability, new_vuln, low_vuln])
      end

      it 'returns every undismissed fixed finding' do
        expect(report_comparer.fixed).to contain_exactly(new_vuln, low_vuln)
      end
    end
  end

  describe 'with empty vulnerabilities' do
    let(:empty_report) { build(:ci_reports_security_aggregated_findings, findings: []) }

    it 'returns empty array when reports are not present' do
      comparer = described_class.new(project, base_report: empty_report, head_report: empty_report)

      expect(comparer.fixed).to eq([])
      expect(comparer.added).to eq([])
    end

    it 'returns added vulnerability when base is empty and head is not empty' do
      comparer = described_class.new(project, base_report: empty_report, head_report: head_report)

      expect(comparer.fixed).to eq([])
      expect(comparer.added).to eq([head_vulnerability])
    end

    it 'returns fixed vulnerability when head is empty and base is not empty' do
      comparer = described_class.new(project, base_report: base_report, head_report: empty_report)

      expect(comparer.fixed).to eq([base_vulnerability])
      expect(comparer.added).to eq([])
    end
  end

  describe 'partial scan scanner filtering' do
    let(:semgrep_scanner) { build(:ci_reports_security_scanner, external_id: 'semgrep') }
    let(:glas_scanner) { build(:ci_reports_security_scanner, external_id: 'glas') }
    let(:bandit_scanner) { build(:ci_reports_security_scanner, external_id: 'bandit') }

    let(:semgrep_finding) { build(:ci_reports_security_finding, scanner: semgrep_scanner) }
    let(:glas_finding) { build(:ci_reports_security_finding, scanner: glas_scanner) }
    let(:bandit_finding) { build(:ci_reports_security_finding, scanner: bandit_scanner) }

    let(:base_report) do
      build(:ci_reports_security_aggregated_findings, findings: [semgrep_finding, glas_finding, bandit_finding])
    end

    let(:head_report) { build(:ci_reports_security_aggregated_findings, findings: []) }

    context 'when scan_mode is full and partial_scan_scanner_ids are provided' do
      let(:params) do
        base_params.merge(
          scan_mode: 'full',
          partial_scan_scanner_ids: Set.new(%w[glas])
        )
      end

      it 'filters out base findings from partial scan scanners' do
        expect(report_comparer.fixed).to contain_exactly(semgrep_finding, bandit_finding)
      end

      it 'does not affect added findings' do
        head_report_with_new_finding = build(:ci_reports_security_aggregated_findings,
          findings: [build(:ci_reports_security_finding)])
        params_with_head = params.merge(head_report: head_report_with_new_finding)
        comparer = described_class.new(project, params_with_head)

        expect(comparer.added.size).to eq(1)
      end
    end

    context 'when scan_mode is not full' do
      let(:params) do
        base_params.merge(
          scan_mode: 'partial',
          partial_scan_scanner_ids: Set.new(%w[glas])
        )
      end

      it 'does not filter base findings' do
        expect(report_comparer.fixed).to be_empty
      end
    end

    context 'when partial_scan_scanner_ids is empty' do
      let(:params) do
        base_params.merge(
          scan_mode: 'full',
          partial_scan_scanner_ids: Set.new
        )
      end

      it 'does not filter any base findings' do
        expect(report_comparer.fixed).to contain_exactly(semgrep_finding, glas_finding, bandit_finding)
      end
    end

    context 'when partial_scan_scanner_ids is not provided' do
      let(:params) { base_params.merge(scan_mode: 'full') }

      it 'does not filter any base findings' do
        expect(report_comparer.fixed).to contain_exactly(semgrep_finding, glas_finding, bandit_finding)
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::FindingsFinder, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, project: project) }

  let_it_be(:dependency_scan) do
    create(:security_scan, :latest_successful, project: project, pipeline: pipeline, scan_type: 'dependency_scanning')
  end

  let_it_be_with_reload(:container_scan) do
    create(:security_scan, :latest_successful, project: project, pipeline: pipeline, scan_type: 'container_scanning')
  end

  let_it_be(:high_severity_finding) do
    create(:security_finding, :with_finding_data, scan: dependency_scan, severity: 'high')
  end

  let_it_be(:container_scanning_finding) { create(:security_finding, :with_finding_data, scan: container_scan) }
  let_it_be(:dismissed_finding) { create(:security_finding, :with_finding_data, scan: dependency_scan) }
  let_it_be(:false_positive_finding) do
    create(:security_finding, :with_finding_data, false_positive: true, scan: dependency_scan)
  end

  let_it_be(:non_false_positive_finding) do
    create(:security_finding, :with_finding_data, false_positive: false, scan: dependency_scan)
  end

  let_it_be(:no_fix_available_finding) do
    create(:security_finding, :with_finding_data, solution: '', remediation_byte_offsets: [], scan: dependency_scan)
  end

  before do
    create(:vulnerabilities_finding, :dismissed, project: project, uuid: dismissed_finding.uuid)

    create(:vulnerability_feedback, :dismissal,
      project: project,
      category: dependency_scan.scan_type,
      finding_uuid: dismissed_finding.uuid
    )
  end

  describe '#execute' do
    subject(:security_findings) { described_class.new(project, pipeline, params).execute }

    let(:all_findings) { pipeline.security_findings.reload }

    context 'with severity_levels' do
      let(:params) { { severity_levels: ['high'] } }

      it { is_expected.to contain_exactly(high_severity_finding) }

      context 'when it is an empty array' do
        let(:params) { { severity_levels: [] } }

        it { is_expected.to match_array(all_findings) }
      end
    end

    context 'with scanners' do
      let(:params) { { scanners: ['container_scanning'] } }

      it { is_expected.to contain_exactly(container_scanning_finding) }
    end

    context 'with dismissed filter' do
      context 'when dismissed is false' do
        let(:params) { { dismissed: false } }

        it { is_expected.to match_array(all_findings - [dismissed_finding]) }
      end

      context 'when dismissed is true' do
        let(:params) { { dismissed: true } }

        it { is_expected.to contain_exactly(dismissed_finding) }
      end

      context 'when dismissed is nil' do
        let(:params) { { dismissed: nil } }

        it { is_expected.to match_array(all_findings) }
      end
    end

    context 'with false_positives true' do
      let(:params) { { false_positive: true } }

      it { is_expected.to contain_exactly(false_positive_finding) }
    end

    context 'with false_positives false' do
      let(:params) { { false_positive: false } }

      it { is_expected.to match_array(all_findings - [false_positive_finding]) }
    end

    context 'with malicious' do
      let_it_be(:malicious_dependency_finding) do
        create(:security_finding, :with_finding_data, scan: dependency_scan, severity: 'low',
          identifiers: [create(:ci_reports_security_identifier, external_id: 'GLAM-2024-1234').to_hash])
      end

      let_it_be(:malicious_container_finding) do
        create(:security_finding, :with_finding_data, scan: container_scan, severity: 'low',
          identifiers: [create(:ci_reports_security_identifier, external_id: 'MAL-2024-5678').to_hash])
      end

      let(:params) { { malicious: true } }

      it 'returns only malicious findings across scanners' do
        is_expected.to contain_exactly(malicious_dependency_finding, malicious_container_finding)
      end

      context 'when combined with other filters' do
        let(:params) { { malicious: true, severity_levels: ['high'] } }

        it 'composes with the other filters instead of superseding them' do
          is_expected.to be_empty
        end
      end

      context 'when scanners are given' do
        let(:params) { { malicious: true, scanners: ['container_scanning'] } }

        it 'restricts malicious findings to the requested scanners' do
          is_expected.to contain_exactly(malicious_container_finding)
        end
      end
    end

    context 'with fix_available true' do
      let(:params) { { fix_available: true } }

      it do
        is_expected.to contain_exactly(
          high_severity_finding,
          container_scanning_finding,
          dismissed_finding,
          false_positive_finding,
          non_false_positive_finding
        )
      end
    end

    context 'with fix_available false' do
      let(:params) { { fix_available: false } }

      it { is_expected.to contain_exactly(no_fix_available_finding) }
    end

    context 'when pipeline is empty' do
      let_it_be(:pipeline) { nil }
      let(:params) { {} }

      it { is_expected.to be_empty }
    end

    context 'with related_pipeline_ids' do
      let_it_be(:pipeline_without_scans) { create(:ee_ci_pipeline, :success, project: project) }
      let_it_be(:pipeline_with_scans) { create(:ee_ci_pipeline, :success, project: project) }

      let_it_be(:findings) do
        create_list(:security_finding, 5,
          :with_finding_data,
          scan: create(:security_scan, :latest_successful, project: project, pipeline: pipeline_with_scans)
        )
      end

      let(:params) { { related_pipeline_ids: [pipeline_with_scans.id, pipeline_without_scans.id] } }

      it { is_expected.to match_array(findings) }

      context 'when pipeline is empty' do
        let_it_be(:pipeline) { nil }
        let(:params) { { related_pipeline_ids: [pipeline_with_scans.id, pipeline_without_scans.id] } }

        it { is_expected.to be_empty }
      end
    end

    context 'with uuids' do
      let(:params) { { uuids: [dismissed_finding.uuid, container_scanning_finding.uuid] } }

      it { is_expected.to contain_exactly(dismissed_finding, container_scanning_finding) }

      context 'when it is an empty array' do
        let(:params) { { uuids: [] } }

        it { is_expected.to match_array(all_findings) }
      end
    end

    context 'with CVE enrichment filters' do
      let_it_be(:pm_cve_enrichment) { create(:pm_cve_enrichment) }

      let_it_be(:finding_with_enrichment) do
        create(:security_finding, :with_finding_data, scan: dependency_scan).tap do |finding|
          create(:security_finding_enrichment, finding_uuid: finding.uuid,
            cve_enrichment_id: pm_cve_enrichment.id, is_known_exploit: true, epss_score: 0.8)
        end
      end

      let_it_be(:finding_with_enrichment_no_exploit) do
        create(:security_finding, :with_finding_data, scan: dependency_scan).tap do |finding|
          create(:security_finding_enrichment, finding_uuid: finding.uuid,
            cve_enrichment_id: pm_cve_enrichment.id, is_known_exploit: false, epss_score: 0.3)
        end
      end

      let_it_be(:finding_without_enrichment) do
        create(:security_finding, :with_finding_data, scan: dependency_scan)
      end

      let_it_be(:finding_with_unenriched_cve) do
        create(:security_finding, :with_finding_data, scan: dependency_scan).tap do |finding|
          create(:security_finding_enrichment, finding_uuid: finding.uuid, cve_enrichment_id: nil)
        end
      end

      let(:all_records) { all_findings }
      let(:model_class) { Security::Finding }
      let(:params) { filter_params }

      it_behaves_like 'CVE enrichment filters finder spec'
    end

    context 'with multiple security_scans for a report_type' do
      let(:params) { { scanners: ['container_scanning'] } }

      before do
        container_scan.update!(latest: false)
      end

      context 'when latest scan is not successful' do
        let_it_be(:failed_container_scan) do
          create(:security_scan, status: :job_failed, latest: true,
            project: project,
            pipeline: pipeline,
            scan_type: 'container_scanning'
          )
        end

        it { is_expected.to be_empty }
      end

      context 'when latest successful scan has no security_findings' do
        let_it_be(:latest_successful_scan) do
          create(:security_scan, :latest_successful,
            project: project,
            pipeline: pipeline,
            scan_type: 'container_scanning'
          )
        end

        it { is_expected.to be_empty }
      end

      context 'when latest successful scan has security_findings' do
        let_it_be(:latest_successful_scan) do
          create(:security_scan,
            :latest_successful,
            project: project,
            pipeline: pipeline,
            scan_type: 'container_scanning'
          )
        end

        let_it_be(:finding) do
          create(:security_finding, :with_finding_data, scan: latest_successful_scan)
        end

        it { is_expected.to contain_exactly(finding) }

        it { is_expected.not_to include(container_scanning_finding) }
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::VulnerabilitiesFinder, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let_it_be(:vulnerability1) do
    create(:vulnerability, :with_finding, :with_issue_links,
      severity: :low,
      report_type: :sast,
      state: :detected,
      project: project
    )
  end

  let_it_be(:vulnerability2) do
    create(:vulnerability, :with_finding,
      resolved_on_default_branch: true,
      severity: :high,
      report_type: :dependency_scanning,
      state: :confirmed,
      project: project
    )
  end

  let_it_be(:vulnerability3) do
    create(:vulnerability, :with_finding, severity: :medium, report_type: :dast, state: :dismissed, project: project)
  end

  let(:filters) { {} }

  let(:all_vulnerabilities) { project.vulnerabilities.reload }

  subject(:vulnerabilities) { described_class.new(project, filters).execute }

  it 'returns vulnerabilities of a project' do
    expect(vulnerabilities).to match_array(all_vulnerabilities)
    expect(vulnerabilities).to contain_exactly(vulnerability1, vulnerability2, vulnerability3)
  end

  context 'when filtered with limit' do
    let(:limit) { 1 }
    let(:filters) { { limit: limit } }

    it 'only returns vulnerabilities within limit' do
      expect(vulnerabilities.count).to eq(limit)
    end
  end

  context 'when filtered by report type' do
    let(:filters) { { report_type: %w[sast dast] } }

    it 'only returns vulnerabilities matching the given report types' do
      is_expected.to contain_exactly(vulnerability1, vulnerability3)
    end
  end

  context 'when filtered by severity' do
    let(:filters) { { severity: %w[medium high] } }

    it 'only returns vulnerabilities matching the given severities' do
      is_expected.to contain_exactly(vulnerability3, vulnerability2)
    end
  end

  context 'when filtered by state' do
    let(:filters) { { state: %w[detected confirmed] } }

    it 'only returns vulnerabilities matching the given states' do
      is_expected.to contain_exactly(vulnerability1, vulnerability2)
    end

    context 'when combined with other filters' do
      let(:filters) { { state: %w[dismissed], report_type: %w[dast] } }

      it 'respects the other filters' do
        is_expected.to contain_exactly(vulnerability3)
      end
    end
  end

  context 'when filtered by age' do
    let(:old_created_at) { 6.months.ago }
    let(:old_vulnerability) { create(:vulnerability, project: project, created_at: old_created_at) }
    let(:new_vulnerability) { create(:vulnerability, project: project, created_at: 3.days.ago) }

    shared_examples 'ignores old vulnerability' do
      it 'returns vulnerabilities except old vulnerability' do
        is_expected.to contain_exactly(new_vulnerability, vulnerability1, vulnerability2, vulnerability3)
      end
    end

    shared_examples 'returns all vulnerabilities' do
      it 'returns all vulnerabilities' do
        is_expected.to contain_exactly(
          new_vulnerability, old_vulnerability, vulnerability1, vulnerability2, vulnerability3
        )
      end
    end

    context 'when operator is greater_than' do
      let(:filters) { { vulnerability_age: { interval: :day, value: 30, operator: :greater_than } } }

      it 'returns vulnerabilities detected before the selected amount of days ago' do
        is_expected.to contain_exactly(old_vulnerability)
      end
    end

    context 'when operator is less_than' do
      let(:filters) { { vulnerability_age: { interval: :day, value: 30, operator: :less_than } } }

      it_behaves_like 'ignores old vulnerability'
    end

    context 'when interval is in weeks' do
      let(:old_created_at) { 2.weeks.ago }
      let(:filters) { { vulnerability_age: { interval: :week, value: 1, operator: :less_than } } }

      it_behaves_like 'ignores old vulnerability'
    end

    context 'when interval is in months' do
      let(:old_created_at) { 2.months.ago }
      let(:filters) { { vulnerability_age: { interval: :month, value: 1, operator: :less_than } } }

      it_behaves_like 'ignores old vulnerability'
    end

    context 'when interval is in years' do
      let(:old_created_at) { 2.years.ago }
      let(:filters) { { vulnerability_age: { interval: :year, value: 1, operator: :less_than } } }

      it_behaves_like 'ignores old vulnerability'
    end

    context 'with invalid values' do
      context 'when interval is invalid' do
        let(:filters) { { vulnerability_age: { interval: :invalid, value: 30, operator: :greater_than } } }

        it_behaves_like 'returns all vulnerabilities'
      end

      context 'when operator is invalid' do
        let(:filters) { { vulnerability_age: { interval: :day, value: 30, operator: :invalid } } }

        it_behaves_like 'returns all vulnerabilities'
      end

      context 'when age value is invalid' do
        let(:filters) { { vulnerability_age: { interval: :day, value: 'invalid', operator: :greater_than } } }

        it_behaves_like 'returns all vulnerabilities'
      end
    end
  end

  context 'when filtered by fix_available' do
    let_it_be(:vuln_with_fix) { create(:vulnerability, project: project) }
    let_it_be(:vuln_without_fix) { create(:vulnerability, project: project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, vulnerability: vuln_with_fix, solution: 'test fix') }
    let_it_be(:finding_without_fix) { create(:vulnerabilities_finding, solution: nil, vulnerability: vuln_without_fix) }

    context 'when fix_available is true' do
      let(:filters) { { fix_available: true } }

      it 'returns vulnerabilities with fix' do
        is_expected.to contain_exactly(vuln_with_fix)
      end
    end

    context 'when fix_available is false' do
      let(:filters) { { fix_available: false } }

      it 'returns vulnerabilities without fix' do
        is_expected.to contain_exactly(vuln_without_fix, vulnerability1, vulnerability2, vulnerability3)
      end
    end
  end

  context 'when filtered by false_positive' do
    let_it_be(:false_positive_vulnerability) { create(:vulnerability, project: project) }
    let_it_be(:non_false_positive_vulnerability) { create(:vulnerability, project: project) }

    let_it_be(:finding) do
      create(:vulnerabilities_finding,
        vulnerability_flags: [create(:vulnerabilities_flag)],
        vulnerability: false_positive_vulnerability
      )
    end

    let_it_be(:non_false_positive_finding) do
      create(:vulnerabilities_finding, vulnerability: non_false_positive_vulnerability)
    end

    context 'when false_positive is true' do
      let(:filters) { { false_positive: true } }

      it 'returns false_positive vulnerabilities' do
        is_expected.to contain_exactly(false_positive_vulnerability)
      end
    end

    context 'when false_positive is false' do
      let(:filters) { { false_positive: false } }

      it 'returns non-false-positive vulnerabilities' do
        is_expected.to contain_exactly(non_false_positive_vulnerability, vulnerability1, vulnerability2, vulnerability3)
      end
    end
  end

  context 'when filtered by uuids' do
    let(:filters) { { uuids: [vulnerability1.finding.uuid, vulnerability2.finding.uuid] } }

    it { is_expected.to contain_exactly(vulnerability1, vulnerability2) }
  end

  context 'when there are vulnerabilities on non default branches' do
    let_it_be(:vulnerability4) do
      create(:vulnerability, report_type: :dast, project: project, present_on_default_branch: false)
    end

    let(:filters) { { report_type: %w[dast] } }

    it 'only returns vulnerabilities on the default branch by default' do
      is_expected.to contain_exactly(vulnerability3)
    end
  end

  context 'when filtered by CVE enrichment attributes' do
    def create_finding_with_enrichment(
      project:, cve_identifier: nil, cve_enrichment: nil,
      is_known_exploit: nil, epss_score: nil, without_enrichment: false
    )
      security_finding = create(:security_finding)

      create(:vulnerability, project: project).tap do |vulnerability|
        create(:vulnerabilities_finding, vulnerability: vulnerability, uuid: security_finding.uuid,
          cve_identifiers: Array(cve_identifier).compact
        )

        unless without_enrichment
          create(
            :security_finding_enrichment, finding_uuid: security_finding.uuid, cve_enrichment_id: cve_enrichment&.id,
            is_known_exploit: is_known_exploit, epss_score: epss_score
          )
        end
      end
    end

    let_it_be(:cve_identifier) { create(:vulnerabilities_identifier, external_type: 'cve', name: 'CVE-2023-12345') }
    let_it_be(:pm_cve_enrichment) { create(:pm_cve_enrichment) }

    let_it_be(:finding_with_enrichment) do
      create_finding_with_enrichment(
        project: project, cve_identifier: cve_identifier,
        cve_enrichment: pm_cve_enrichment, is_known_exploit: true, epss_score: 0.8
      )
    end

    let_it_be(:finding_with_enrichment_no_exploit) do
      create_finding_with_enrichment(
        project: project, cve_identifier: cve_identifier,
        cve_enrichment: pm_cve_enrichment, is_known_exploit: false, epss_score: 0.3
      )
    end

    let_it_be(:finding_with_unenriched_cve) do
      create_finding_with_enrichment(project: project, cve_identifier: cve_identifier)
    end

    let_it_be(:finding_without_enrichment) do
      create_finding_with_enrichment(project: project, cve_identifier: cve_identifier, without_enrichment: true)
    end

    let(:all_records) { all_vulnerabilities }
    let(:model_class) { Vulnerabilities::Finding }
    let(:filters) { filter_params }

    it_behaves_like 'CVE enrichment filters finder spec'
  end
end

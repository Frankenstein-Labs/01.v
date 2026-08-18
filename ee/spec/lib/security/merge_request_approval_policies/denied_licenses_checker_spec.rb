# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::MergeRequestApprovalPolicies::DeniedLicensesChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
  let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
  let_it_be(:approval_policy_rule) { nil }
  let(:approval_policy_source) do
    Security::ApprovalPolicySource.new(
      project: project,
      action_idx: 0,
      scan_result_policy_read: scan_result_policy_read,
      approval_policy_rule: approval_policy_rule
    )
  end

  let(:service) do
    described_class.new(project, pipeline_report, target_branch_report, approval_policy_source)
  end

  subject(:denied_licenses_with_dependencies) { service.denied_licenses_with_dependencies }

  shared_examples_for 'tracks enforce_approval_policies_with_package_exceptions_in_project event' do
    # rubocop:disable Layout/LineLength -- easier to read in single line
    it 'tracks internal metrics with the right parameters', :clean_gitlab_redis_shared_state do
      expect do
        denied_licenses_with_dependencies
      end
        .to trigger_internal_events('enforce_approval_policies_with_package_exceptions_in_project')
          .with(project: project,
            additional_properties: { label: policy_state == :denied ? 'denylist' : 'allowlist' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_namespace_id_from_enforce_approval_policies_with_package_exceptions_in_project_monthly',
            'redis_hll_counters.count_distinct_namespace_id_from_enforce_approval_policies_with_package_exceptions_in_project_weekly',
            'redis_hll_counters.count_distinct_project_id_from_enforce_approval_policies_with_package_exceptions_in_project_monthly',
            'redis_hll_counters.count_distinct_project_id_from_enforce_approval_policies_with_package_exceptions_in_project_weekly',
            'counts.count_total_enforce_approval_policies_with_package_exceptions_in_project_monthly',
            'counts.count_total_enforce_approval_policies_with_package_exceptions_in_project_weekly',
            'counts.count_total_enforce_approval_policies_with_package_exceptions_in_project'
          )
    end
    # rubocop:enable Layout/LineLength
  end

  context 'without package exceptions' do
    include_context 'for denied_licenses_checker without package exceptions'

    with_them do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
      let(:license_states) { states }
      let(:licenses) { { policy_state.to_sym => [{ name: policy_license }] } }

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          license_states: license_states,
          licenses: licenses
        )
      end

      before do
        target_branch_licenses.each do |ld|
          target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end

        pipeline_branch_licenses.each do |ld|
          pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end

      it_behaves_like 'tracks enforce_approval_policies_with_package_exceptions_in_project event'
    end
  end

  context 'with package exceptions' do
    shared_examples_for 'with package exceptions' do
      include_context 'for denied_licenses_checker with package exceptions'

      with_them do
        let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
        let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }
        let(:license_states) { states }
        let(:licenses) do
          { policy_state.to_sym => [{ name: policy_license, packages: { excluding: { purls: excluded_packages } } }] }
        end

        let(:scan_result_policy_read) do
          create(:scan_result_policy_read,
            project: project,
            license_states: license_states,
            licenses: licenses
          )
        end

        let(:approval_policy_rule_content) do
          {
            type: 'license_finding',
            branches: [],
            license_states: license_states,
            licenses: licenses
          }
        end

        let(:approval_policy_rule) do
          create(:approval_policy_rule, :license_finding_with_allowed_licenses,
            content: approval_policy_rule_content)
        end

        before do
          target_branch_licenses.each do |ld|
            target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(purl_type: ld[2], name: ld[3],
              version: ld[4])
          end

          pipeline_branch_licenses.each do |ld|
            pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(purl_type: ld[2], name: ld[3],
              version: ld[4])
          end
        end

        it 'returns denied_licenses_with_dependencies' do
          is_expected.to eq(violated_licenses)
        end

        it_behaves_like 'tracks enforce_approval_policies_with_package_exceptions_in_project event'
      end
    end

    it_behaves_like 'with package exceptions'
  end

  context 'when approval_policy_source is nil' do
    let(:target_branch_report) { create(:ci_reports_license_scanning_report) }
    let(:pipeline_report) { create(:ci_reports_license_scanning_report) }

    let(:service) do
      described_class.new(project, pipeline_report, target_branch_report, nil)
    end

    it 'returns no denied licenses' do
      expect(denied_licenses_with_dependencies).to be_blank
    end

    context 'when policy_licenses is forced non-empty' do
      before do
        allow(service).to receive(:policy_licenses).and_return({ 'denied' => [{ 'name' => 'GPL v3' }] })
        pipeline_report.add_license(id: 'GPL-3.0', name: 'GPL v3').add_dependency(name: 'gpl_lib')
      end

      it 'computes denied licenses using empty license_states without raising' do
        expect { denied_licenses_with_dependencies }.not_to raise_error
      end
    end
  end

  context 'with a name-only license (no SPDX identifier)' do
    let(:custom_license) { 'Acme Internal License v2' }
    let(:target_branch_report) { create(:ci_reports_license_scanning_report) }
    let(:pipeline_report) { create(:ci_reports_license_scanning_report) }

    let(:scan_result_policy_read) do
      create(:scan_result_policy_read, project: project,
        license_states: %w[newly_detected detected], licenses: licenses)
    end

    before do
      # A license enriched in a CycloneDX SBOM with only `license.name` reaches the
      # report with no SPDX id (id: nil), matched purely by name.
      pipeline_report.add_license(id: nil, name: custom_license).add_dependency(name: 'acme_lib')
    end

    context 'with an allowlist' do
      context 'when the custom name is not in the allowlist' do
        let(:licenses) { { allowed: [{ name: 'MIT License' }] } }

        it 'reports the name-only license as a violation' do
          expect(denied_licenses_with_dependencies).to eq({ custom_license => ['acme_lib'] })
        end
      end

      context 'when the custom name is in the allowlist' do
        let(:licenses) { { allowed: [{ name: custom_license }] } }

        it 'does not report a violation' do
          expect(denied_licenses_with_dependencies).to be_blank
        end
      end
    end

    context 'with a denylist' do
      context 'when the custom name is in the denylist' do
        let(:licenses) { { denied: [{ name: custom_license }] } }

        it 'reports the name-only license as a violation' do
          expect(denied_licenses_with_dependencies).to eq({ custom_license => ['acme_lib'] })
        end
      end

      context 'when the custom name is not in the denylist' do
        let(:licenses) { { denied: [{ name: 'MIT License' }] } }

        it 'does not report a violation' do
          expect(denied_licenses_with_dependencies).to be_blank
        end
      end
    end
  end

  context 'when approval_policy_source resolves through approval_policy_rule' do
    let(:target_branch_report) { create(:ci_reports_license_scanning_report) }
    let(:pipeline_report) { create(:ci_reports_license_scanning_report) }

    let(:scan_result_policy_read) do
      create(:scan_result_policy_read, project: project,
        license_states: %w[detected], match_on_inclusion_license: true,
        licenses: { denied: [{ name: 'MIT' }] })
    end

    let(:approval_policy_rule) do
      create(:approval_policy_rule, :license_finding,
        content: {
          type: 'license_finding', branches: [],
          match_on_inclusion_license: true,
          license_states: %w[detected],
          licenses: { denied: [{ name: 'GPL v3' }] }
        })
    end

    before do
      target_branch_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'mit_lib')
      target_branch_report.add_license(id: 'GPL-3.0', name: 'GPL v3').add_dependency(name: 'gpl_lib')
      pipeline_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'mit_lib')
      pipeline_report.add_license(id: 'GPL-3.0', name: 'GPL v3').add_dependency(name: 'gpl_lib')
    end

    it 'denies licenses listed by approval_policy_rule content' do
      expect(denied_licenses_with_dependencies).to eq({ 'GPL v3' => ['gpl_lib'] })
    end

    context 'when the deprecate_scan_result_policies flag is disabled' do
      include_context 'with deprecate_scan_result_policies flag disabled'

      it 'denies licenses listed by scan_result_policy_read content' do
        expect(denied_licenses_with_dependencies).to eq({ 'MIT' => ['mit_lib'] })
      end
    end
  end

  context 'with license overrides' do
    let(:target_branch_report) { create(:ci_reports_license_scanning_report) }
    let(:scan_result_policy_read) do
      create(:scan_result_policy_read,
        project: project,
        license_states: license_states,
        licenses: licenses
      )
    end

    let(:approval_policy_rule) do
      rule_content = {
        type: 'license_finding',
        branches: [],
        license_states: license_states,
        licenses: licenses
      }
      rule_content[:license_overrides] = license_overrides if license_overrides.present?

      create(:approval_policy_rule, :license_finding_with_allowed_licenses, content: rule_content)
    end

    let(:pipeline_report) { create(:ci_reports_license_scanning_report) }

    let(:license_states) { %w[newly_detected] }
    let(:licenses) { { 'allowed' => [{ 'name' => 'MIT License' }] } }
    let(:license_overrides) { [] }

    before do
      allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
        .with(project).and_return(true)
    end

    context 'when patch mode overrides unknown license to an allowed license' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
      end

      it 'does not report a violation because overridden license is allowed' do
        is_expected.to be_nil
      end
    end

    context 'when patch mode overrides unknown license to a non-allowed license' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'GPL-3.0', 'mode' => 'patch' }]
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
      end

      it 'reports a violation because overridden license is not allowed' do
        is_expected.to eq({ 'GPL-3.0' => ['urllib3'] })
      end
    end

    context 'when patch mode does not apply to known licenses' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:gem/rails', 'license' => 'Apache-2.0', 'mode' => 'patch' }]
      end

      before do
        pipeline_report.add_license(id: 'GPL-3.0', name: 'GPL-3.0')
          .add_dependency(purl_type: 'gem', name: 'rails', version: '8.0.1')
      end

      it 'reports the original license violation (override not applied)' do
        is_expected.to eq({ 'GPL-3.0' => ['rails'] })
      end
    end

    context 'when overwrite mode applies regardless of detected license' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:gem/rails', 'license' => 'MIT License', 'mode' => 'overwrite' }]
      end

      before do
        pipeline_report.add_license(id: 'GPL-3.0', name: 'GPL-3.0')
          .add_dependency(purl_type: 'gem', name: 'rails', version: '8.0.1')
      end

      it 'does not report a violation because overwritten license is allowed' do
        is_expected.to be_nil
      end
    end

    context 'when purl prefix matches versioned dependency' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '1.26.18')
      end

      it 'matches version-less override purl against versioned dependency purl' do
        is_expected.to be_nil
      end
    end

    context 'when versioned override purl matches a dependency with a different version' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3@2.0.0', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '1.26.18')
      end

      it 'does not apply the override because override version does not match dependency version' do
        is_expected.to eq({ 'unknown' => ['urllib3'] })
      end
    end

    context 'with multiple overrides for different packages' do
      let(:license_overrides) do
        [
          { 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' },
          { 'purl' => 'pkg:pypi/requests', 'license' => 'Apache-2.0', 'mode' => 'patch' }
        ]
      end

      before do
        unknown = pipeline_report.add_license(id: nil, name: 'unknown')
        unknown.add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
        unknown.add_dependency(purl_type: 'pypi', name: 'requests', version: '2.31.0')
      end

      it 'overrides both: MIT allowed, Apache License 2.0 not allowed' do
        is_expected.to eq({ 'Apache License 2.0' => ['requests'] })
      end
    end

    context 'with mixed overridden and non-overridden unknown deps' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      before do
        unknown = pipeline_report.add_license(id: nil, name: 'unknown')
        unknown.add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
        unknown.add_dependency(purl_type: 'pypi', name: 'proprietary-lib', version: '1.0.0')
      end

      it 'overrides urllib3 to MIT (allowed) but proprietary-lib remains unknown (violation)' do
        is_expected.to eq({ 'unknown' => ['proprietary-lib'] })
      end
    end

    context 'when no overrides are configured' do
      let(:license_overrides) { [] }

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
      end

      it 'reports the unknown license violation as normal' do
        is_expected.to eq({ 'unknown' => ['urllib3'] })
      end
    end

    context 'when experiment is not enabled' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
          .with(project).and_return(false)
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
      end

      it 'ignores overrides and reports the unknown license violation' do
        is_expected.to eq({ 'unknown' => ['urllib3'] })
      end
    end

    context 'when mode defaults to patch when not specified' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License' }]
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
      end

      it 'applies patch mode by default and resolves the violation' do
        is_expected.to be_nil
      end
    end

    context 'with denied list: override maps unknown to a denied license' do
      let(:licenses) { { 'denied' => [{ 'name' => 'GPL-3.0' }] } }
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'GPL-3.0', 'mode' => 'patch' }]
      end

      let(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding_with_denied_licenses,
          content: {
            type: 'license_finding',
            branches: [],
            license_states: license_states,
            licenses: licenses,
            license_overrides: license_overrides
          })
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
      end

      it 'reports a violation because overridden license matches the denied list' do
        is_expected.to eq({ 'GPL-3.0' => ['urllib3'] })
      end
    end

    context 'with denied list: override maps unknown to a non-denied license' do
      let(:licenses) { { 'denied' => [{ 'name' => 'GPL-3.0' }] } }
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      let(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding_with_denied_licenses,
          content: {
            type: 'license_finding',
            branches: [],
            license_states: license_states,
            licenses: licenses,
            license_overrides: license_overrides
          })
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(purl_type: 'pypi', name: 'urllib3', version: '2.0.0')
      end

      it 'does not report a violation because overridden license is not denied' do
        is_expected.to be_nil
      end
    end

    context 'when dependency has no purl (purl_type is nil)' do
      let(:license_overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      before do
        pipeline_report.add_license(id: nil, name: 'unknown')
          .add_dependency(name: 'some-lib', version: '1.0.0')
      end

      it 'skips override for dependencies without purl and reports the violation' do
        is_expected.to eq({ 'unknown' => ['some-lib'] })
      end
    end
  end
end

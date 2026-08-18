# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::MergeRequestApprovalPolicies::LicenseExpressionChecker,
  feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
  let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

  let(:approval_policy_rule) { nil }

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
            additional_properties: { label: policy_state.to_sym == :denied ? 'denylist' : 'allowlist' })
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
      let(:target_branch_report) { build(:ci_reports_license_scanning_report) }
      let(:pipeline_report) { build(:ci_reports_license_scanning_report) }

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
        target_branch_licenses.each do |spdx_id, display_name, dependency_name|
          target_branch_report.add_license(id: spdx_id, name: display_name).add_dependency(name: dependency_name)
        end

        pipeline_branch_licenses.each do |spdx_id, display_name, dependency_name|
          pipeline_report.add_license(id: spdx_id, name: display_name).add_dependency(name: dependency_name)
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end

      it_behaves_like 'tracks enforce_approval_policies_with_package_exceptions_in_project event'
    end
  end

  shared_examples 'with license operator expressions' do |operator, policy_type: :denied|
    context_prefix = policy_type == :allowed ? 'allowlist ' : ''
    include_context "for license_expression_checker #{context_prefix}#{operator} operator"

    with_them do
      let(:target_branch_report) { build(:ci_reports_license_scanning_report) }
      let(:pipeline_report) { build(:ci_reports_license_scanning_report) }

      let(:license_states) { states }
      let(:licenses) do
        names = policy_type == :allowed ? policy_allowed_names : policy_denied_names
        { policy_type => names.map { |name| { name: name } } }
      end

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          license_states: license_states,
          licenses: licenses
        )
      end

      before do
        target_branch_licenses.each do |spdx_id, display_name, dependency_name|
          target_branch_report.add_license(id: spdx_id, name: display_name).add_dependency(name: dependency_name)
        end

        pipeline_branch_licenses.each do |spdx_id, display_name, dependency_name|
          pipeline_report.add_license(id: spdx_id, name: display_name).add_dependency(name: dependency_name)
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end
    end
  end

  shared_examples 'with license operator expressions and package exceptions' do |operator|
    include_context "for license_expression_checker #{operator} operator with package exceptions"

    with_them do
      let(:target_branch_report) { build(:ci_reports_license_scanning_report) }
      let(:pipeline_report) { build(:ci_reports_license_scanning_report) }

      let(:license_states) { states }
      let(:licenses) do
        entries = policy_names.map do |name|
          purls = excluded_packages[name]
          purls.present? ? { name: name, packages: { excluding: { purls: purls } } } : { name: name }
        end
        { policy_state => entries }
      end

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          license_states: license_states,
          licenses: licenses
        )
      end

      before do
        target_branch_licenses.each do |spdx_id, display_name, purl_type, dependency_name, version|
          target_branch_report.add_license(id: spdx_id, name: display_name)
            .add_dependency(purl_type: purl_type, name: dependency_name, version: version)
        end

        pipeline_branch_licenses.each do |spdx_id, display_name, purl_type, dependency_name, version|
          pipeline_report.add_license(id: spdx_id, name: display_name)
            .add_dependency(purl_type: purl_type, name: dependency_name, version: version)
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end

      it_behaves_like 'tracks enforce_approval_policies_with_package_exceptions_in_project event'
    end
  end

  context 'with denylist operator expressions' do
    context 'with AND operator expressions' do
      it_behaves_like 'with license operator expressions', 'AND'
    end

    context 'with OR operator expressions' do
      it_behaves_like 'with license operator expressions', 'OR'
    end

    context 'with WITH operator expressions' do
      it_behaves_like 'with license operator expressions', 'WITH'
    end

    context 'with PLUS operator expressions' do
      it_behaves_like 'with license operator expressions', 'PLUS'
    end

    context 'with LicenseRef expressions' do
      it_behaves_like 'with license operator expressions', 'LicenseRef'
    end
  end

  context 'with allowlist operator expressions' do
    context 'with AND operator expressions' do
      it_behaves_like 'with license operator expressions', 'AND', policy_type: :allowed
    end

    context 'with OR operator expressions' do
      it_behaves_like 'with license operator expressions', 'OR', policy_type: :allowed
    end

    context 'with WITH operator expressions' do
      it_behaves_like 'with license operator expressions', 'WITH', policy_type: :allowed
    end

    context 'with PLUS operator expressions' do
      it_behaves_like 'with license operator expressions', 'PLUS', policy_type: :allowed
    end

    context 'with LicenseRef expressions' do
      it_behaves_like 'with license operator expressions', 'LicenseRef', policy_type: :allowed
    end
  end

  context 'with package exceptions for license expressions' do
    context 'with AND operator expressions' do
      it_behaves_like 'with license operator expressions and package exceptions', 'AND'
    end

    context 'with OR operator expressions' do
      it_behaves_like 'with license operator expressions and package exceptions', 'OR'
    end

    context 'with WITH operator expressions' do
      it_behaves_like 'with license operator expressions and package exceptions', 'WITH'
    end

    context 'with PLUS operator expressions' do
      it_behaves_like 'with license operator expressions and package exceptions', 'PLUS'
    end

    context 'with LicenseRef expressions' do
      it_behaves_like 'with license operator expressions and package exceptions', 'LicenseRef'
    end
  end

  context 'with package exceptions for licenses' do
    include_context 'for denied_licenses_checker with package exceptions'

    with_them do
      let(:target_branch_report) { build(:ci_reports_license_scanning_report) }
      let(:pipeline_report) { build(:ci_reports_license_scanning_report) }
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

      before do
        target_branch_licenses.each do |spdx_id, display_name, purl_type, dependency_name, version|
          target_branch_report.add_license(id: spdx_id, name: display_name)
            .add_dependency(purl_type: purl_type, name: dependency_name, version: version)
        end

        pipeline_branch_licenses.each do |spdx_id, display_name, purl_type, dependency_name, version|
          pipeline_report.add_license(id: spdx_id, name: display_name)
            .add_dependency(purl_type: purl_type, name: dependency_name, version: version)
        end
      end

      it 'returns denied_licenses_with_dependencies' do
        is_expected.to eq(violated_licenses)
      end

      it_behaves_like 'tracks enforce_approval_policies_with_package_exceptions_in_project event'
    end
  end

  describe 'license-expression event tracking' do
    let(:pipeline_report) { build(:ci_reports_license_scanning_report) }
    let(:target_branch_report) { build(:ci_reports_license_scanning_report) }

    let(:scan_result_policy_read) do
      create(:scan_result_policy_read,
        project: project,
        license_states: ['detected'],
        licenses: policy_licenses
      )
    end

    before do
      report_license_names.each do |name|
        target_branch_report.add_license(id: name, name: name).add_dependency(name: 'dependency_1')
      end
    end

    shared_examples 'fires the license-expression event' do |label:|
      # rubocop:disable Layout/LineLength -- easier to read in single line
      it 'fires the package-exception and license-expression events with the right label',
        :clean_gitlab_redis_shared_state, :aggregate_failures do
        expect { denied_licenses_with_dependencies }
          .to trigger_internal_events(
            'enforce_approval_policies_with_package_exceptions_in_project',
            'enforce_approval_policies_with_license_expressions_in_project'
          ).with(project: project, additional_properties: { label: label })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_namespace_id_from_enforce_approval_policies_with_license_expressions_in_project_monthly',
            'redis_hll_counters.count_distinct_namespace_id_from_enforce_approval_policies_with_license_expressions_in_project_weekly',
            'redis_hll_counters.count_distinct_project_id_from_enforce_approval_policies_with_license_expressions_in_project_monthly',
            'redis_hll_counters.count_distinct_project_id_from_enforce_approval_policies_with_license_expressions_in_project_weekly',
            'counts.count_total_enforce_approval_policies_with_license_expressions_in_project_monthly',
            'counts.count_total_enforce_approval_policies_with_license_expressions_in_project_weekly',
            'counts.count_total_enforce_approval_policies_with_license_expressions_in_project'
          )
      end
      # rubocop:enable Layout/LineLength
    end

    context 'with a denylist policy' do
      let(:policy_licenses) { { denied: [{ name: 'MIT License' }] } }

      context 'when the report contains a compound SPDX expression' do
        let(:report_license_names) { ['MIT AND Apache-2.0'] }

        it_behaves_like 'fires the license-expression event', label: 'denylist'
      end

      context 'when the report contains a standalone LicenseRef identifier' do
        let(:report_license_names) { ['LicenseRef-custom'] }

        it_behaves_like 'fires the license-expression event', label: 'denylist'
      end

      context 'when the report contains a DocumentRef identifier' do
        let(:report_license_names) { ['DocumentRef-spdxdoc:LicenseRef-custom'] }

        it_behaves_like 'fires the license-expression event', label: 'denylist'
      end

      context 'when the report contains only plain single-identifier licenses' do
        let(:report_license_names) { ['MIT'] }

        it 'fires the package-exception event but not the license-expression event',
          :clean_gitlab_redis_shared_state do
          expect { denied_licenses_with_dependencies }
            .to trigger_internal_events('enforce_approval_policies_with_package_exceptions_in_project')
              .with(project: project, additional_properties: { label: 'denylist' })
            .and not_trigger_internal_events('enforce_approval_policies_with_license_expressions_in_project')
        end
      end
    end

    context 'with an allowlist policy' do
      let(:policy_licenses) { { allowed: [{ name: 'MIT License' }] } }
      let(:report_license_names) { ['MIT OR Apache-2.0'] }

      it_behaves_like 'fires the license-expression event', label: 'allowlist'
    end
  end

  context 'when the SPDX catalogue maps IDs to display names' do
    let(:pipeline_report) { create(:ci_reports_license_scanning_report) }
    let(:target_branch_report) { create(:ci_reports_license_scanning_report) }

    let(:scan_result_policy_read) do
      create(:scan_result_policy_read,
        project: project,
        license_states: ['newly_detected'],
        licenses: { denied: [{ name: 'MIT License' }] }
      )
    end

    before do
      allow(Gitlab::SPDX::Catalogue).to receive(:latest_active_licenses).and_return(
        [
          instance_double(Gitlab::SPDX::License, id: 'MIT', name: 'MIT License'),
          instance_double(Gitlab::SPDX::License, id: 'Apache-2.0', name: 'Apache License 2.0')
        ]
      )
    end

    context 'when the report contains a plain "MIT" SPDX ID' do
      before do
        pipeline_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'mit-lib')
      end

      it 'resolves "MIT" to "MIT License" and flags a violation' do
        expect(denied_licenses_with_dependencies).to eq({ 'MIT' => ['mit-lib'] })
      end
    end

    context 'when the report contains an identifier not in the SPDX catalogue' do
      before do
        pipeline_report.add_license(id: 'LicenseRef-Custom', name: 'LicenseRef-Custom')
                       .add_dependency(name: 'custom-lib')
      end

      it 'keeps the identifier as-is and does not flag a violation' do
        expect(denied_licenses_with_dependencies).to be_blank
      end
    end

    context 'when the policy name matches the raw SPDX ID but not the resolved display name' do
      let(:pipeline_report) { create(:ci_reports_license_scanning_report) }
      let(:target_branch_report) { create(:ci_reports_license_scanning_report) }

      let(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          license_states: ['newly_detected'],
          licenses: { denied: [{ name: 'MIT' }] }
        )
      end

      before do
        pipeline_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'mit-lib')
      end

      it 'does not produce a false-positive violation via policy_plus_covers_report_base?' do
        expect(denied_licenses_with_dependencies).to be_blank
      end
    end
  end

  context 'when approval_policy_source is nil' do
    let(:service) do
      described_class.new(project, pipeline_report, target_branch_report, nil)
    end

    it 'returns no denied licenses' do
      expect(denied_licenses_with_dependencies).to be_blank
    end
  end

  context 'when the policy has no denied licenses' do
    let(:scan_result_policy_read) do
      create(:scan_result_policy_read,
        project: project,
        license_states: ['detected'],
        licenses: {}
      )
    end

    it 'returns no denied licenses' do
      expect(denied_licenses_with_dependencies).to be_blank
    end
  end

  context 'with license overrides' do
    let(:target_branch_report) { build(:ci_reports_license_scanning_report) }
    let(:pipeline_report) { build(:ci_reports_license_scanning_report) }

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

    # Expression-specific coverage: an override value can itself be a compound SPDX
    # expression, which the checker parses and evaluates (unlike DeniedLicensesChecker,
    # which only does plain-name matching).
    context 'when the override value is a compound SPDX expression' do
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

      context 'with an AND expression where one component is denied' do
        let(:denied_name) { 'Apache License 2.0' }
        let(:licenses) { { 'denied' => [{ 'name' => denied_name }] } }
        let(:license_overrides) do
          [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT AND Apache-2.0', 'mode' => 'patch' }]
        end

        it 'reports a violation because AND requires every component to be allowed' do
          is_expected.to eq({ 'MIT AND Apache-2.0' => ['urllib3'] })
        end
      end

      context 'with an OR expression where every component is denied' do
        let(:denied_name) { ['MIT License', 'Apache License 2.0'] }
        let(:licenses) { { 'denied' => denied_name.map { |name| { 'name' => name } } } }
        let(:license_overrides) do
          [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT OR Apache-2.0', 'mode' => 'patch' }]
        end

        it 'reports a violation because no OR component is allowed' do
          is_expected.to eq({ 'MIT OR Apache-2.0' => ['urllib3'] })
        end
      end

      context 'with an OR expression where one component is allowed' do
        let(:denied_name) { 'Apache License 2.0' }
        let(:licenses) { { 'denied' => [{ 'name' => denied_name }] } }
        let(:license_overrides) do
          [{ 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT OR Apache-2.0', 'mode' => 'patch' }]
        end

        it 'does not report a violation because OR is satisfied by the non-denied component' do
          is_expected.to be_nil
        end
      end
    end
  end
end

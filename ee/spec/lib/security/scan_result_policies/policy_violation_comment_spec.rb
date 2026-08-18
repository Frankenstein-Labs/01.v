# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyViolationComment, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let(:existing_comment) { build(:note, author: build(:user, :security_bot)) }
  let(:comment) { described_class.new(existing_comment, merge_request) }

  def build_comment(reports: [], optional_approvals: [])
    build(:note,
      author: build(:user, :security_bot),
      note: [
        described_class::MESSAGE_HEADER,
        "<!-- violated_reports: #{reports.join(',')} -->",
        "<!-- optional_approvals: #{optional_approvals.join(',')} -->",
        "Comment body"
      ].join("\n"))
  end

  describe '#reports' do
    subject(:execute) { comment.reports }

    where(:existing_comment, :expected) do
      nil | []
      build_comment(reports: %w[scan_finding]) | %w[scan_finding]
      build_comment(reports: %w[scan_finding license_scanning]) | %w[scan_finding license_scanning]
      build_comment(reports: %w[scan_finding invalid]) | %w[scan_finding]
      build(:note, note: "invalid format") | []
    end

    with_them do
      it { is_expected.to match_array(expected) }
    end
  end

  describe '#optional_approval_reports' do
    subject(:execute) { comment.optional_approval_reports }

    where(:existing_comment, :expected) do
      nil | []
      build_comment(optional_approvals: %w[scan_finding]) | %w[scan_finding]
      build_comment(optional_approvals: %w[scan_finding license_scanning]) | %w[scan_finding license_scanning]
      build_comment(optional_approvals: %w[scan_finding invalid]) | %w[scan_finding]
      build(:note, note: "invalid format") | []
    end

    with_them do
      it { is_expected.to match_array(expected) }
    end
  end

  describe '#add_report_type' do
    subject(:add_report_type) { comment.add_report_type(report_type, requires_approval) }

    where(:report_type, :requires_approval, :existing_comment, :expected_reports, :expected_optional_reports) do
      'scan_finding' | true | nil | %w[scan_finding] | []
      'scan_finding' | false | nil | %w[scan_finding] | %w[scan_finding]
      'scan_finding' | true | build_comment(reports: %w[scan_finding]) | %w[scan_finding] | []
      'scan_finding' | false | build_comment(reports: %w[scan_finding]) | %w[scan_finding] | %w[scan_finding]
      'scan_finding' | true | build_comment(reports: %w[license_scanning]) | %w[scan_finding license_scanning] | []
      'scan_finding' | false | build_comment(reports: %w[license_scanning]) | %w[scan_finding
        license_scanning] | %w[scan_finding]
      'scan_finding' | false | build_comment(optional_approvals: %w[license_scanning]) | %w[scan_finding] | %w[
        license_scanning scan_finding
      ]
      'invalid' | true | build_comment(reports: %w[license_scanning]) | %w[license_scanning] | []
      'invalid' | false | build_comment(reports: %w[license_scanning],
        optional_approvals: %w[license_scanning]) | %w[license_scanning] | %w[license_scanning]
    end

    before do
      add_report_type
    end

    with_them do
      it { expect(comment.reports).to match_array(expected_reports) }
      it { expect(comment.optional_approval_reports).to match_array(expected_optional_reports) }
    end
  end

  describe '#remove_report_type' do
    subject(:remove_report_type) { comment.remove_report_type(report_type) }

    where(:report_type, :existing_comment, :expected_reports, :expected_optional_reports) do
      'scan_finding' | nil | [] | []
      'scan_finding' | build_comment(reports: %w[scan_finding]) | [] | []
      'scan_finding' | build_comment(reports: %w[scan_finding], optional_approvals: %w[scan_finding]) | [] | []
      'scan_finding' | build_comment(reports: %w[license_scanning]) | %w[license_scanning] | []
      'scan_finding' | build_comment(reports: %w[license_scanning],
        optional_approvals: %w[license_scanning]) | %w[license_scanning] | %w[license_scanning]
    end

    before do
      remove_report_type
    end

    with_them do
      it { expect(comment.reports).to match_array(expected_reports) }
      it { expect(comment.optional_approval_reports).to match_array(expected_optional_reports) }
    end
  end

  describe '#clear_report_types' do
    subject(:clear_report_types) { comment.clear_report_types }

    let(:existing_comment) { nil }

    before do
      comment.add_report_type('scan_finding', true)
      comment.add_report_type('license_scanning', false)
    end

    it 'can clear all previously added report types' do
      clear_report_types

      expect(comment.reports).to be_empty
      expect(comment.optional_approval_reports).to be_empty
    end
  end

  describe 'enabled_violated_policy_ids scoping' do
    let_it_be(:included_policy) { create(:scan_result_policy_read, project: project) }

    let(:comment) do
      described_class.new(nil, merge_request, enabled_violated_policy_ids: [included_policy.id])
    end

    it 'forwards the enabled_violated_policy_ids to the violation details' do
      expect(::Security::ScanResultPolicies::PolicyViolationDetails).to receive(:new)
        .with(merge_request, enabled_violated_policy_ids: [included_policy.id])
        .and_call_original

      comment.add_report_type('scan_finding', true)
      comment.body
    end
  end

  describe '#body' do
    subject(:body) { comment.body }

    let_it_be(:violations_resolved) { 'Security policy violations have been resolved.' }
    let_it_be(:violations_title_detailed_body) { 'this merge request has policy violations and errors' }
    let_it_be(:unblock_mr_text) { 'To unblock this merge request, fix these items' }

    context 'without reports' do
      it { is_expected.to include violations_resolved }
    end

    context 'with reports' do
      let(:report_requires_approval) { true }

      before do
        comment.add_report_type('scan_finding', report_requires_approval)
      end

      describe 'violations overview' do
        let_it_be(:pipeline) do
          create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
            ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
            merge_requests_as_head_pipeline: [merge_request])
        end

        let_it_be(:uuid_new) { SecureRandom.uuid }
        let_it_be(:uuid_existing) { SecureRandom.uuid }

        let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }

        let_it_be(:policy) do
          create(:scan_result_policy_read, project: project,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be(:normal_db_policy) do
          create(:security_policy, policy_index: 1,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be(:warn_mode_db_policy) do
          create(:security_policy, :enforcement_type_warn, policy_index: 2,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be(:normal_policy_rule) { create(:approval_policy_rule, security_policy: normal_db_policy) }
        let_it_be(:warn_mode_policy_rule) { create(:approval_policy_rule, security_policy: warn_mode_db_policy) }

        let_it_be(:ci_build) { pipeline.builds.first }
        let_it_be(:pipeline_scan) do
          create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
        end

        let_it_be_with_reload(:new_security_finding) do
          create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner, severity: 'high',
            uuid: uuid_new)
        end

        let_it_be(:new_vulnerability_finding) do
          create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner, uuid: uuid_new,
            name: 'New vulnerability')
        end

        let_it_be(:existing_security_finding) do
          create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner, severity: 'medium',
            uuid: uuid_existing)
        end

        let_it_be(:existing_vulnerability_finding) do
          create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
            uuid: uuid_existing, name: 'Existing vulnerability')
        end

        context 'with only enforced violations' do
          before do
            build_violation_details(:scan_finding,
              {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid_new] } } }
              },
              policy_rule: normal_policy_rule)
          end

          it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
          it { is_expected.to exclude(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
          it { is_expected.to include('Newly detected enforced `scan_finding` violations') }
          it { is_expected.to include('Test finding') }
        end

        context 'with only bypassable violations' do
          before do
            build_violation_details(:scan_finding,
              {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid_new] } } }
              },
              policy_rule: warn_mode_policy_rule)
          end

          it { is_expected.to exclude(described_class::VIOLATIONS_BLOCKING_TITLE) }
          it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
          it { is_expected.to include('Newly detected `scan_finding` violations that users can bypass') }
        end

        context 'with both enforced and bypassable violations' do
          let_it_be(:policy2) do
            create(:scan_result_policy_read, project: project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          before do
            build_violation_details(:scan_finding,
              {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid_new] } } }
              },
              policy_read: policy,
              policy_rule: normal_policy_rule)

            build_violation_details(:scan_finding,
              {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { previously_existing: [uuid_existing] } } }
              },
              policy_read: policy2,
              policy_rule: warn_mode_policy_rule,
              name: 'Warn Policy')
          end

          it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
          it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
          it { is_expected.to include('Newly detected enforced `scan_finding` violations') }
          it { is_expected.to include('Previously found `scan_finding` violations that users can bypass') }
        end

        # rubocop:disable RSpec/MultipleMemoizedHelpers -- required for test setup
        context 'with any_merge_request violations' do
          let_it_be(:any_mr_policy) do
            create(:scan_result_policy_read, project: project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be(:any_mr_normal_db_policy) do
            create(:security_policy, policy_index: 3,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be(:any_mr_warn_mode_db_policy) do
            create(:security_policy, :enforcement_type_warn, policy_index: 4,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be(:any_mr_normal_policy_rule) do
            create(:approval_policy_rule, security_policy: any_mr_normal_db_policy)
          end

          let_it_be(:any_mr_warn_mode_policy_rule) do
            create(:approval_policy_rule, security_policy: any_mr_warn_mode_db_policy)
          end

          let(:commit_sha1) { 'a' * 40 }
          let(:commit_sha2) { 'b' * 40 }
          let(:commit_sha3) { 'c' * 40 }

          context 'with enforced any_merge_request violations' do
            context 'when commits is an array' do
              before do
                build_violation_details(:any_merge_request,
                  {
                    violations: { any_merge_request: { commits: [commit_sha1, commit_sha2] } }
                  },
                  policy_read: any_mr_policy,
                  policy_rule: any_mr_normal_policy_rule,
                  name: 'Merge request policy')
              end

              it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
              it { is_expected.to include('Enforced `any_merge_request` violations') }
              it { is_expected.to include('The following policies require approval:') }
              it { is_expected.to include('* Merge request policy: any unsigned commits') }
              it { is_expected.to include('Unsigned commits:') }

              it 'includes commit SHA' do
                is_expected.to include("[`#{commit_sha1}`](#{project_commit_url(project, commit_sha1)})")
              end

              it 'includes commit SHA' do
                is_expected.to include("[`#{commit_sha2}`](#{project_commit_url(project, commit_sha2)})")
              end
            end

            context 'when commits is true' do
              before do
                build_violation_details(:any_merge_request,
                  {
                    violations: { any_merge_request: { commits: true } }
                  },
                  policy_read: any_mr_policy,
                  policy_rule: any_mr_normal_policy_rule,
                  name: 'Any Commit Policy')
              end

              it { is_expected.to include('Enforced `any_merge_request` violations') }
              it { is_expected.to include('The following policies require approval:') }
              it { is_expected.to include('* Any Commit Policy: any commits') }
              it { is_expected.not_to include('Unsigned commits:') }
            end
          end

          context 'with bypassable any_merge_request violations' do
            context 'when commits is an array' do
              before do
                build_violation_details(:any_merge_request,
                  {
                    violations: { any_merge_request: { commits: [commit_sha3] } }
                  },
                  policy_read: any_mr_policy,
                  policy_rule: any_mr_warn_mode_policy_rule,
                  name: 'Warn Merge request policy')
              end

              it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
              it { is_expected.to include('`any_merge_request` violations that users can bypass') }
              it { is_expected.to include('The following policies require either approval or bypass:') }
              it { is_expected.to include('* Warn Merge request policy: any unsigned commits') }
              it { is_expected.to include('Unsigned commits:') }

              it 'includes commit SHA' do
                is_expected.to include("[`#{commit_sha3}`](#{project_commit_url(project, commit_sha3)})")
              end
            end

            context 'when commits is true' do
              before do
                build_violation_details(:any_merge_request,
                  {
                    violations: { any_merge_request: { commits: true } }
                  },
                  policy_read: any_mr_policy,
                  policy_rule: any_mr_warn_mode_policy_rule,
                  name: 'Warn Any Commit Policy')
              end

              it { is_expected.to include('`any_merge_request` violations that users can bypass') }
              it { is_expected.to include('The following policies require either approval or bypass:') }
              it { is_expected.to include('* Warn Any Commit Policy: any commits') }
              it { is_expected.not_to include('Unsigned commits:') }
            end
          end

          context 'with both enforced and bypassable any_merge_request violations' do
            before do
              build_violation_details(:any_merge_request,
                {
                  violations: { any_merge_request: { commits: [commit_sha1] } }
                },
                policy_read: any_mr_policy,
                policy_rule: any_mr_normal_policy_rule,
                name: 'Enforced merge request policy')

              build_violation_details(:any_merge_request,
                {
                  violations: { any_merge_request: { commits: true } }
                },
                policy_read: create(:scan_result_policy_read, project: project,
                  security_orchestration_policy_configuration: security_orchestration_policy_configuration),
                policy_rule: any_mr_warn_mode_policy_rule,
                name: 'Bypassable Merge request policy')
            end

            it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
            it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
            it { is_expected.to include('Enforced `any_merge_request` violations') }
            it { is_expected.to include('`any_merge_request` violations that users can bypass') }
            it { is_expected.to include('* Enforced merge request policy: any unsigned commits') }
            it { is_expected.to include('* Bypassable Merge request policy: any commits') }
          end

          context 'with mixed scan_finding and any_merge_request violations' do
            before do
              build_violation_details(:scan_finding,
                {
                  context: { pipeline_ids: [pipeline.id] },
                  violations: { scan_finding: { uuids: { newly_detected: [uuid_new] } } }
                },
                policy_rule: normal_policy_rule)

              build_violation_details(:any_merge_request,
                {
                  violations: { any_merge_request: { commits: [commit_sha1, commit_sha2] } }
                },
                policy_read: any_mr_policy,
                policy_rule: any_mr_warn_mode_policy_rule,
                name: 'Merge request warn mode policy')
            end

            it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
            it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
            it { is_expected.to include('Newly detected enforced `scan_finding` violations') }
            it { is_expected.to include('`any_merge_request` violations that users can bypass') }
            it { is_expected.to include('* Merge request warn mode policy: any unsigned commits') }
            it { is_expected.to include('Unsigned commits:') }
          end
        end
        # rubocop:enable RSpec/MultipleMemoizedHelpers

        # rubocop:disable RSpec/MultipleMemoizedHelpers -- required for test setup
        context 'with license_finding violations' do
          let_it_be(:policy2) do
            create(:scan_result_policy_read, project: project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be(:normal_db_policy_2) do
            create(:security_policy, policy_index: 5,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be(:normal_policy_rule_2) { create(:approval_policy_rule, security_policy: normal_db_policy_2) }

          let_it_be(:license_warn_db_policy) do
            create(:security_policy, :enforcement_type_warn, policy_index: 6,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be(:license_warn_policy_rule) do
            create(:approval_policy_rule, security_policy: license_warn_db_policy)
          end

          context 'with only enforced license_finding violations' do
            before do
              comment.add_report_type('license_scanning', true)

              build_violation_details(:license_scanning,
                {
                  violations: { license_scanning: { 'MIT' => %w[package-a package-b] } }
                },
                policy_read: policy2,
                policy_rule: normal_policy_rule_2,
                name: 'License Policy')
            end

            it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
            it { is_expected.to exclude(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
            it { is_expected.to include('Enforced `license_finding` violations') }
            it { is_expected.to include('Out-of-policy licenses:') }
            it { is_expected.to include('MIT') }
            it { is_expected.to include('Used by package-a, package-b') }
          end

          context 'with only bypassable license_finding violations' do
            let_it_be(:policy3) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            before do
              comment.add_report_type('license_scanning', true)

              build_violation_details(:license_scanning,
                {
                  violations: { license_scanning: { 'Apache-2.0' => %w[package-c package-d] } }
                },
                policy_read: policy3,
                policy_rule: license_warn_policy_rule,
                name: 'Warn License Policy')
            end

            it { is_expected.to exclude(described_class::VIOLATIONS_BLOCKING_TITLE) }
            it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
            it { is_expected.to include('`license_finding` violations that users can bypass') }
            it { is_expected.to include('Out-of-policy licenses:') }
            it { is_expected.to include('Apache-2.0') }
            it { is_expected.to include('Used by package-c, package-d') }
          end

          context 'with both enforced and bypassable license_finding violations' do
            let_it_be(:policy3) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            before do
              comment.add_report_type('license_scanning', true)

              build_violation_details(:license_scanning,
                {
                  violations: { license_scanning: { 'MIT' => %w[package-a package-b] } }
                },
                policy_read: policy2,
                policy_rule: normal_policy_rule_2,
                name: 'License Policy')

              build_violation_details(:license_scanning,
                {
                  violations: { license_scanning: { 'GPL-3.0' => %w[package-e] } }
                },
                policy_read: policy3,
                policy_rule: license_warn_policy_rule,
                name: 'Warn License Policy')
            end

            it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
            it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
            it { is_expected.to include('Enforced `license_finding` violations') }
            it { is_expected.to include('`license_finding` violations that users can bypass') }
            it { is_expected.to include('MIT') }
            it { is_expected.to include('Used by package-a, package-b') }
            it { is_expected.to include('GPL-3.0') }
            it { is_expected.to include('Used by package-e') }
          end

          context 'with mixed scan_finding and license_finding violations' do
            let_it_be(:policy3) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            before do
              comment.add_report_type('license_scanning', true)

              build_violation_details(:scan_finding,
                {
                  context: { pipeline_ids: [pipeline.id] },
                  violations: { scan_finding: { uuids: { newly_detected: [uuid_new] } } }
                },
                policy_rule: normal_policy_rule)

              build_violation_details(:license_scanning,
                {
                  violations: { license_scanning: { 'MIT' => %w[package-a] } }
                },
                policy_read: policy3,
                policy_rule: license_warn_policy_rule,
                name: 'Warn License Policy')
            end

            it { is_expected.to include(described_class::VIOLATIONS_BLOCKING_TITLE) }
            it { is_expected.to include(described_class::VIOLATIONS_BYPASSABLE_TITLE) }
            it { is_expected.to include('Newly detected enforced `scan_finding` violations') }
            it { is_expected.to include('`license_finding` violations that users can bypass') }
            it { is_expected.to include('MIT') }
            it { is_expected.to include('Used by package-a') }
          end

          context 'with license violations exceeding MAX_VIOLATIONS' do
            let_it_be(:policy3) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            let(:many_dependencies) do
              (0..Security::ScanResultPolicyViolation::MAX_VIOLATIONS).map { |n| "package-#{n.to_s.rjust(3, '0')}" }
            end

            before do
              comment.add_report_type('license_scanning', true)

              build_violation_details(:license_scanning,
                {
                  violations: { license_scanning: { 'Apache-2.0' => many_dependencies } }
                },
                policy_read: policy3,
                policy_rule: normal_policy_rule_2,
                name: 'License Policy')
            end

            it { is_expected.to include('Apache-2.0') }
            it { is_expected.to include('…and more') }

            it 'includes only MAX_VIOLATIONS dependencies' do
              many_dependencies.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS).each do |dep|
                expect(body).to include(dep)
              end
            end
          end
          # rubocop:enable RSpec/MultipleMemoizedHelpers
        end
      end

      describe 'summary' do
        let_it_be(:policy1) { create(:scan_result_policy_read, project: project) }
        let_it_be(:policy2) { create(:scan_result_policy_read, project: project) }
        let_it_be(:policy3) { create(:scan_result_policy_read, project: project) }
        let_it_be(:scan_policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy, name: 'Scan'))
        end

        let_it_be(:license_policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy, name: 'License'))
        end

        let_it_be(:any_mr_policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy, name: 'Any merge request'))
        end

        let_it_be(:scan_finding_rule_policy1) do
          create(:report_approver_rule, :scan_finding, merge_request: merge_request,
            scan_result_policy_read: policy1, approval_policy_rule: scan_policy_rule, name: 'Scan')
        end

        let_it_be(:license_scanning_rule_policy2) do
          create(:report_approver_rule, :license_scanning, merge_request: merge_request,
            scan_result_policy_read: policy2, approval_policy_rule: license_policy_rule, name: 'License')
        end

        let_it_be(:non_violated_rule_policy3) do
          create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
            scan_result_policy_read: policy3, approval_policy_rule: any_mr_policy_rule, name: 'Any merge request')
        end

        before do
          create(:scan_result_policy_violation, project: project, merge_request: merge_request,
            scan_result_policy_read: policy1, approval_policy_rule: scan_policy_rule)
          create(:scan_result_policy_violation, project: project, merge_request: merge_request,
            scan_result_policy_read: policy2, approval_policy_rule: license_policy_rule,
            violation_data: { 'violations' => { 'license_scanning' => { 'MIT' => ['A'] } } })
        end

        it { is_expected.to include violations_title_detailed_body }
        it { is_expected.to include unblock_mr_text }

        context 'when approvals are optional' do
          let(:report_requires_approval) { false }

          it { is_expected.not_to include unblock_mr_text }
          it { is_expected.to include 'Consider including optional reviewers' }
        end

        it { is_expected.to include 'Resolve all violations' }

        it 'includes violated policy names' do
          expect(body)
            .to include 'Resolve all violations in the following merge request approval policies: License, Scan'
          expect(body).not_to include 'Any merge request'
        end

        it 'includes a bullet point for licenses' do
          expect(body)
            .to include('Remove all denied licenses identified by the following merge request approval policies: ' \
              'License')
        end

        context 'with "any_merge_request" rule violations' do
          before do
            create(:scan_result_policy_violation, project: project, merge_request: merge_request,
              scan_result_policy_read: policy3, approval_policy_rule: any_mr_policy_rule)
          end

          it 'includes information about acquiring approvals' do
            expect(body).to include('Resolve all violations in the following merge request approval policies: ' \
              'Any merge request, License, Scan')
            expect(body).to include('Acquire approvals from eligible approvers defined in the following ' \
              'merge request approval policies: Any merge request')
          end
        end

        context 'with errors' do
          before do
            create(:scan_result_policy_violation, project: project, merge_request: merge_request,
              scan_result_policy_read: policy3, approval_policy_rule: any_mr_policy_rule,
              violation_data: { 'errors' => [{ 'error' => 'error' }] })
          end

          it 'includes information about errors' do
            expect(body).to include 'Resolve the errors and re-run the pipeline'
          end
        end

        context 'with fail-open policies' do
          before do
            create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
              scan_result_policy_read: policy3, approval_policy_rule: any_mr_policy_rule,
              violation_data: { 'errors' => [{ 'error' => 'SCAN_REMOVED' }] })
          end

          it 'includes information about fail-open policies' do
            expect(body).to include 'The following policies enforced on your project were skipped because they are ' \
              'configured to fail open: Any merge request.'
          end
        end

        context 'with warn-mode policies' do
          let_it_be(:warn_mode_policy) do
            create(:security_policy, :enforcement_type_warn, name: 'Warn Policy')
          end

          context 'when there is one warn-mode policy' do
            before do
              allow_next_instance_of(::Security::ScanResultPolicies::PolicyViolationDetails) do |details|
                allow(details).to receive(:warn_mode_policies).and_return([warn_mode_policy])
              end
            end

            it 'includes warn-mode summary in the comment body' do
              expect(body).to include(
                '**Note:** The following policies are in warn mode and can be bypassed to make approvals optional:'
              )
              expect(body).to include('- Warn Policy')
            end
          end

          context 'when there are multiple warn-mode policies' do
            let_it_be(:warn_mode_policy_2) do
              create(:security_policy, :enforcement_type_warn, policy_index: 1, name: 'Another Warn Policy')
            end

            before do
              allow_next_instance_of(::Security::ScanResultPolicies::PolicyViolationDetails) do |details|
                allow(details).to receive(:warn_mode_policies).and_return([warn_mode_policy, warn_mode_policy_2])
              end
            end

            it 'includes warn-mode summary for multiple policies' do
              expect(body).to include('- Another Warn Policy')
              expect(body).to include('- Warn Policy')
            end
          end

          context 'without warn-mode policy approval settings overrides' do
            let_it_be(:enforced_policy) do
              create(:security_policy,
                content: {
                  enforcement_type: 'enforce',
                  approval_settings: {
                    prevent_approval_by_author: true
                  }
                })
            end

            before do
              project.update!(merge_requests_author_approval: false)

              allow_next_instance_of(::Security::ScanResultPolicies::PolicyViolationDetails) do |details|
                allow(details).to receive(:warn_mode_policies).and_return([enforced_policy])
              end
            end

            it 'excludes overrides segment' do
              expect(body).to exclude(
                ':lock: **Warn-mode policies set more restrictive approval settings**'
              )
            end
          end

          context 'with warn-mode policy but without overrides' do
            let_it_be(:warn_mode_policy) do
              create(:security_policy,
                content: {
                  enforcement_type: 'enforce',
                  approval_settings: {
                    prevent_approval_by_author: true
                  }
                })
            end

            before do
              project.update!(merge_requests_author_approval: false)

              allow_next_instance_of(::Security::ScanResultPolicies::PolicyViolationDetails) do |details|
                allow(details).to receive(:warn_mode_policies).and_return([warn_mode_policy])
              end
            end

            it 'excludes overrides segment' do
              expect(body).to exclude(
                ':lock: **Warn-mode policies set more restrictive approval settings**'
              )
            end
          end

          context 'when warn-mode policy overrides project approval settings' do
            let_it_be(:warn_mode_policy_3) do
              create(:security_policy,
                content: {
                  enforcement_type: 'warn',
                  approval_settings: {
                    prevent_approval_by_author: true,
                    prevent_approval_by_commit_author: true,
                    remove_approvals_with_new_commit: true,
                    require_password_to_approve: true
                  }
                })
            end

            let_it_be(:warn_mode_policy_4) do
              create(:security_policy,
                content: {
                  enforcement_type: 'warn',
                  approval_settings: {
                    prevent_approval_by_author: true
                  }
                })
            end

            before do
              project.update!(
                merge_requests_author_approval: true,
                merge_requests_disable_committers_approval: false,
                reset_approvals_on_push: false,
                require_password_to_approve: false
              )

              allow_next_instance_of(::Security::ScanResultPolicies::PolicyViolationDetails) do |details|
                allow(details).to receive(:warn_mode_policies).and_return(
                  [warn_mode_policy, warn_mode_policy_3, warn_mode_policy_4]
                )
              end
            end

            it 'includes overrides segment' do
              expect(body).to include(
                ':lock: **Warn mode policies set more restrictive approval settings**'
              )
            end

            it 'lists more restrictive policies' do
              expect(body).to include('__Prevent approval by merge request creator__')
              expect(body).to include('__Prevent approvals by users who add commits__')
              expect(body).to include('__When a commit is added: Remove all approvals__')
              expect(body).to include('__Require user re-authentication (password or SAML) to approve__')
              expect(body).to include("`#{warn_mode_policy_3.name}`")
              expect(body).to include("`#{warn_mode_policy_4.name}`")
            end
          end
        end
      end

      context 'without violation details' do
        it { is_expected.not_to include described_class::VIOLATIONS_BLOCKING_TITLE }
        it { is_expected.not_to include described_class::VIOLATIONS_DETECTED_TITLE }
      end

      context 'with violation details' do
        let_it_be(:uuid) { SecureRandom.uuid }
        let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
        let_it_be(:pipeline) do
          create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
            ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
            merge_requests_as_head_pipeline: [merge_request])
        end

        let_it_be(:ci_build) { pipeline.builds.first }
        let_it_be(:pipeline_scan) do
          create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
        end

        let_it_be(:policy) do
          create(:scan_result_policy_read, project: project,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be_with_reload(:new_security_finding) do
          create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner, severity: 'high',
            uuid: uuid)
        end

        let_it_be(:new_vulnerability_finding) do
          create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner, uuid: uuid,
            name: 'AWS API key')
        end

        it { is_expected.not_to include described_class::VIOLATIONS_BLOCKING_TITLE }
        it { is_expected.not_to include described_class::VIOLATIONS_DETECTED_TITLE }

        shared_examples_for 'title for detected violations' do
          it { is_expected.to include described_class::VIOLATIONS_BLOCKING_TITLE }
          it { is_expected.not_to include described_class::VIOLATIONS_DETECTED_TITLE }
        end

        shared_examples 'with CVE enrichment data' do
          before do
            create(:security_finding_enrichment, finding_uuid: enrichment_finding_uuid, cve: 'CVE-2024-1234',
              epss_score: 0.85, is_known_exploit: true)
            create(:security_finding_enrichment, finding_uuid: enrichment_finding_uuid, cve: 'CVE-2024-6789')
          end

          it 'includes CVE enrichment information inline' do
            expect(body).to include('- `CVE-2024-1234` **·** EPSS: 0.85 **·** Known Exploited: Yes')
            expect(body).to include('- `CVE-2024-6789` **·** EPSS: Unknown **·** Known Exploited: Unknown')
          end

          context 'when is_known_exploit is false' do
            before do
              create(:security_finding_enrichment, finding_uuid: enrichment_finding_uuid, cve: 'CVE-2024-9999',
                epss_score: 0.50, is_known_exploit: false)
            end

            it 'includes "No" for Known Exploited when is_known_exploit is false' do
              expect(body).to include('- `CVE-2024-9999` **·** EPSS: 0.5 **·** Known Exploited: No')
            end
          end
        end

        describe 'newly_introduced_violations' do
          before do
            build_violation_details(:scan_finding,
              {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid] } } }
              })
          end

          it_behaves_like 'title for detected violations'

          it { is_expected.to include 'High', 'Test finding', 'Dependency scanning' }

          context 'with CVE enrichment data' do
            let(:enrichment_finding_uuid) { uuid }

            it_behaves_like 'with CVE enrichment data'
          end

          context 'with CVE identifier' do
            before_all do
              # Update security_finding to include CVE identifier
              finding_data = new_security_finding.finding_data.dup
              finding_data[:identifiers] = [
                { external_type: 'cve', external_id: 'CVE-2024-1234', name: 'CVE-2024-1234', url: 'https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2024-1234' }
              ]
              new_security_finding.update!(finding_data: finding_data)

              # Also update vulnerability_finding
              cve_identifier = create(:vulnerabilities_identifier, external_type: 'cve',
                external_id: 'CVE-2024-1234', name: 'CVE-2024-1234', project: project)
              new_vulnerability_finding.identifiers << cve_identifier
            end

            it { is_expected.to include 'CVE-2024-1234' }
          end

          context 'with CWE identifier but no CVE' do
            before_all do
              # Update security_finding to include CWE identifier
              finding_data = new_security_finding.finding_data.dup
              finding_data[:identifiers] = [
                { external_type: 'cwe', external_id: 'CWE-79', name: 'CWE-79', url: 'https://cwe.mitre.org/data/definitions/79.html' }
              ]
              new_security_finding.update!(finding_data: finding_data)

              # Also update vulnerability_finding
              cwe_identifier = create(:vulnerabilities_identifier, external_type: 'cwe',
                external_id: 'CWE-79', name: 'CWE-79', project: project)
              new_vulnerability_finding.identifiers << cwe_identifier
            end

            it { is_expected.to include 'CWE-79' }
          end

          context 'without identifier' do
            before_all do
              # Update security_finding to have no identifiers
              finding_data = new_security_finding.finding_data.dup
              finding_data[:identifiers] = []
              new_security_finding.update!(finding_data: finding_data)
            end

            it { is_expected.not_to include 'CVE-' }
            it { is_expected.not_to include 'CWE-' }
          end
        end

        describe 'previously_existing_violations' do
          before do
            build_violation_details(:scan_finding,
              {
                violations: { scan_finding: { uuids: { previously_existing: [uuid] } } }
              })
          end

          it_behaves_like 'title for detected violations'

          it { is_expected.to include 'Critical', 'AWS API key', 'Secret detection' }

          context 'with CVE enrichment data' do
            let(:enrichment_finding_uuid) { uuid }

            it_behaves_like 'with CVE enrichment data'
          end

          context 'with CVE identifier' do
            before_all do
              cve_identifier = create(:vulnerabilities_identifier, external_type: 'cve',
                external_id: 'CVE-2024-5678', name: 'CVE-2024-5678', project: project)
              new_vulnerability_finding.identifiers << cve_identifier
            end

            it { is_expected.to include 'CVE-2024-5678' }
          end
        end

        describe 'any_merge_request_violations' do
          before do
            build_violation_details(:any_merge_request,
              {
                violations: { any_merge_request: { commits: commits } }
              })
          end

          context 'with a list of commits' do
            let(:commits) { ['abcd1234'] }

            it_behaves_like 'title for detected violations'

            it 'includes the section and a linked commit' do
              expect(body).to include 'Unsigned commits',
                "[`abcd1234`](#{project_commit_url(project, 'abcd1234')})"
            end

            it { is_expected.not_to include described_class::MORE_VIOLATIONS_DETECTED }

            context 'when the list is longer than MAX_VIOLATIONS' do
              let(:commits) { (0..Security::ScanResultPolicyViolation::MAX_VIOLATIONS).map { |n| "abcdef0#{n}" } }

              it { is_expected.to include(*commits.first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS)) }
              it { is_expected.to include described_class::MORE_VIOLATIONS_DETECTED }
            end
          end

          context 'with any commits' do
            let(:commits) { true }

            it { is_expected.to include 'Acquire approvals from eligible approvers' }
            it { is_expected.not_to include 'Unsigned commits' }
          end
        end

        describe 'scan finding violations with location details' do
          let_it_be(:uuid_with_location) { SecureRandom.uuid }

          let_it_be_with_reload(:security_finding_with_location) do
            create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
              severity: 'high', uuid: uuid_with_location,
              location: {
                'file' => 'package.json',
                'start_line' => 42,
                'dependency' => {
                  'package' => { 'name' => 'lodash' },
                  'version' => '4.17.20'
                }
              })
          end

          let_it_be(:vulnerability_finding_with_location) do
            create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
              uuid: uuid_with_location, name: 'Vulnerable dependency')
          end

          before do
            build_violation_details(:scan_finding,
              {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid_with_location] } } }
              })
          end

          it { is_expected.to include 'Package lodash' }
          it { is_expected.to include '4.17.20' }
          it { is_expected.to include 'Line 42' }
          it { is_expected.to include 'package.json' }

          context 'with CVE identifier' do
            before_all do
              # Update the security_finding to include CVE identifier
              finding_data = security_finding_with_location.finding_data.dup
              finding_data[:identifiers] = [
                { external_type: 'cve', external_id: 'CVE-2024-9999', name: 'CVE-2024-9999', url: 'https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2024-9999' }
              ]
              security_finding_with_location.update!(finding_data: finding_data)

              # Also update the vulnerability_finding
              cve_identifier = create(:vulnerabilities_identifier, external_type: 'cve',
                external_id: 'CVE-2024-9999', name: 'CVE-2024-9999', project: project)
              vulnerability_finding_with_location.identifiers << cve_identifier
            end

            it { is_expected.to include 'CVE-2024-9999' }
            it { is_expected.to include 'Package lodash' }

            it 'formats the complete violation line with CVE, package, and location' do
              expect(body).to match(/High.*·.*CVE-2024-9999.*·.*Line 42.*Package lodash.*4\.17\.20.*package\.json/)
            end
          end

          context 'without package name' do
            let_it_be(:uuid_no_package) { SecureRandom.uuid }

            let_it_be(:security_finding_no_package) do
              create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
                severity: 'high', uuid: uuid_no_package,
                location: {
                  'file' => 'Gemfile.lock',
                  'start_line' => 10,
                  'dependency' => { 'version' => '1.2.3' }
                })
            end

            let_it_be(:vulnerability_finding_no_package) do
              create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
                uuid: uuid_no_package, name: 'Vulnerable dependency without package')
            end

            before do
              violation = Security::ScanResultPolicyViolation.last
              violation.update!(violation_data: {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid_no_package] } } }
              })
            end

            it { is_expected.not_to include 'Package' }
            it { is_expected.to include 'Line 10' }
            it { is_expected.to include 'Gemfile.lock' }
          end

          context 'without start_line in location' do
            let_it_be(:uuid_no_start_line) { SecureRandom.uuid }

            let_it_be(:security_finding_no_start_line) do
              create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
                severity: 'medium', uuid: uuid_no_start_line,
                location: {
                  'file' => 'app.rb',
                  'dependency' => {
                    'package' => { 'name' => 'rails' },
                    'version' => '6.0.0'
                  }
                })
            end

            let_it_be(:vulnerability_finding_no_start_line) do
              create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
                uuid: uuid_no_start_line, name: 'Vulnerability without line number')
            end

            before do
              violation = Security::ScanResultPolicyViolation.last
              violation.update!(violation_data: {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid_no_start_line] } } }
              })
            end

            it { is_expected.to include 'Package rails' }
            it { is_expected.to include '6.0.0' }
            it { is_expected.not_to include 'Line' }
            it { is_expected.to include 'app.rb' }
          end

          context 'without any location metadata' do
            let_it_be(:uuid_no_metadata) { SecureRandom.uuid }

            let_it_be(:security_finding_no_metadata) do
              create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
                severity: 'low', uuid: uuid_no_metadata,
                location: { 'file' => 'config.yml' })
            end

            let_it_be(:vulnerability_finding_no_metadata) do
              create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
                uuid: uuid_no_metadata, name: 'Minimal violation')
            end

            before do
              violation = Security::ScanResultPolicyViolation.last
              violation.update!(violation_data: {
                context: { pipeline_ids: [pipeline.id] },
                violations: { scan_finding: { uuids: { newly_detected: [uuid_no_metadata] } } }
              })
            end

            it { is_expected.to include 'config.yml' }
            it { is_expected.not_to include 'Line' }
            it { is_expected.not_to include 'Package' }
          end
        end

        describe 'license_scanning_violations' do
          before do
            build_violation_details(:license_scanning,
              {
                violations: { license_scanning: { 'MIT' => %w[A B] } }
              })
          end

          it { is_expected.to include 'Out-of-policy licenses', 'MIT', 'Used by A, B' }
        end

        describe 'errors' do
          before do
            build_violation_details(:scan_finding,
              {
                errors: [{ error: Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing] }]
              })
          end

          it { is_expected.to include 'Errors', 'Pipeline configuration error' }
        end

        describe 'comparison pipelines' do
          let_it_be(:target_pipeline) do
            create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
              ref: merge_request.target_branch, sha: merge_request.diff_head_sha)
          end

          def pipeline_id_with_link(id)
            "[##{id}](#{project_pipeline_url(project, id)})"
          end

          context 'when pipeline ids of one report_type are present' do
            before do
              build_violation_details(:scan_finding,
                { 'context' => { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] } }
              )
            end

            it 'includes linked pipelines in the body' do
              expect(body).to include 'Comparison pipelines',
                pipeline_id_with_link(pipeline.id),
                pipeline_id_with_link(target_pipeline.id)
            end

            it 'does not render the report_type title' do
              expect(body).not_to include 'Scan finding'
            end
          end

          context 'when pipeline ids from multiple reports are present' do
            let_it_be(:policy2) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            before do
              build_violation_details(:scan_finding,
                { 'context' => { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] } }
              )
              build_violation_details(:license_scanning,
                { 'context' => { 'pipeline_ids' => [123], 'target_pipeline_ids' => [456] } },
                policy_read: policy2,
                name: 'Policy 2'
              )
            end

            it 'displays them grouped by report_type, showing the titles' do
              expect(body).to include 'Comparison pipelines', 'Scan finding', 'License scanning',
                pipeline_id_with_link(pipeline.id),
                pipeline_id_with_link(target_pipeline.id),
                pipeline_id_with_link(123),
                pipeline_id_with_link(456)
            end
          end

          context 'when multiple pipeline ids are present' do
            before do
              build_violation_details(:scan_finding,
                { 'context' => {
                  'pipeline_ids' => [pipeline.id, 123456],
                  'target_pipeline_ids' => [target_pipeline.id, 456789]
                } }
              )
            end

            it 'displays them as comma-separated list in the body' do
              expect(body).to include 'Comparison pipelines',
                "#{pipeline_id_with_link(pipeline.id)}, #{pipeline_id_with_link(123456)}",
                "#{pipeline_id_with_link(target_pipeline.id)}, #{pipeline_id_with_link(456789)}"
            end
          end

          context 'when some pipeline ids are missing' do
            before do
              build_violation_details(:scan_finding,
                { 'context' => { 'target_pipeline_ids' => [target_pipeline.id] } }
              )
            end

            it 'shows fallback message' do
              expect(body).to include 'Comparison pipelines',
                pipeline_id_with_link(target_pipeline.id),
                "Source branch (`#{merge_request.source_branch}`): None"
            end
          end

          context 'when no pipeline ids are present' do
            it 'does not show comparison pipelines block' do
              expect(body).not_to include 'Comparison pipelines'
            end
          end
        end
      end
    end
  end

  private

  delegate :project_commit_url, :project_pipeline_url, to: 'Gitlab::Routing.url_helpers'

  def build_violation_details(report_type, data, policy_read: policy, name: 'Policy', policy_rule: nil)
    # With deprecate_scan_result_policies enabled, violations are matched to approval rules by approval_policy_rule_id
    # and the displayed policy name comes from the rule's security policy, so build a rule named after `name`
    # (preserving warn-mode from any passed policy_rule).
    warn_mode = policy_rule&.security_policy&.warn_mode? || false
    approval_policy_rule = create(:approval_policy_rule,
      security_policy: create(:security_policy, *(warn_mode ? [:enforcement_type_warn] : []), name: name))
    project_rule = create(:approval_project_rule, project: project, scan_result_policy_read: policy_read)
    create(:report_approver_rule, report_type, merge_request: merge_request, approval_project_rule: project_rule,
      scan_result_policy_read: policy_read, approval_policy_rule: approval_policy_rule, name: name)
    create(:scan_result_policy_violation, project: project, merge_request: merge_request,
      scan_result_policy_read: policy_read, violation_data: data, approval_policy_rule: approval_policy_rule)
  end
end

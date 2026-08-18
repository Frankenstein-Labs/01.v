# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.mergeRequest.policyViolations', feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:pipeline) do
    create(:ee_ci_pipeline, :success, :with_dependency_scanning_report,
      project: project, ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
      merge_requests_as_head_pipeline: [merge_request])
  end

  let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }

  let(:policy_violation_fields) do
    <<~QUERY
      policyViolations {
        policies {
          name
          reportType
        }
        newScanFinding {
          name
          reportType
          severity
          location
          path
        }
        previousScanFinding {
          name
          reportType
          severity
          location
          path
        }
        licenseScanning {
          license
          dependencies
          url
        }
        anyMergeRequest {
          name
          commits
        }
        errors {
          error
          message
          reportType
          data
        }
        comparisonPipelines {
          reportType
          source
          target
        }
      }
    QUERY
  end

  let(:merge_request_fields) do
    query_graphql_field(
      :merge_request,
      { iid: merge_request.iid.to_s },
      policy_violation_fields)
  end

  let(:query) { graphql_query_for(:project, { full_path: project.full_path }, merge_request_fields) }

  subject(:result) { graphql_data_at(:project, :merge_request, :policy_violations) }

  context 'when the user is not authorized to read the field' do
    before do
      post_graphql(query, current_user: user)
    end

    it { is_expected.to be_nil }
  end

  context 'when the user is authorized to read the field' do
    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(security_orchestration_policies: true, security_dashboard: true)
    end

    context 'when feature is available' do
      it 'returns empty data' do
        post_graphql(query, current_user: user)
        expect(result).to eq({
          comparisonPipelines: [],
          errors: [],
          licenseScanning: [],
          newScanFinding: [],
          anyMergeRequest: [],
          previousScanFinding: [],
          policies: []
        }.deep_stringify_keys)
      end

      context 'with violations' do
        let_it_be(:policy1) { create(:scan_result_policy_read, project: project) }
        let_it_be(:policy2) { create(:scan_result_policy_read, project: project) }
        let_it_be(:policy3) { create(:scan_result_policy_read, project: project) }
        let_it_be(:license_policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy, name: 'License policy'))
        end

        let_it_be(:scans_policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy, name: 'Scans'))
        end

        let_it_be(:any_mr_policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy, name: 'Any MR'))
        end

        let_it_be(:license_scanning_rule) do
          create(:report_approver_rule, :license_scanning, merge_request: merge_request,
            scan_result_policy_read: policy1, approval_policy_rule: license_policy_rule, name: 'License policy')
        end

        let_it_be(:scan_finding_rule) do
          create(:report_approver_rule, :scan_finding, merge_request: merge_request,
            scan_result_policy_read: policy2, approval_policy_rule: scans_policy_rule, name: 'Scans')
        end

        let_it_be(:any_merge_request_rule) do
          create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
            scan_result_policy_read: policy3, approval_policy_rule: any_mr_policy_rule, name: 'Any MR')
        end

        context 'with license scanning violations' do
          before do
            create(:scan_result_policy_violation, :license_scanning, merge_request: merge_request, project: project,
              scan_result_policy_read: policy1, approval_policy_rule: license_policy_rule)
            post_graphql(query, current_user: user)
          end

          it 'returns expected data' do
            expect(result).to match(a_hash_including(
              {
                licenseScanning: [{ license: 'MIT', dependencies: %w[A B], url: nil }],
                policies: [{ name: 'License policy', reportType: 'LICENSE_SCANNING' }]
              }.deep_stringify_keys))
          end
        end

        context 'with new scan finding violations' do
          let(:uuid) { SecureRandom.uuid }
          let_it_be(:ci_build) { pipeline.builds.first }
          let_it_be(:pipeline_scan) do
            create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
          end

          before do
            create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
              severity: 'high', uuid: uuid, location: { start_line: 3, file: '.env' })
            create(:scan_result_policy_violation, :new_scan_finding, merge_request: merge_request, project: project,
              scan_result_policy_read: policy2, approval_policy_rule: scans_policy_rule, uuids: [uuid],
              validation_context: { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [789] })

            post_graphql(query, current_user: user)
          end

          it 'returns expected data' do
            expect(result).to match(a_hash_including(
              'newScanFinding' => [
                a_hash_including('name' => 'Test finding', 'reportType' => 'DEPENDENCY_SCANNING',
                  'severity' => 'HIGH', 'location' => { 'file' => '.env', 'start_line' => 3 })
              ],
              'policies' => [{ 'name' => 'Scans', 'reportType' => 'SCAN_FINDING' }],
              'comparisonPipelines' => [
                { 'reportType' => 'SCAN_FINDING',
                  'source' => [::Gitlab::GlobalId.as_global_id(pipeline.id, model_name: 'Ci::Pipeline').to_s],
                  'target' => [::Gitlab::GlobalId.as_global_id(789, model_name: 'Ci::Pipeline').to_s] }
              ]
            ))
          end
        end

        context 'with previous scan finding violations' do
          let(:uuid) { SecureRandom.uuid }

          before do
            create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
              uuid: uuid, name: 'AWS API key')
            create(:scan_result_policy_violation, :previous_scan_finding, merge_request: merge_request,
              project: project, scan_result_policy_read: policy2, approval_policy_rule: scans_policy_rule,
              uuids: [uuid])

            post_graphql(query, current_user: user)
          end

          it 'returns expected data' do
            expect(result).to match(a_hash_including(
              'previousScanFinding' => [
                a_hash_including('name' => 'AWS API key', 'reportType' => 'SECRET_DETECTION',
                  'severity' => 'CRITICAL',
                  'location' => a_hash_including('file' => 'aws-key.py', 'start_line' => 5))
              ],
              'policies' => [{ 'name' => 'Scans', 'reportType' => 'SCAN_FINDING' }]
            ))
          end
        end

        context 'with any_merge_request violations' do
          before do
            create(:scan_result_policy_violation, :any_merge_request, merge_request: merge_request,
              project: project, scan_result_policy_read: policy3, approval_policy_rule: any_mr_policy_rule)

            post_graphql(query, current_user: user)
          end

          it 'returns expected data' do
            expect(result).to match(a_hash_including(
              'anyMergeRequest' => [
                a_hash_including('name' => 'Any MR', 'commits' => ['f89a4ed7'])
              ],
              'policies' => [
                { 'name' => 'Any MR', 'reportType' => 'ANY_MERGE_REQUEST' }
              ]
            ))
          end
        end

        context 'with violation errors' do
          before do
            create(:scan_result_policy_violation, :with_errors, merge_request: merge_request,
              project: project, scan_result_policy_read: policy2, approval_policy_rule: scans_policy_rule)

            post_graphql(query, current_user: user)
          end

          it 'returns expected data' do
            expect(result).to match(a_hash_including(
              'errors' => [a_hash_including('message',
                'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_removed],
                'data' => { 'missing_scans' => ['secret_detection'] })],
              'policies' => [{ 'name' => 'Scans', 'reportType' => 'SCAN_FINDING' }]
            ))
          end
        end
      end
    end
  end
end

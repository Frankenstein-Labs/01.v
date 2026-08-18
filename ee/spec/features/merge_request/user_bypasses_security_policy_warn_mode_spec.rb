# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User bypasses security policy in warn mode',
  :js, :sidekiq_inline, feature_category: :security_policy_management do
  include Features::SecurityPolicyHelpers

  include_context 'with default organization security policy configuration'

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { project.creator }
  let_it_be(:policy_management_project) { create(:project, :repository, creator: user, namespace: project.namespace) }
  let(:merge_request) do
    ::MergeRequests::CreateService.new(project: project,
      current_user: user,
      params: {
        title: 'MR to test warn mode policy bypass',
        target_branch: project.default_branch,
        source_branch: 'feature'
      }).execute
  end

  # The policy rule uses `branch_type: 'protected'` so the target branch must be protected for it to apply
  let_it_be_with_reload(:protected_branch) do
    create(:protected_branch, project: project, name: project.default_branch)
  end

  let_it_be(:finding_uuid) { SecureRandom.uuid }

  let(:policy_name) { 'MR - Security Scan' }
  let(:warn_mode_policy) do
    build(:approval_policy, :fail_open,
      name: policy_name,
      enforcement_type: 'warn',
      rules: [{
        type: 'scan_finding',
        scanners: %w[secret_detection],
        vulnerabilities_allowed: 0,
        severity_levels: [],
        vulnerability_states: [],
        branch_type: 'protected'
      }])
  end

  let(:policy_yaml) do
    build(:orchestration_policy_yaml, scan_execution_policy: [], approval_policy: [warn_mode_policy])
  end

  before_all do
    project.add_developer(user)
  end

  context 'with warn mode approval policy and secret detection findings' do
    let!(:pipeline) do
      create(:ee_ci_pipeline, :success, :with_secret_detection_report,
        merge_requests_as_head_pipeline: [merge_request],
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha)
    end

    before do
      sign_in(user)
    end

    context 'when policy is in warn mode (enforcement_type: warn)' do
      let(:project_policy_configuration) { project.security_orchestration_policy_configuration }

      let(:security_policy) do
        Security::Policy.find_by!(name: policy_name)
      end

      before do
        create_policy_setup
      end

      it 'does not block the MR', :aggregate_failures do
        merge_request.mark_as_unchecked!
        merge_request.mark_as_mergeable!

        visit(project_merge_request_path(project, merge_request))

        expect(page).to have_button('Merge', exact: true)
        expect(page).not_to have_content 'Merge blocked'
      end

      context 'when user bypasses the warn mode policy' do
        let_it_be(:bypass_comment) { "Emergency bypass for production issue" }

        # Created by create_policy_setup
        let(:scan_result_policy_read) do
          Security::ScanResultPolicyRead.find_by!(project: project)
        end

        let!(:violation) do
          Security::ScanResultPolicyViolation.find_or_create_by!(
            project: project,
            merge_request: merge_request,
            scan_result_policy_id: scan_result_policy_read.id
          ) do |v|
            v.violation_data = {
              "violations" => { "scan_finding" => { "uuids" => { "newly_detected" => [finding_uuid] } } }
            }
          end
        end

        it 'blocks the MR until policy is dismissed', :aggregate_failures do
          expect(violation).not_to be_dismissed

          dismiss_policy_violations

          expect(violation.reload).to be_dismissed
        end

        context 'when security_policy_id does not exist' do
          it 'returns an error and does not dismiss the violation', :aggregate_failures do
            expect(violation).not_to be_dismissed

            result = dismiss_policy_violations(policy_ids: [non_existing_record_id])

            expect(result).to be_error
            expect(result.message).to eq("No warn mode policies are found.")
            expect(violation.reload).not_to be_dismissed
          end
        end

        context 'when security_policy_id belongs to a non-warn-mode policy' do
          let(:enforce_mode_policy) do
            create(:security_policy, :enforcement_type_enforce,
              name: 'Enforce Mode Policy',
              policy_index: 1,
              security_orchestration_policy_configuration: project_policy_configuration,
              security_policy_management_project_id: project_policy_configuration.security_policy_management_project_id)
          end

          it 'returns an error and does not dismiss the violation', :aggregate_failures do
            expect(violation).not_to be_dismissed

            result = dismiss_policy_violations(policy_ids: [enforce_mode_policy.id])

            expect(result).to be_error
            expect(result.message).to eq("No warn mode policies are found.")
            expect(violation.reload).not_to be_dismissed
          end
        end

        context 'when dismissal does not cover all violations on preserve' do
          let(:vulnerability) do
            create(:vulnerability, :detected, :secret_detection,
              title: 'AWS access token',
              project: project)
          end

          it 'destroys the dismissal and does not create an audit event', :aggregate_failures do
            resolved_finding_uuid = vulnerability.vulnerability_finding.uuid

            violation.update!(violation_data: {
              "violations" => {
                "scan_finding" => {
                  "uuids" => { "newly_detected" => [resolved_finding_uuid] }
                }
              }
            })

            dismiss_policy_violations

            policy_dismissal = Security::PolicyDismissal.find_by(
              security_policy: security_policy,
              merge_request: merge_request
            )

            expect(policy_dismissal).to be_present

            unrelated_uuid = SecureRandom.uuid
            violation.update!(violation_data: {
              "violations" => {
                "scan_finding" => {
                  "uuids" => { "newly_detected" => [resolved_finding_uuid, unrelated_uuid] }
                }
              }
            })

            expect { policy_dismissal.preserve! }.not_to change { AuditEventReader.count }

            expect(Security::PolicyDismissal.find_by(id: policy_dismissal.id)).to be_nil
          end
        end

        context 'when vulnerability is created after merge' do
          let_it_be(:vulnerability) do
            create(:vulnerability, :detected, :secret_detection,
              title: 'AWS access token',
              project: project)
          end

          let_it_be(:vulnerability_finding) do
            create(:vulnerabilities_finding,
              vulnerability: vulnerability,
              project: project,
              uuid: finding_uuid,
              report_type: :secret_detection)
          end

          it 'shows the vulnerability in the vulnerability report and creates an audit event', :aggregate_failures do
            resolved_finding_uuid = vulnerability.vulnerability_finding.uuid

            violation.update!(violation_data: {
              "violations" => {
                "scan_finding" => {
                  "uuids" => { "newly_detected" => [resolved_finding_uuid] }
                }
              }
            })

            dismiss_policy_violations

            policy_dismissal = Security::PolicyDismissal.find_by(
              security_policy: security_policy,
              merge_request: merge_request
            )

            expect { policy_dismissal.preserve! }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author_id: user.id,
              entity_id: project.id,
              entity_type: 'Project',
              details: hash_including(
                custom_message: "Merge request #{merge_request.to_reference} was merged with violated security policy."
              )
            )

            # Use rack_test to avoid JS asset loading flakiness and read server-rendered payloads.
            Capybara.using_driver(:rack_test) do
              visit(project_security_vulnerability_path(project, vulnerability))

              vulnerability_payload = Gitlab::Json.safe_parse(
                find('#js-vulnerability-main', visible: false)['data-vulnerability']
              )

              expect(vulnerability_payload['policy_dismissals']).to include(
                hash_including('comment' => bypass_comment)
              )
            end
          end
        end
      end
    end
  end

  private

  def dismiss_policy_violations(policy_ids: [security_policy.id])
    Security::ScanResultPolicies::DismissPolicyViolationsService.new(
      merge_request,
      current_user: user,
      params: {
        security_policy_ids: policy_ids,
        comment: bypass_comment,
        dismissal_types: [Security::PolicyDismissal::DISMISSAL_TYPES[:emergency_hot_fix]]
      }
    ).execute
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncAnyMergeRequestRulesService, feature_category: :security_policy_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let(:service) { described_class.new(merge_request) }
  let_it_be_with_reload(:merge_request) { create(:ee_merge_request, source_project: project) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:approvals_required) { 1 }
    let(:signed_commit) { instance_double(Commit, has_signature?: true, short_id: 'abcd1234') }
    let(:unsigned_commit) { instance_double(Commit, has_signature?: false, short_id: 'dcba5678') }
    let_it_be(:protected_branch, freeze: false) do
      create(:protected_branch, name: merge_request.target_branch, project: project)
    end

    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let_it_be(:security_policy) do
      create(:security_policy,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:any_mr_approval_policy_rule, reload: true) do
      rule = create(:approval_policy_rule, :any_merge_request, security_policy: security_policy, rule_index: 0)
      create(:approval_policy_rule_project_link, project: project, approval_policy_rule: rule)
      rule
    end

    let_it_be(:scan_result_policy_read, reload: true) do
      create(:scan_result_policy_read, project: project,
        approval_policy_rule: any_mr_approval_policy_rule,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let!(:approval_project_rule) do
      create(:approval_project_rule, :any_merge_request, project: project, approvals_required: approvals_required,
        applies_to_all_protected_branches: true, protected_branches: [protected_branch],
        scan_result_policy_read: scan_result_policy_read,
        approval_policy_rule: any_mr_approval_policy_rule)
    end

    let!(:approver_rule) do
      create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
        approval_project_rule: approval_project_rule, approvals_required: approvals_required,
        scan_result_policy_read: scan_result_policy_read,
        approval_policy_rule: any_mr_approval_policy_rule)
    end

    shared_examples_for 'does not update approval rules' do
      it 'does not update approval rules' do
        expect { execute }.not_to change { approver_rule.reload.approvals_required }
      end
    end

    shared_examples_for 'sets approvals_required to 0' do
      it 'sets approvals_required to 0' do
        expect { execute }.to change { approver_rule.reload.approvals_required }.to(0)
      end
    end

    context 'when merge_request is merged' do
      before do
        merge_request.update!(state: 'merged')
      end

      it_behaves_like 'does not update approval rules'
      it_behaves_like 'does not trigger policy bot comment'

      it 'creates no violation records' do
        expect { execute }.not_to change { merge_request.scan_result_policy_violations.count }
      end

      it 'does not create a log' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)

        execute
      end
    end

    describe 'approval rules' do
      context 'without violations' do
        context 'when policy targets unsigned commits and there are only signed commits in merge request' do
          before do
            scan_result_policy_read.update!(commits: :unsigned)
            any_mr_approval_policy_rule.update!(
              content: any_mr_approval_policy_rule.content.merge('commits' => 'unsigned'))
            allow(merge_request).to receive(:commits).and_return([signed_commit])
          end

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', false
          it_behaves_like 'merge request without scan result violations'
          it_behaves_like 'does not trigger policy bot comment for archived project' do
            let(:archived_project) { merge_request.project }
          end

          it 'logs only the evaluation and not a violated rule' do
            expect(Gitlab::AppJsonLogger).to receive(:info).with(
              hash_including(message: 'Evaluating any_merge_request rules from approval policies')
            )

            execute
          end
        end

        context 'when target branch is not protected' do
          before do
            scan_result_policy_read.update!(commits: :any)
            any_mr_approval_policy_rule.update!(
              content: any_mr_approval_policy_rule.content.merge('commits' => 'any'))
            merge_request.update!(target_branch: 'non-protected')
          end

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', false
          it_behaves_like 'merge request without scan result violations'
          it_behaves_like 'does not trigger policy bot comment for archived project' do
            let(:archived_project) { merge_request.project }
          end
        end
      end

      context 'with violations' do
        let(:policy_commits) { :any }
        let(:merge_request_commits) { [unsigned_commit] }

        before do
          scan_result_policy_read.update!(commits: policy_commits)
          any_mr_approval_policy_rule.update!(
            content: any_mr_approval_policy_rule.content.merge('commits' => policy_commits&.to_s))
          allow(merge_request).to receive(:commits).and_return(merge_request_commits)
        end

        describe 'branch exceptions' do
          let(:approval_policy) do
            build(:approval_policy,
              rules: [{
                type: Security::ScanResultPolicy::ANY_MERGE_REQUEST,
                branches: ['protected'],
                branch_exceptions: branch_exceptions,
                commits: 'any'
              }])
          end

          let(:policy_yaml) do
            build(:orchestration_policy_yaml, approval_policy: [approval_policy])
          end

          subject(:violation_exists?) do
            Security::ScanResultPolicyViolation
              .exists?(merge_request_id: merge_request.id, scan_result_policy_id: scan_result_policy_read.id)
          end

          before do
            scan_result_policy_read.update!(rule_idx: 0)

            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
            end

            execute
          end

          where(:branch_exceptions, :violated?) do
            [lazy { merge_request.target_branch }]                                                         | false
            [lazy { merge_request.target_branch.reverse }]                                                 | true
            [lazy { { name: merge_request.target_branch,         full_path: project.full_path } }]         | false
            [lazy { { name: merge_request.target_branch.reverse, full_path: project.full_path } }]         | true
            [lazy { { name: merge_request.target_branch,         full_path: project.full_path.reverse } }] | true
          end

          with_them do
            it { is_expected.to be(violated?) }
          end
        end

        describe 'skipping the branch computation when the policy already has approval rules' do
          let(:branch_service) { Security::SecurityOrchestrationPolicies::PolicyBranchesService }

          let(:approval_policy) do
            build(:approval_policy,
              rules: [{
                type: Security::ScanResultPolicy::ANY_MERGE_REQUEST,
                branches: [],
                commits: 'any'
              }])
          end

          let(:policy_yaml) do
            build(:orchestration_policy_yaml, approval_policy: [approval_policy])
          end

          before do
            scan_result_policy_read.update!(rule_idx: 0)

            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
            end
          end

          context 'when the current merge request already has an approval rule for the policy' do
            it 'short-circuits and does not compute the policy branches' do
              expect(branch_service).not_to receive(:new)

              execute
            end

            it_behaves_like 'merge request with scan result violations'
            it_behaves_like 'triggers policy bot comment', true
          end

          context 'when only another merge request has an approval rule for the policy' do
            let!(:approver_rule) { nil }

            let_it_be(:other_merge_request) do
              create(:ee_merge_request, source_project: project, target_branch: 'other')
            end

            before do
              create(:report_approver_rule, :any_merge_request, merge_request: other_merge_request,
                approval_project_rule: approval_project_rule, approvals_required: 1,
                scan_result_policy_read: scan_result_policy_read,
                approval_policy_rule: any_mr_approval_policy_rule)
            end

            it 'does not short-circuit and computes the policy branches for the current merge request' do
              expect_next_instance_of(branch_service) do |instance|
                expect(instance).to receive(:scan_result_branches).and_return([merge_request.target_branch])
              end

              execute
            end

            it_behaves_like 'merge request with scan result violations'
          end
        end

        context 'when approvals are optional' do
          let(:approvals_required) { 0 }

          it_behaves_like 'does not update approval rules'
          it_behaves_like 'triggers policy bot comment', true
          it_behaves_like 'does not trigger policy bot comment for archived project' do
            let(:archived_project) { merge_request.project }
          end
        end

        context 'when approvals are required but approval_merge_request_rules have been made optional' do
          let!(:approval_project_rule) do
            create(:approval_project_rule, :any_merge_request, project: project, approvals_required: 1,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: any_mr_approval_policy_rule)
          end

          let!(:approver_rule) do
            create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
              approval_project_rule: approval_project_rule, approvals_required: 0,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: any_mr_approval_policy_rule)
          end

          it 'resets the required approvals' do
            expect { execute }.to change { approver_rule.reload.approvals_required }.to(1)
          end

          it_behaves_like 'triggers policy bot comment', true
          it_behaves_like 'does not trigger policy bot comment for archived project' do
            let(:archived_project) { merge_request.project }
          end
        end

        where(:policy_commits, :merge_request_commits, :expected_violation) do
          :unsigned | [ref(:unsigned_commit)] | ['dcba5678']
          :unsigned | [ref(:signed_commit), ref(:unsigned_commit)] | ['dcba5678']
          :any      | [ref(:signed_commit)] | true
          :any      | [ref(:unsigned_commit)] | true
        end

        with_them do
          it_behaves_like 'does not update approval rules'
          it_behaves_like 'triggers policy bot comment', true
          it_behaves_like 'merge request with scan result violations'

          it 'logs violated rules' do
            expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
              message: 'Evaluating any_merge_request rules from approval policies'))
            expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(message: 'Updating MR approval rule'))

            execute
          end

          it 'persists violation details' do
            expect { execute }
              .to change { merge_request.scan_result_policy_violations.last&.violation_data }
                              .from(nil)
                              .to('violations' => { 'any_merge_request' => { 'commits' => expected_violation } })
          end

          it_behaves_like 'when no policy is applicable due to the policy scope' do
            it_behaves_like 'does not update approval rules'
          end
        end

        context 'when deprecate_scan_result_policies is disabled' do
          before do
            stub_feature_flags(deprecate_scan_result_policies: false)
          end

          it_behaves_like 'does not update approval rules'
          it_behaves_like 'merge request with scan result violations'
        end
      end

      describe 'policies with no approval rules' do
        let!(:approver_rule) { nil }

        context 'when policies target commits' do
          let(:violation) { merge_request.scan_result_policy_violations.first }

          let_it_be(:commits_security_policy) do
            create(:security_policy,
              security_orchestration_policy_configuration: policy_configuration,
              policy_index: 2)
          end

          let_it_be(:commits_approval_policy_rule) do
            rule = create(:approval_policy_rule, :any_merge_request,
              security_policy: commits_security_policy, rule_index: 0,
              content: { 'type' => 'any_merge_request', 'branches' => [], 'commits' => 'unsigned' })
            create(:approval_policy_rule_project_link, project: project, approval_policy_rule: rule)
            rule
          end

          let_it_be(:scan_result_policy_read_with_commits, reload: true) do
            create(:scan_result_policy_read, project: project, commits: :unsigned, rule_idx: 0,
              approval_policy_rule: commits_approval_policy_rule,
              security_orchestration_policy_configuration: policy_configuration)
          end

          before do
            # Remove the outer APR's project link so only commits_approval_policy_rule is found
            Security::ApprovalPolicyRuleProjectLink
              .where(approval_policy_rule: any_mr_approval_policy_rule, project: project).delete_all
            allow(merge_request).to receive(:commits).and_return([unsigned_commit])
          end

          it 'creates violations for policies that have no approval rules' do
            expect { execute }.to change { merge_request.scan_result_policy_violations.count }.by(1)
            expect(violation.scan_result_policy_read).to(eq scan_result_policy_read_with_commits)
            expect(violation.violation_data)
              .to match('violations' => { 'any_merge_request' => { 'commits' => ['dcba5678'] } })
          end

          context 'with previous violation for policy that is now unviolated' do
            let!(:unrelated_violation) do
              create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read_with_commits,
                approval_policy_rule: commits_approval_policy_rule,
                merge_request: merge_request)
            end

            before do
              allow(merge_request).to receive(:commits).and_return([signed_commit])
            end

            it 'removes the violation record' do
              expect { execute }.to change { merge_request.scan_result_policy_violations.count }.by(-1)
            end
          end

          context 'when target branch is not protected' do
            let(:approval_policy) { build(:approval_policy, :any_merge_request, branches: ['protected']) }
            let(:dummy_policy) { build(:approval_policy, :any_merge_request, branches: []) }
            let(:policy_yaml) do
              # commits_security_policy has policy_index: 2, so the approval_policy must be at index 2
              build(:orchestration_policy_yaml, approval_policy: [dummy_policy, dummy_policy, approval_policy])
            end

            before do
              merge_request.update!(target_branch: 'non-protected')
              allow_next_instance_of(Repository) do |repository|
                allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
              end
            end

            it_behaves_like 'triggers policy bot comment', false
            it_behaves_like 'merge request without scan result violations' do
              let(:scan_result_policy_read) { scan_result_policy_read_with_commits }
            end

            it_behaves_like 'does not trigger policy bot comment for archived project' do
              let(:archived_project) { merge_request.project }
            end
          end

          context 'when there are other approval rules' do
            let_it_be(:scan_finding_project_rule) do
              create(:approval_project_rule, :scan_finding, project: project,
                scan_result_policy_read: scan_result_policy_read_with_commits, approvals_required: 1)
            end

            let!(:another_approver_rule) { approver_rule }

            let_it_be(:license_scanning_project_rule) do
              create(:approval_project_rule, :scan_finding, project: project,
                scan_result_policy_read: scan_result_policy_read_with_commits, approvals_required: 1)
            end

            let_it_be(:scan_finding_merge_request_rule) do
              create(:report_approver_rule, :scan_finding, merge_request: merge_request,
                approval_project_rule: scan_finding_project_rule, approvals_required: 0,
                scan_result_policy_read: scan_result_policy_read_with_commits)
            end

            let_it_be(:license_scanning_merge_request_rule) do
              create(:report_approver_rule, :license_scanning, merge_request: merge_request,
                approval_project_rule: license_scanning_project_rule, approvals_required: 0,
                scan_result_policy_read: scan_result_policy_read_with_commits)
            end

            it 'does not reset required approvals' do
              execute

              expect(scan_finding_merge_request_rule.reload.approvals_required).to eq 0
              expect(license_scanning_merge_request_rule.reload.approvals_required).to eq 0
            end
          end
        end

        context 'when the policies are not targeting commits' do
          before do
            scan_result_policy_read.update!(commits: nil)
            Security::ApprovalPolicyRuleProjectLink
              .where(approval_policy_rule: any_mr_approval_policy_rule, project: project).delete_all
          end

          it_behaves_like 'merge request without scan result violations', previous_violation: false
        end
      end
    end

    context 'when storing violation detail data' do
      let(:policy_commits) { :unsigned }
      let(:max_array_limit) { 2 }
      let(:merge_request_commits) { Array.new(max_array_limit + 3) { unsigned_commit } }

      before do
        stub_const('Security::ScanResultPolicyViolationDetail::MAX_ARRAY_LIMIT', max_array_limit)

        scan_result_policy_read.update!(commits: policy_commits)
        any_mr_approval_policy_rule.update!(
          content: any_mr_approval_policy_rule.content.merge('commits' => policy_commits.to_s))
        allow(merge_request).to receive(:commits).and_return(merge_request_commits)
      end

      it 'stores trimmed commit shas in the violation detail row' do
        execute

        detail = Security::ScanResultPolicyViolationDetail.order(:id).last
        expect(detail.commit_shas).to eq(merge_request_commits.first(max_array_limit).map(&:short_id))
      end

      it 'stores total commit count in violation detail metadata' do
        execute

        detail = Security::ScanResultPolicyViolationDetail.order(:id).last
        expect(detail.metadata).to include('total_commit_shas_count' => merge_request_commits.size)
      end

      context 'when policy targets any commits (not unsigned)' do
        let(:policy_commits) { :any }

        it 'does not create violation details' do
          expect { execute }.not_to change { Security::ScanResultPolicyViolationDetail.count }
        end
      end

      context 'when the feature flag is disabled' do
        let(:policy_commits) { :unsigned }

        before do
          stub_feature_flags(dual_write_scan_result_policy_violation_details: false)
        end

        it 'does not create violation details' do
          expect { execute }.not_to change { Security::ScanResultPolicyViolationDetail.count }
        end
      end
    end
  end
end

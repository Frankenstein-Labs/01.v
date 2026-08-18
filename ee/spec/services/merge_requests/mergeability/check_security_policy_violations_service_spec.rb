# frozen_string_literal: true

require "spec_helper"

RSpec.describe MergeRequests::Mergeability::CheckSecurityPolicyViolationsService, feature_category: :code_review_workflow do
  subject(:check_policies) { described_class.new(merge_request: merge_request, params: params) }

  let(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:project) { create(:project) }
  let(:params) { { skip_security_policy_check: skip_check } }
  let(:skip_check) { false }

  it_behaves_like 'mergeability check service', :security_policy_violations,
    'Checks whether the security policies are satisfied'

  describe "#execute" do
    let(:result) { check_policies.execute }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'with no scan result policies' do
      it 'returns a check result with inactive status' do
        expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      end
    end

    context 'when only legacy scan_result_policy_read-linked approval rules exist' do
      let(:policy) { create(:scan_result_policy_read, project: project) }

      before do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: policy, approval_policy_rule: nil, name: 'Legacy policy')
      end

      it 'detects policy rules via the legacy association when FF is enabled' do
        expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
      end
    end

    context 'when scan result policy exists' do
      let(:policy) { create(:scan_result_policy_read, :with_approval_policy_rule, project: project) }

      before do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: policy, approval_policy_rule: policy.approval_policy_rule, name: 'Policy 1')
      end

      context 'when deprecate_scan_result_policies flag is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        it 'detects policy rules via scan_result_policy_reads' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end

      context 'when security_orchestration_policies license is false' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'returns a check result with inactive status' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end

      context 'when scan result violations are failed' do
        before do
          create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
            scan_result_policy_read: policy, violation_data: nil)
        end

        context 'when the MR is not approved' do
          before do
            create(:report_approver_rule, merge_request: merge_request, approvals_required: 1, users: [create(:user)])
          end

          it "returns a check result with status failure" do
            expect(result.status)
              .to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
            expect(result.payload[:identifier]).to eq(:security_policy_violations)
          end
        end

        context 'when the MR is approved' do
          it "returns check result with status success" do
            expect(result.status)
              .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
          end
        end
      end

      context 'when no scan result violations exist' do
        it "returns check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end

      context 'when scan result violations are running' do
        before do
          create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
            scan_result_policy_read: policy, violation_data: nil)
        end

        it "returns a check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
        end
      end

      context 'when scan result violations are only warning' do
        before do
          create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
            scan_result_policy_read: policy, violation_data: nil)
        end

        it "returns a check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end

      context 'when some scan result policy violations are dismissed' do
        let(:security_policy_1) { create(:security_policy) }
        let(:approval_policy_rule_1) { create(:approval_policy_rule, security_policy: security_policy_1) }
        let!(:violation_1) do
          create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
            scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule_1,
            violation_data: {
              'violations' => {
                'scan_finding' => {
                  'uuids' => {
                    'newly_detected' => %w[uuid-1 uuid-2]
                  }
                }
              }
            })
        end

        let(:policy_2) { create(:scan_result_policy_read, project: project) }
        let(:security_policy_2) { create(:security_policy) }
        let(:approval_policy_rule_2) { create(:approval_policy_rule, security_policy: security_policy_2) }
        let!(:violation_2) do
          create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
            scan_result_policy_read: policy_2, approval_policy_rule: approval_policy_rule_2)
        end

        it 'returns a check result with status warning' do
          create(:policy_dismissal,
            security_policy: security_policy_1,
            merge_request: merge_request,
            project: project,
            security_findings_uuids: %w[uuid-1 uuid-2])

          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::WARNING_STATUS

          expect(result.payload[:identifier]).to eq(:security_policy_violations)
        end

        it 'does not produce N+1 queries when checking dismissals' do
          control_count = ActiveRecord::QueryRecorder.new do
            check_policies.execute
          end

          policy_3 = create(:scan_result_policy_read, project: project)
          security_policy_3 = create(:security_policy)
          approval_policy_rule_3 = create(:approval_policy_rule, security_policy: security_policy_3)

          create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
            scan_result_policy_read: policy_3, approval_policy_rule: approval_policy_rule_3)

          create(:policy_dismissal,
            security_policy: security_policy_3,
            merge_request: merge_request,
            project: project)

          expect { check_policies.execute }.not_to exceed_query_limit(control_count)
        end
      end

      context 'when security policy is bypassed' do
        let_it_be(:user) { create(:user) }
        let_it_be(:security_policy) do
          create(:security_policy, :approval_policy,
            linked_projects: [project],
            bypass_user_ids: [user.id]
          )
        end

        let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

        let!(:approval_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            name: 'Bypass rule',
            approval_policy_rule: approval_policy_rule
          )
        end

        before do
          create(:approval_policy_merge_request_bypass_event,
            security_policy: security_policy,
            project: merge_request.project,
            merge_request: merge_request,
            user: user,
            reason: 'Test bypass')
        end

        it "returns a check result with status warning" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::WARNING_STATUS
        end
      end
    end
  end

  describe '#skip?' do
    subject { check_policies.skip? }

    context 'when skip check is true' do
      let(:skip_check) { true }

      it { is_expected.to be true }
    end

    context 'when skip check is false' do
      let(:skip_check) { false }

      it { is_expected.to be false }
    end
  end

  describe '#cacheable?' do
    it 'returns false' do
      expect(check_policies.cacheable?).to be false
    end
  end
end

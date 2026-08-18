# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PostMergeService, feature_category: :code_review_workflow do
  let_it_be_with_refind(:project) { create(:project) }
  # Works around https://gitlab.com/gitlab-org/gitlab/-/issues/335054
  let_it_be_with_refind(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  let(:current_user) { merge_request.author }
  let(:params) { {} }
  let(:service) { described_class.new(project: project, current_user: current_user, params: params) }

  subject(:execute) { service.execute(merge_request) }

  describe '#execute' do
    context 'when the merge request is already merged' do
      before do
        merge_request.mark_as_merged!
      end

      it 'returns early without running EE post-merge logic' do
        expect(ApprovalRules::FinalizeService).not_to receive(:new)

        execute
      end
    end

    context 'merged event' do
      it 'publishes to the MergedEvent' do
        expect(::Gitlab::EventStore).to receive(:publish)
        expect(MergeRequests::MergedEvent).to receive(:new)

        execute
      end
    end

    context 'finalize approvals' do
      let(:finalize_service) { double(:finalize_service) }

      it 'executes ApprovalRules::FinalizeService' do
        expect(ApprovalRules::FinalizeService).to receive(:new).and_return(finalize_service)
        expect(finalize_service).to receive(:execute)

        execute
      end
    end

    context 'compliance violations' do
      shared_examples 'does not call the compliance violations worker' do
        it do
          expect(ComplianceManagement::MergeRequests::ComplianceViolationsWorker).not_to receive(:perform_async)

          execute
        end
      end

      context 'when the compliance center feature is unlicensed' do
        before do
          stub_licensed_features(group_level_compliance_dashboard: false)
        end

        it_behaves_like 'does not call the compliance violations worker'
      end

      context 'when the compliance center feature is licensed' do
        before do
          stub_licensed_features(group_level_compliance_dashboard: true)
        end

        it 'calls the compliance violations worker asynchronously' do
          expect(ComplianceManagement::MergeRequests::ComplianceViolationsWorker).to receive(:perform_async).with(merge_request.id)

          execute
        end
      end
    end

    context 'auditing and tracking invalid logs' do
      shared_examples 'auditing invalid logs' do
        let(:expected_params) do
          {
            name: 'merge_request_invalid_approver_rules',
            author: merge_request.author,
            scope: merge_request.project,
            target: merge_request,
            target_details: {
              title: merge_request.title,
              iid: merge_request.iid,
              id: merge_request.id,
              rule_type: rule.rule_type,
              rule_name: rule.name
            },
            message: 'Invalid merge request approver rules'
          }
        end

        context 'when the rule is valid' do
          let!(:rule) { valid_rule }

          it 'does not audit or track the event' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)
            expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter).not_to receive(:track_invalid_approvers)

            execute
          end
        end

        context 'when invalid' do
          let!(:rule) { invalid_rule }

          it 'audits and tracks logs the event' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_params)
            expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter).to receive(:track_invalid_approvers).with(merge_request: merge_request)

            execute
          end
        end
      end

      context 'when the rule is code owner' do
        let(:valid_rule) { create(:code_owner_rule, merge_request: merge_request, users: create_list(:user, 1)) }
        let(:invalid_rule) { create(:code_owner_rule, merge_request: merge_request) }

        before do
          stub_licensed_features(code_owner_approval_required: true)
          create(:protected_branch, project: project, name: merge_request.target_branch, code_owner_approval_required: true)
        end

        include_examples 'auditing invalid logs'
      end

      context 'when the rule is any_approver' do
        context 'when the rule is valid' do
          let!(:rule) { create(:any_approver_rule, merge_request: merge_request, users: create_list(:user, 1)) }

          it 'does not audit or track the event' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)
            expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter).not_to receive(:track_invalid_approvers)

            execute
          end
        end

        context 'when invalid' do
          let!(:rule) { create(:any_approver_rule, merge_request: merge_request, approvals_required: 1) }

          it 'does not audit or track the event' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)
            expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter).not_to receive(:track_invalid_approvers)

            execute
          end
        end
      end

      context 'when the rule is approval_merge_request_rule' do
        let(:valid_rule) { create(:approval_merge_request_rule, merge_request: merge_request, users: create_list(:user, 1)) }
        let(:invalid_rule) { create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: 1) }

        include_examples 'auditing invalid logs'
      end

      context 'when the rule is report_approver' do
        let(:valid_rule) { create(:report_approver_rule, merge_request: merge_request, users: create_list(:user, 1)) }
        let(:invalid_rule) { create(:report_approver_rule, merge_request: merge_request, approvals_required: 1) }

        include_examples 'auditing invalid logs'
      end
    end

    context 'with security orchestration policy configuration' do
      let(:security_orchestration_enabled) { true }
      let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: main_project, security_policy_management_project: project) }

      let_it_be(:main_project) { create(:project) }
      let_it_be(:another_project) { create(:project) }
      let_it_be(:another_policy_configuration) { create(:security_orchestration_policy_configuration, project: another_project, security_policy_management_project: project) }

      before do
        stub_licensed_features(security_orchestration_policies: security_orchestration_enabled)
      end

      it 'executes Security::SyncScanResultPolicyWorker for each configuration project' do
        expect(Security::SyncScanPoliciesWorker).to receive(:perform_async).with(policy_configuration.id)
        expect(Security::SyncScanPoliciesWorker).to receive(:perform_async).with(another_policy_configuration.id)

        execute
      end

      it 'executes Security::ScanResultPolicies::FailOpenTrackingService' do
        expect(Security::ScanResultPolicies::FallbackBehaviorTrackingWorker).to receive(:perform_async).with(merge_request.id)

        execute
      end

      context 'without licensed feature' do
        let(:security_orchestration_enabled) { false }

        it 'does not execute Security::SyncScanResultPolicyWorker for each configuration project' do
          expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

          execute
        end

        it 'does not execute Security::ScanResultPolicies::FailOpenTrackingService' do
          expect(Security::ScanResultPolicies::FallbackBehaviorTrackingWorker).not_to receive(:perform_async)

          execute
        end
      end

      context 'with unrelated policy configurations' do
        let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: main_project, security_policy_management_project: unrelated_project) }

        let_it_be(:unrelated_project) { create(:project) }

        it 'does not execute Security::SyncScanResultPolicyWorker for each configuration project' do
          expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async).with(policy_configuration.id)

          execute
        end
      end
    end

    context 'when merge request is a blocker for other merge requests' do
      let(:blocked_mr_1) { create(:merge_request) }
      let(:blocked_mr_2) { create(:merge_request) }

      before do
        create(:merge_request_block, blocking_merge_request: merge_request, blocked_merge_request: blocked_mr_1)
        create(:merge_request_block, blocking_merge_request: merge_request, blocked_merge_request: blocked_mr_2)
      end

      it 'triggers GraphQL subscription mergeRequestMergeStatusUpdated for each blocked merge request' do
        expect(GraphqlTriggers).not_to receive(:merge_request_merge_status_updated).with(merge_request)
        expect(GraphqlTriggers).to receive(:merge_request_merge_status_updated).with(blocked_mr_1)
        expect(GraphqlTriggers).to receive(:merge_request_merge_status_updated).with(blocked_mr_2)

        execute
      end

      context 'when merge_when_checks_pass is enabled' do
        it 'sends an unblocked event for the first blocked merge request' do
          expect { execute }.to publish_event(MergeRequests::UnblockedStateEvent).with({
            current_user_id: current_user.id,
            merge_request_id: blocked_mr_1.id
          })
        end

        it 'sends an unblocked event for the second blocked merge request' do
          expect { execute }.to publish_event(MergeRequests::UnblockedStateEvent).with({
            current_user_id: current_user.id,
            merge_request_id: blocked_mr_2.id
          })
        end

        it 'does send any additional unblocked events' do
          expect(::Gitlab::EventStore).to receive(:publish).exactly(3).times

          execute
        end
      end
    end

    context 'when a temporary unapproval is needed for the MR' do
      it 'removes the unmergeable flag after the service is run' do
        merge_request.approval_state.temporarily_unapprove!

        execute

        merge_request.reload

        expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
      end
    end

    context 'for audit events' do
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be_with_reload(:merge_request) { create(:merge_request, author: project_bot) }

      include_examples 'audit event logging' do
        let(:operation) { execute }
        let(:event_type) { 'merge_request_merged_by_project_bot' }
        let(:fail_condition!) { expect(merge_request.author).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: merge_request.target_project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'merge_request_merged_by_project_bot',
              target_id: merge_request.id,
              target_type: 'MergeRequest',
              target_details: {
                iid: merge_request.iid,
                id: merge_request.id,
                source_branch: merge_request.source_branch,
                target_branch: merge_request.target_branch,
                merge_commit_sha: merge_request.merge_commit_sha
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Merged merge request #{merge_request.title}"
            }
          }
        end
      end
    end

    context 'for vulnerability resolution tracking' do
      let_it_be_with_refind(:merge_request) do
        create(:merge_request, :unique_branches, source_project: project, target_project: project)
      end

      context 'when merge request was created by agentic vulnerability resolution' do
        before do
          allow(merge_request).to receive(:created_by_agentic_vr?).and_return(true)
        end

        it 'tracks the merge_vulnerability_resolution_merge_request event' do
          expect { execute }
            .to trigger_internal_events('merge_vulnerability_resolution_merge_request')
                  .with(
                    project: project,
                    additional_properties: {
                      value: merge_request.id
                    })
                  .and increment_usage_metrics('counts.count_total_merge_vulnerability_resolution_merge_request')
        end
      end

      context 'when merge request was not created by agentic vulnerability resolution' do
        before do
          allow(merge_request).to receive(:created_by_agentic_vr?).and_return(false)
        end

        it 'does not track the event' do
          expect { execute }
            .to not_trigger_internal_events('merge_vulnerability_resolution_merge_request')
        end
      end
    end

    context 'for activation event tracking' do
      it 'tracks the merged_mr internal event' do
        expect { execute }
          .to trigger_internal_events('merged_mr')
                .with(
                  user: merge_request.author,
                  project: merge_request.target_project,
                  namespace: merge_request.target_project.namespace
                )
      end
    end
  end
end

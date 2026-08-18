# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::SyncMergeRequestsService, feature_category: :security_policy_management do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:policy_configuration, freeze: false) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:group_policy_configuration, freeze: false) do
    create(:security_orchestration_policy_configuration, project: nil, namespace: group)
  end

  let_it_be(:security_policy, freeze: false) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:approval_policy_rule, freeze: false) do
    create(:approval_policy_rule, security_policy: security_policy)
  end

  let_it_be(:container_scanning_project_approval_rule, freeze: false) do
    create(:approval_project_rule, :scan_finding,
      project: project,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration,
      scanners: %w[container_scanning]
    )
  end

  let_it_be(:sast_project_approval_rule, freeze: false) do
    create(:approval_project_rule, :scan_finding,
      project: project,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration,
      scanners: %w[sast]
    )
  end

  let_it_be(:project_approval_rule_from_group, freeze: false) do
    create(:approval_project_rule, :scan_finding,
      project: project,
      security_orchestration_policy_configuration: group_policy_configuration,
      scanners: %w[sast]
    )
  end

  let_it_be(:approval_policy_rule_project_link, freeze: false) do
    create(:approval_policy_rule_project_link,
      project: project,
      approval_policy_rule: approval_policy_rule
    )
  end

  let_it_be(:draft_merge_request, freeze: false) do
    create(:merge_request, :draft_merge_request, source_project: project, source_branch: "draft")
  end

  let_it_be(:opened_merge_request, freeze: false) { create(:merge_request, :opened, source_project: project) }
  let_it_be(:merged_merge_request, freeze: false) { create(:merge_request, :merged, source_project: project) }
  let_it_be(:closed_merge_request, freeze: false) { create(:merge_request, :closed, source_project: project) }

  let_it_be(:protected_branch, freeze: false) do
    create(:protected_branch, project: project, name: opened_merge_request.target_branch)
  end

  let_it_be(:opened_mr_rule, freeze: false) do
    create(:report_approver_rule, :scan_finding,
      merge_request: opened_merge_request,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration
    )
  end

  let_it_be(:draft_mr_rule, freeze: false) do
    create(:report_approver_rule, :scan_finding,
      merge_request: draft_merge_request,
      approval_policy_rule: approval_policy_rule,
      security_orchestration_policy_configuration: policy_configuration
    )
  end

  before do
    create(:approval_merge_request_rule_source,
      approval_merge_request_rule: opened_mr_rule,
      approval_project_rule: container_scanning_project_approval_rule
    )
    create(:approval_merge_request_rule_source,
      approval_merge_request_rule: draft_mr_rule,
      approval_project_rule: container_scanning_project_approval_rule
    )
  end

  describe "#execute" do
    subject(:execute) { described_class.new(project: project, security_policy: security_policy).execute }

    context 'without head_pipeline for merge request' do
      it 'does not trigger workers' do
        expect(::Ci::SyncReportsToReportApprovalRulesWorker).not_to receive(:perform_async)
        expect(::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker)
          .not_to receive(:bulk_perform_in_with_contexts)

        execute
      end
    end

    describe 'fail-open rules' do
      it 'unblocks fail-open rules' do
        expect(::Security::ScanResultPolicies::UnblockFailOpenApprovalRulesWorker).to receive(:perform_async).twice

        execute
      end
    end

    context 'with head_pipeline' do
      let(:head_pipeline) { create(:ci_pipeline, project: project, ref: opened_merge_request.source_branch) }

      before do
        opened_merge_request.update!(head_pipeline_id: head_pipeline.id)
      end

      it 'triggers both workers' do
        expect(::Ci::SyncReportsToReportApprovalRulesWorker).to receive(:perform_async).with(head_pipeline.id)

        expect(::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker)
          .to receive(:bulk_perform_in_with_contexts) do |delay, batch, arguments_proc:, context_proc:|
            expect(delay).to eq(described_class::PIPELINES_BATCH_BASE_DELAY)
            expect(batch).to eq([head_pipeline.id])
            expect(arguments_proc.call(head_pipeline.id)).to eq([head_pipeline.id])
            expect(context_proc.call(head_pipeline.id)).to eq(project: project)
          end

        execute
      end

      context 'when pipelines exceed PIPELINES_BATCH_SIZE' do
        let!(:second_head_pipeline) do
          create(:ci_pipeline, project: project, ref: draft_merge_request.source_branch)
        end

        before do
          draft_merge_request.update!(head_pipeline_id: second_head_pipeline.id)
          stub_const("#{described_class}::PIPELINES_BATCH_SIZE", 1)
        end

        it 'schedules findings sync in staggered batches with incremented delays' do
          calls = []

          allow(::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker)
            .to receive(:bulk_perform_in_with_contexts) do |delay, batch, **_|
              calls << [delay, batch]
            end

          execute

          expect(calls.size).to eq(2)
          expect(calls.map(&:first)).to eq([
            described_class::PIPELINES_BATCH_BASE_DELAY,
            described_class::PIPELINES_BATCH_BASE_DELAY + described_class::PIPELINES_BATCH_DELAY
          ])
          expect(calls.flat_map(&:last)).to contain_exactly(head_pipeline.id, second_head_pipeline.id)
        end
      end
    end

    it "synchronizes rules to opened merge requests" do
      execute

      [opened_merge_request, draft_merge_request].each do |mr|
        expect(mr.approval_rules.scan_finding.count).to be(2)
      end
    end

    describe '#notify_for_policy_violations' do
      it 'enqueues UnenforceablePolicyRulesNotificationWorker' do
        expect(::Security::UnenforceablePolicyRulesNotificationWorker).to(
          receive(:perform_async).with(opened_merge_request.id, { 'force_without_approval_rules' => true })
        )
        expect(::Security::UnenforceablePolicyRulesNotificationWorker).to(
          receive(:perform_async).with(draft_merge_request.id, { 'force_without_approval_rules' => true })
        )

        execute
      end
    end

    context "when scan_result_policy_read targets commits" do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, :targeting_commits, project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it "enqueues SyncAnyMergeRequestApprovalRulesWorker with opened merge requests" do
        expect(::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(opened_merge_request.id)
        )
        expect(::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(draft_merge_request.id)
        )

        execute
      end
    end

    context 'when merge request has scan_finding rules' do
      before do
        create(:approval_project_rule, :any_merge_request, :for_all_protected_branches,
          project: project,
          approval_policy_rule: approval_policy_rule,
          security_orchestration_policy_configuration: policy_configuration
        )
      end

      it "enqueues SyncPreexistingStatesApprovalRulesWorker with opened merge requests" do
        expect(::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(opened_merge_request.id)
        )
        expect(::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(draft_merge_request.id)
        )

        execute
      end
    end

    it "does not synchronize rules to merged or closed requests" do
      execute

      [merged_merge_request, closed_merge_request].each do |mr|
        expect(mr.approval_rules.scan_finding.count).to be(0)
      end
    end

    it "does not synchronize rules of another policy configuration" do
      execute

      [opened_merge_request, draft_merge_request].each do |mr|
        expect(mr.approval_rules.map(&:approval_project_rule)).not_to include(project_approval_rule_from_group)
      end
    end

    context "when merge request is synchronized" do
      context "when fully synchronized" do
        it "does not alter rules" do
          expect { execute }.not_to change { opened_merge_request.approval_rules.map(&:attributes) }
        end
      end

      context "when partially synchronized" do
        before do
          opened_merge_request.approval_rules.reload.first.destroy!
        end

        it "creates missing rules" do
          expect { execute }.to change { opened_merge_request.approval_rules.count }.by(2)
        end
      end

      context "when project rule is dirty" do
        let(:states) { %w[detected confirmed] }
        let(:rule) { opened_merge_request.approval_rules.reload.last }

        before do
          sast_project_approval_rule.update_attribute(:vulnerability_states, states)
        end

        it "synchronizes the updated rule" do
          execute

          expect(rule.reload.vulnerability_states).to eq(states)
        end
      end
    end

    it_behaves_like 'policy metrics with logging', described_class::HISTOGRAM do
      let(:expected_logged_data) do
        {
          "class" => described_class.name,
          "duration" => kind_of(Float),
          "project_id" => project.id,
          "configuration_id" => policy_configuration.id
        }
      end
    end
  end
end

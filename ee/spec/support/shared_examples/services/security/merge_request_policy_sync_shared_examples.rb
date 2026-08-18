# frozen_string_literal: true

RSpec.shared_examples_for 'synchronizes policies for a merge request' do
  let_it_be_with_reload(:merge_request) { create(:merge_request) }
  let_it_be(:project, freeze: false) { merge_request.target_project }

  context 'when the merge request has a head_pipeline' do
    let_it_be(:head_pipeline, freeze: false) do
      create(
        :ee_ci_pipeline,
        :with_license_scanning_feature_branch,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha,
        merge_requests_as_head_pipeline: [merge_request]
      )
    end

    it 'schedules background jobs to sync policy approval rules' do
      expect(Ci::SyncReportsToReportApprovalRulesWorker).to receive(:perform_async).ordered.with(head_pipeline.id)
      expect(Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker)
        .to receive(:perform_async).ordered.with(head_pipeline.id, merge_request.id)
      expect(Security::UnenforceablePolicyRulesPipelineNotificationWorker)
        .to receive(:perform_async).ordered.with(head_pipeline.id)

      execute
    end

    it 'does not schedule a background job to check for unenforceable policy rules' do
      expect(::Security::UnenforceablePolicyRulesNotificationWorker).not_to receive(:perform_async)

      execute
    end
  end

  context 'when the merge request does not have a head_pipeline' do
    it 'does not schedule background jobs to sync policy approval rules', :aggregate_failures do
      expect(Ci::SyncReportsToReportApprovalRulesWorker).not_to receive(:perform_async)
      expect(Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker).not_to receive(:perform_async)
      expect(Security::UnenforceablePolicyRulesPipelineNotificationWorker).not_to receive(:perform_async)

      execute
    end

    it 'schedules background job to check for unenforceable policy rules' do
      expect(::Security::UnenforceablePolicyRulesNotificationWorker).to receive(:perform_async)
                                                                          .with(merge_request.id)

      execute
    end
  end

  context 'when a pipeline is being created asynchronously' do
    before do
      allow(merge_request).to receive(:pipeline_creating?).and_return(true)
    end

    it 'does not schedule background job to check for unenforceable policy rules' do
      expect(::Security::UnenforceablePolicyRulesNotificationWorker).not_to receive(:perform_async)

      execute
    end
  end

  context 'when the merge request has a head_pipeline that does not match the diff_head_sha' do
    let_it_be(:stale_pipeline, freeze: false) do
      create(
        :ee_ci_pipeline,
        project: project,
        ref: merge_request.source_branch,
        sha: 'stale_sha_that_does_not_match',
        merge_requests_as_head_pipeline: [merge_request]
      )
    end

    it 'does not schedule background jobs to sync policy approval rules', :aggregate_failures do
      expect(Ci::SyncReportsToReportApprovalRulesWorker).not_to receive(:perform_async)
      expect(Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker).not_to receive(:perform_async)
      expect(Security::UnenforceablePolicyRulesPipelineNotificationWorker).not_to receive(:perform_async)

      execute
    end

    it 'schedules background job to check for unenforceable policy rules' do
      expect(::Security::UnenforceablePolicyRulesNotificationWorker).to receive(:perform_async)
                                                                          .with(merge_request.id)

      execute
    end
  end

  describe 'SyncPreexistingStatesApprovalRulesWorker' do
    context 'when merge request has scan_finding rules' do
      before do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request)
      end

      it 'enqueues SyncPreexistingStatesApprovalRulesWorker worker' do
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request.id)
        )

        execute
      end
    end

    context 'when merge request has license_finding rules' do
      before do
        create(:report_approver_rule, :license_scanning, merge_request: merge_request)
      end

      it 'enqueues SyncPreexistingStatesApprovalRulesWorker worker' do
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request.id)
        )

        execute
      end
    end

    context 'when merge request has no scan_finding or license_finding rules' do
      it 'does not enqueue SyncPreexistingStatesApprovalRulesWorker worker' do
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).not_to(
          receive(:perform_async)
        )

        execute
      end
    end
  end

  describe 'SyncAnyMergeRequestApprovalRulesWorker' do
    context 'when merge request has scan_result_policy_reads targeting commits' do
      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read, :targeting_commits, project: project)
      end

      it 'enqueues SyncAnyMergeRequestApprovalRulesWorker' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request.id)
        )

        execute
      end
    end

    context 'when merge request has no scan_result_policy_reads targeting commits' do
      it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to(
          receive(:perform_async)
        )

        execute
      end
    end
  end
end

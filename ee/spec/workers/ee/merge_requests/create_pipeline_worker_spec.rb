# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreatePipelineWorker, "#execute", feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let(:worker) { Security::UnenforceablePolicyRulesNotificationWorker }

  subject(:perform) { described_class.new.perform(project.id, project.owner.id, merge_request.id) }

  before do
    stub_licensed_features(security_orchestration_policies: true)

    allow(merge_request).to receive(:diff_head_pipeline).and_return(pipeline)

    allow_next_found_instance_of(MergeRequest) do |mr|
      allow(mr).to receive(:diff_head_pipeline).and_return(pipeline)
    end
  end

  context "when MR doesn't get a pipeline" do
    let(:pipeline) { nil }

    it "enqueues unenforceable policy rules notification" do
      expect(worker).to receive(:perform_async).with(merge_request.id)

      perform
    end

    context "without licensed feature" do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it "does not enqueue unenforceable policy rules notification" do
        expect(worker).not_to receive(:perform_async)

        perform
      end
    end
  end

  context "when MR gets a pipeline" do
    let(:pipeline) { create(:ci_pipeline) }

    it "does not enqueue unenforceable policy rules notification" do
      expect(worker).not_to receive(:perform_async)

      perform
    end
  end

  context "when pre-existing branch pipeline matches MR diff_head_sha" do
    let_it_be(:pipeline) do
      create(
        :ee_ci_pipeline,
        :success,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end

    before do
      create(:report_approver_rule, :scan_finding, merge_request: merge_request)
      stub_licensed_features(security_orchestration_policies: true)

      allow(merge_request).to receive(:diff_head_pipeline).and_call_original
      allow_next_found_instance_of(MergeRequest) do |mr|
        allow(mr).to receive(:diff_head_pipeline).and_call_original
      end
    end

    it "enqueues security policy sync workers when diff_head_pipeline matches", :aggregate_failures do
      expect(::Ci::SyncReportsToReportApprovalRulesWorker)
        .to receive(:perform_async).with(pipeline.id)
      expect(::Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker)
        .to receive(:perform_async).with(pipeline.id, merge_request.id)
      expect(::Security::UnenforceablePolicyRulesPipelineNotificationWorker)
        .to receive(:perform_async).with(pipeline.id)
      expect(worker).not_to receive(:perform_async)

      perform

      expect(merge_request.reload.diff_head_pipeline).to eq(pipeline)
    end

    context "without licensed feature" do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it "does not enqueue any workers", :aggregate_failures do
        expect(::Ci::SyncReportsToReportApprovalRulesWorker).not_to receive(:perform_async)
        expect(::Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker).not_to receive(:perform_async)
        expect(::Security::UnenforceablePolicyRulesPipelineNotificationWorker).not_to receive(:perform_async)
        expect(worker).not_to receive(:perform_async)

        perform
      end
    end
  end
end

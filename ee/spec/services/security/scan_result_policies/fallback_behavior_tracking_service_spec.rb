# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::FallbackBehaviorTrackingService, "#execute", feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:service) { described_class.new(merge_request) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be_with_refind(:project_rule) do
    create(
      :approval_project_rule,
      project: project,
      scanners: %w[dependency_scanning],
      approvals_required: 1)
  end

  let_it_be_with_refind(:rule) do
    create(
      :report_approver_rule,
      approval_project_rule: project_rule,
      scanners: %w[dependency_scanning],
      merge_request: merge_request,
      approvals_required: 0,
      users: [user])
  end

  subject(:execute) { service.execute }

  shared_context "with fallback behavior" do |fail_open|
    let(:behavior) { fail_open ? "open" : "closed" }

    before do
      security_policy = create(:security_policy,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration,
        content: { fallback_behavior: { fail: behavior } })

      rule.update!(
        approval_policy_rule: create(:approval_policy_rule, security_policy: security_policy),
        scan_result_policy_read: create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          fallback_behavior: { fail: behavior }))
    end
  end

  shared_context "with invalid rule" do
    before do
      rule.update!(approvals_required: rule.approvers.size + 1)
    end
  end

  shared_context "with report" do
    let_it_be(:source_pipeline) do
      create(:ee_ci_pipeline,
        :success,
        :with_dependency_scanning_report,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha,
        merge_requests_as_head_pipeline: [merge_request])
    end

    let_it_be_with_refind(:target_pipeline) do
      create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
        ref: merge_request.target_branch, sha: merge_request.diff_base_sha)
    end

    let_it_be(:source_scan) do
      create(:security_scan, scan_type: 'dependency_scanning', pipeline: source_pipeline)
    end

    let_it_be(:target_scan) do
      create(:security_scan, scan_type: 'dependency_scanning', pipeline: target_pipeline)
    end

    before do
      allow_next_found_instance_of(Project) do |instance|
        allow(instance).to receive(:can_store_security_reports?).and_return(true)
      end
    end
  end

  shared_context "with approvals remaining" do
    before do
      rule.update!(approvals_required: 1)
    end
  end

  shared_context "when not requiring approval" do
    before do
      project_rule.update!(approvals_required: 0)
    end
  end

  shared_examples "tracks internal event" do |expected|
    specify do
      if expected
        expect(Gitlab::InternalEvents).to receive(:track_event).with(
          described_class::EVENT_NAME,
          hash_including(project: project)
        ).and_call_original
      else
        expect(Gitlab::InternalEvents).not_to receive(:track_event)
      end

      execute
    end
  end

  shared_examples "tracks behavior" do |fail_open:, track_event:|
    context "when rule fails #{fail_open ? 'open' : 'closed'}" do
      include_context "with fallback behavior", fail_open
      it_behaves_like "tracks internal event", track_event
    end
  end

  shared_examples "tracks event" do |expected|
    include_examples "tracks behavior", fail_open: true, track_event: expected
    include_examples "tracks behavior", fail_open: false, track_event: false
  end

  shared_examples "tracks fallback behavior for each report type" do
    context "with `scan_finding` rule" do
      before_all do
        rule.update!(report_type: :scan_finding)
      end

      context "with invalid rule" do
        include_context "with invalid rule"

        include_examples "tracks event", true
      end

      context "with missing report" do
        include_examples "tracks event", true
      end

      context "with report" do
        include_context "with report"

        include_examples "tracks event", false
      end

      context "with approvals remaining" do
        include_context "with approvals remaining"

        include_examples "tracks event", false
      end

      context "when not requiring approval" do
        include_context "when not requiring approval"

        include_examples "tracks event", false
      end

      context "when scan was removed" do
        include_context "with report"

        before do
          allow_next_instance_of(Security::ScanResultPolicies::UpdateApprovalsService) do |service|
            allow(service).to receive(:scan_missing?).with(rule).and_return(true)
          end
        end

        include_examples "tracks event", true
      end
    end

    context "with `license_scanning` rule" do
      before_all do
        rule.update!(report_type: :license_scanning)
      end

      context "with invalid rule" do
        include_context "with invalid rule"

        include_examples "tracks event", true
      end

      context "with missing report" do
        include_examples "tracks event", true
      end

      context "with report" do
        include_context "with report"

        include_examples "tracks event", false
      end

      context "with approvals remaining" do
        include_context "with approvals remaining"

        include_examples "tracks event", false
      end

      context "when not requiring approval" do
        include_context "when not requiring approval"

        include_examples "tracks event", false
      end
    end

    context "with `any_merge_request` rule" do
      before_all do
        rule.update!(report_type: :any_merge_request)
      end

      context "with invalid rule" do
        include_context "with invalid rule"

        include_examples "tracks event", true
      end

      context "with approvals remaining" do
        include_context "with approvals remaining"

        include_examples "tracks event", false
      end

      context "when not requiring approval" do
        include_context "when not requiring approval"

        include_examples "tracks event", false
      end
    end
  end

  it_behaves_like "tracks fallback behavior for each report type"

  context "when the deprecate_scan_result_policies flag is disabled" do
    include_context 'with deprecate_scan_result_policies flag disabled'

    it_behaves_like "tracks fallback behavior for each report type"
  end

  context 'when approval rule has no approval_policy_source' do
    before do
      rule.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
    end

    it_behaves_like "tracks internal event", false
  end

  context 'when approval_policy_source is resolved as nil' do
    include_context "with fallback behavior", true

    before do
      allow_next_found_instance_of(ApprovalMergeRequestRule) do |found_rule|
        allow(found_rule).to receive(:approval_policy_source).and_return(nil)
      end
    end

    it_behaves_like "tracks internal event", false
  end

  context 'when approval rule is backed by approval_policy_rule' do
    include_context 'with approval rule backed by approval_policy_rule'
    include_context 'with divergent fallback_behavior across approval_policy_source'

    let(:scan_result_policy_read) do
      create(:scan_result_policy_read, project: project,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let(:approval_policy_source_read) { scan_result_policy_read }
    let(:approval_policy_source_rule) { rule }
    let(:approval_policy_rule_trait) { :scan_finding }

    before do
      rule.update!(report_type: :scan_finding, scan_result_policy_read: scan_result_policy_read,
        approvals_required: rule.approvers.size + 1)
    end

    it 'tracks event when approval_policy_rule resolves fail_open' do
      expect(Gitlab::InternalEvents).to receive(:track_event).with(
        described_class::EVENT_NAME,
        hash_including(project: project)
      ).and_call_original

      execute
    end

    context 'when the deprecate_scan_result_policies flag is disabled' do
      include_context 'with deprecate_scan_result_policies flag disabled'

      it 'does not track event because scan_result_policy_read resolves fail_closed' do
        expect(Gitlab::InternalEvents).not_to receive(:track_event)

        execute
      end
    end
  end

  context 'when fail-open rule has only a scan_result_policy_read' do
    before do
      rule.update!(report_type: :scan_finding, approvals_required: rule.approvers.size + 1,
        scan_result_policy_read: create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          fallback_behavior: { fail: 'open' }))
    end

    it_behaves_like "tracks internal event", false

    context 'when the deprecate_scan_result_policies flag is disabled' do
      include_context 'with deprecate_scan_result_policies flag disabled'

      it_behaves_like "tracks internal event", true
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UnblockFailOpenApprovalRulesService, "#execute", feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:merge_request, freeze: false) { create(:merge_request, source_project: project) }
  let_it_be(:pipeline, freeze: false) do
    create(:ee_ci_pipeline,
      project: project,
      ref: merge_request.source_branch,
      merge_requests_as_head_pipeline: [merge_request])
  end

  let_it_be_with_refind(:scan_finding_fail_closed_rule) do
    create(
      :report_approver_rule,
      :scan_finding,
      scanners: %w[container_scanning sast],
      name: "Scan Finding Fail Closed",
      scan_result_policy_read: create(:scan_result_policy_read),
      approval_policy_rule: create(:approval_policy_rule),
      merge_request: merge_request,
      approvals_required: 1)
  end

  let_it_be_with_refind(:scan_finding_fail_open_rule) do
    create(
      :report_approver_rule,
      :scan_finding,
      name: "Scan Finding Fail Open",
      scanners: %w[container_scanning sast],
      scan_result_policy_read: create(:scan_result_policy_read, :fail_open),
      approval_policy_rule: create(:approval_policy_rule,
        security_policy: create(:security_policy, content: { fallback_behavior: { fail: 'open' } })),
      merge_request: merge_request,
      approvals_required: 1)
  end

  let_it_be_with_refind(:license_scanning_fail_closed_rule) do
    create(
      :report_approver_rule,
      :license_scanning,
      name: "License Scanning Fail Closed",
      scan_result_policy_read: create(:scan_result_policy_read),
      approval_policy_rule: create(:approval_policy_rule),
      merge_request: merge_request,
      approvals_required: 1)
  end

  let_it_be_with_refind(:license_scanning_fail_open_rule) do
    create(
      :report_approver_rule,
      :license_scanning,
      name: "License Scanning Fail Open",
      scan_result_policy_read: create(:scan_result_policy_read, :fail_open),
      approval_policy_rule: create(:approval_policy_rule,
        security_policy: create(:security_policy, content: { fallback_behavior: { fail: 'open' } })),
      merge_request: merge_request,
      approvals_required: 1)
  end

  let_it_be(:rules) do
    [
      scan_finding_fail_closed_rule,
      scan_finding_fail_open_rule,
      license_scanning_fail_closed_rule,
      license_scanning_fail_open_rule
    ]
  end

  let(:service) { described_class.new(merge_request: merge_request, report_types: report_types) }

  subject(:execute) { service.execute }

  before do
    rules.each do |rule|
      create(:scan_result_policy_violation,
        project: project,
        merge_request: merge_request,
        scan_result_policy_read: rule.scan_result_policy_read,
        approval_policy_rule: rule.approval_policy_rule)
    end
  end

  def approvals_required?(rule)
    rule.reload.approvals_required?
  end

  def violation_count(rule)
    rule.scan_result_policy_read.violations.count
  end

  shared_examples "unblocks all report types" do
    it "unblocks both scan_finding and license_scanning rules" do
      execute

      expect(approvals_required?(scan_finding_fail_open_rule)).to be_falsey
      expect(violation_count(scan_finding_fail_open_rule)).to eq(0)
      expect(approvals_required?(scan_finding_fail_closed_rule)).to be_truthy
      expect(violation_count(scan_finding_fail_closed_rule)).to eq(1)

      expect(approvals_required?(license_scanning_fail_open_rule)).to be_falsey
      expect(violation_count(license_scanning_fail_open_rule)).to eq(0)
      expect(approvals_required?(license_scanning_fail_closed_rule)).to be_truthy
      expect(violation_count(license_scanning_fail_closed_rule)).to eq(1)
    end
  end

  context "with scan_finding report_type" do
    let(:report_types) { %i[scan_finding] }

    it "removes required approvals for fail-open scan_finding rules only" do
      expect { execute }.to change { approvals_required?(scan_finding_fail_open_rule) }.from(true).to(false)
                              .and not_change { approvals_required?(scan_finding_fail_closed_rule) }.from(true)
                              .and not_change { approvals_required?(license_scanning_fail_open_rule) }.from(true)
                              .and not_change { approvals_required?(license_scanning_fail_closed_rule) }.from(true)
    end

    it "deletes violations for fail-open scan_finding rules only" do
      expect { execute }.to change { violation_count(scan_finding_fail_open_rule) }.from(1).to(0)
                              .and not_change { violation_count(scan_finding_fail_closed_rule) }.from(1)
                              .and not_change { violation_count(license_scanning_fail_open_rule) }.from(1)
                              .and not_change { violation_count(license_scanning_fail_closed_rule) }.from(1)
    end
  end

  context "with license_finding report_type" do
    let(:report_types) { %i[license_scanning] }

    it "removes required approvals for fail-open license_finding rules only" do
      expect { execute }.to change { approvals_required?(license_scanning_fail_open_rule) }.from(true).to(false)
                              .and not_change { approvals_required?(license_scanning_fail_closed_rule) }.from(true)
                              .and not_change { approvals_required?(scan_finding_fail_open_rule) }.from(true)
                              .and not_change { approvals_required?(scan_finding_fail_closed_rule) }.from(true)
    end

    it "deletes violations for fail-open license_finding rules only" do
      expect { execute }.to change { violation_count(license_scanning_fail_open_rule) }.from(1).to(0)
                              .and not_change { violation_count(license_scanning_fail_closed_rule) }.from(1)
                              .and not_change { violation_count(scan_finding_fail_open_rule) }.from(1)
                              .and not_change { violation_count(scan_finding_fail_closed_rule) }.from(1)
    end
  end

  context "with unrecognized report_type" do
    let(:report_types) { %i[any_merge_request] }

    specify do
      expect { execute }.to raise_error(ArgumentError, "unrecognized report_type")
    end
  end

  context "with multiple report_types" do
    let(:report_types) { %i[scan_finding license_scanning] }

    it_behaves_like "unblocks all report types"
  end

  context "without report_types" do
    let(:service) { described_class.new(merge_request: merge_request) }

    it_behaves_like "unblocks all report types"
  end

  context "without persisted policy" do
    let(:report_types) { %i[scan_finding] }

    before do
      scan_finding_fail_closed_rule.scan_result_policy_read.delete
    end

    it "doesn't raise" do
      expect { execute }.not_to raise_error
    end
  end

  context "when deprecate_scan_result_policies is disabled" do
    let(:report_types) { %i[scan_finding license_scanning] }

    before do
      stub_feature_flags(deprecate_scan_result_policies: false)
    end

    it_behaves_like "unblocks all report types"
  end
end

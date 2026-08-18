# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalWrappedRule, factory_default: :keep, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project, freeze: false) { create_default(:project) }
  let_it_be_with_refind(:merge_request) { create_default(:merge_request) }
  let_it_be(:approver1, freeze: false) { create(:user) }
  let_it_be(:approver2, freeze: false) { create(:user) }
  let_it_be(:approver3, freeze: false) { create(:user) }

  let(:rule) do
    create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: approvals_required)
  end

  let(:approvals_required) { 0 }

  subject(:approval_wrapped_rule) { described_class.new(merge_request, rule) }

  before do
    rule.clear_memoization(:approvers) if rule.respond_to?(:clear_memoization)
  end

  describe '#project' do
    it 'returns merge request project' do
      expect(approval_wrapped_rule.project).to eq(merge_request.target_project)
    end
  end

  describe '#approvals_left' do
    let_it_be(:approvals_left_policy_config, freeze: false) do
      create(:security_orchestration_policy_configuration)
    end

    before_all do
      create(:approval, merge_request: merge_request, user: approver1)
      create(:approval, merge_request: merge_request, user: approver2)
    end

    before do
      rule.users << approver1
      rule.users << approver2
    end

    context 'when approvals_required is greater than approved approver count' do
      let(:approvals_required) { 8 }

      it 'returns approvals still needed' do
        expect(approval_wrapped_rule.approvals_left).to eq(6)
      end
    end

    context 'when approvals_required is less than approved approver count' do
      let(:approvals_required) { 1 }

      it 'returns zero' do
        expect(approval_wrapped_rule.approvals_left).to eq(0)
      end
    end

    context 'when invalid' do
      let(:approvals_required) { 3 }

      context 'when failing closed' do
        it 'requires approvals' do
          expect(approval_wrapped_rule.approvals_left).to be(1)
        end
      end

      context 'when failing open' do
        before do
          rule.update!(report_type: :scan_finding, scan_result_policy_read: create(:scan_result_policy_read, :fail_open,
            security_orchestration_policy_configuration: approvals_left_policy_config))
        end

        it 'requires no approvals' do
          expect(approval_wrapped_rule.approvals_left).to be(0)
        end
      end
    end
  end

  describe '#approved?' do
    subject { described_class.new(merge_request, rule).approved? }

    before_all do
      create(:approval, merge_request: merge_request, user: approver1)
    end

    before do
      rule.users << approver1
    end

    context 'when approvals left is zero' do
      let(:approvals_required) { 1 }

      it { is_expected.to be(true) }
    end

    context 'when approvals left is not zero, but there is still unactioned approvers' do
      let(:approvals_required) { 2 }

      before do
        rule.users << approver2
      end

      it { is_expected.to be(false) }

      context 'when approval rule is dismissed' do
        let_it_be(:policy_configuration, freeze: false) do
          create(:security_orchestration_policy_configuration)
        end

        let_it_be(:security_policy, freeze: false) do
          create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
        end

        let_it_be(:scan_result_policy_read, freeze: false) do
          create(:scan_result_policy_read,
            security_orchestration_policy_configuration: policy_configuration)
        end

        let_it_be(:approval_policy_rule, freeze: false) do
          create(:approval_policy_rule, security_policy: security_policy)
        end

        let_it_be(:rule, freeze: false) do
          create(
            :approval_merge_request_rule,
            merge_request: merge_request,
            approvals_required: 2,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: approval_policy_rule
          )
        end

        let_it_be(:security_policy_dismissal, freeze: false) do
          create(:policy_dismissal, merge_request: merge_request,
            security_policy: security_policy)
        end

        let_it_be(:violation, freeze: false) do
          create(:scan_result_policy_violation,
            merge_request: merge_request,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: approval_policy_rule)
        end

        before do
          allow(rule).to receive(:warn_mode_policy?).and_return(true)
        end

        it { is_expected.to be(true) }
      end
    end

    context 'when approvals left is not zero, but there is no unactioned approvers' do
      let(:approvals_required) { 99 }

      it { is_expected.to be(true) }
    end

    context 'when approvals left is not zero, but there is not enough unactioned approvers' do
      let(:approvals_required) { 99 }

      before do
        rule.users << approver2
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#invalid_rule?' do
    subject { described_class.new(merge_request, rule).invalid_rule? }

    context 'when there are no unactioned approvers and approvals are required' do
      let(:approvals_required) { 1 }

      it { is_expected.to be(true) }
    end

    context 'when rule is any_approver and approvals are required' do
      let(:rule) { create(:any_approver_rule, merge_request: merge_request, approvals_required: 1) }

      it { is_expected.to be(false) }
    end

    context 'when more approvals are required than the number of approvers' do
      let(:approvals_required) { 2 }

      before do
        rule.users << approver1
      end

      it { is_expected.to be(true) }
    end

    context 'when there are unactioned approvers and approvals are required' do
      let(:approvals_required) { 1 }

      before do
        rule.users << approver1
      end

      it { is_expected.to be(false) }
    end

    context 'when there are no unactioned approvers because all required approvals are given' do
      let(:approvals_required) { 1 }

      before do
        create(:approval, merge_request: merge_request, user: approver1)
        rule.users << approver1
      end

      it { is_expected.to be(false) }
    end

    context 'when there are more approvers than required approvals' do
      let(:approvals_required) { 1 }

      before do
        rule.users << approver1
        rule.users << approver2
      end

      it { is_expected.to be(false) }
    end

    context 'when no approvals are required' do
      let(:approvals_required) { 0 }

      it { is_expected.to be(false) }
    end
  end

  describe '#allow_merge_when_invalid?' do
    subject { described_class.new(merge_request, rule).allow_merge_when_invalid? }

    context 'when report_type is scan_finding' do
      let(:rule) { create(:report_approver_rule, :scan_finding) }

      it { is_expected.to be(false) }
    end

    context 'when report_type is license_scanning and scan_result_policy_read is attached' do
      let_it_be(:policy_management_project, freeze: false) { create(:project) }

      let_it_be(:policy_configuration, freeze: false) do
        create(:security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project)
      end

      let(:rule) do
        create(:report_approver_rule, :license_scanning, scan_result_policy_read: scan_result_policy_read)
      end

      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it { is_expected.to be(false) }

      context 'when invalid' do
        let(:approvals_required) { 2 }

        context 'when failing open' do
          let_it_be(:scan_result_policy_read, freeze: false) do
            create(:scan_result_policy_read, :fail_open,
              security_orchestration_policy_configuration: policy_configuration)
          end

          it { is_expected.to be(true) }
        end
      end
    end

    context 'when report_type is any_merge_request' do
      let(:rule) { create(:report_approver_rule, :any_merge_request) }

      it { is_expected.to be(false) }
    end

    context 'when report_type is nil' do
      let(:rule) { create(:approval_merge_request_rule, report_type: nil) }

      it { is_expected.to be(true) }
    end

    context 'when project is a policy management project' do
      before_all do
        create(:security_orchestration_policy_configuration, security_policy_management_project: merge_request.project)
      end

      let(:rule) { create(:report_approver_rule, :scan_finding) }

      it { is_expected.to be(true) }
    end
  end

  describe '#scan_result_policies' do
    let_it_be(:policy_configuration, freeze: false) do
      create(:security_orchestration_policy_configuration)
    end

    let_it_be(:scan_finding_approval_rule, freeze: false) do
      create(:approval_merge_request_rule,
        report_type: :scan_finding,
        merge_request: merge_request,
        scan_result_policy_read: create(:scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration),
        orchestration_policy_idx: 0,
        security_orchestration_policy_configuration: policy_configuration
      )
    end

    subject { described_class.new(merge_request, scan_finding_approval_rule).scan_result_policies }

    it 'returns approval rules matching index' do
      rules = subject
      rule = rules.first

      expect(rules.size).to eq(1)
      expect(rule.report_type).to eq('scan_finding')
      expect(rule.name).to eq(scan_finding_approval_rule.name)
      expect(rule.approvals_required).to eq(scan_finding_approval_rule.approvals_required)
      expect(rule.approval_policy_action_idx).to eq(scan_finding_approval_rule.approval_policy_action_idx)
    end
  end

  describe '#policy_has_multiple_actions?' do
    let_it_be(:policy_configuration, freeze: false) do
      create(:security_orchestration_policy_configuration)
    end

    let_it_be(:scan_finding_approval_rule, freeze: false) do
      create(:approval_merge_request_rule,
        report_type: :scan_finding,
        merge_request: merge_request,
        orchestration_policy_idx: 0,
        approval_policy_action_idx: 0,
        security_orchestration_policy_configuration: policy_configuration
      )
    end

    subject { described_class.new(merge_request, scan_finding_approval_rule).policy_has_multiple_actions? }

    it { is_expected.to be(false) }

    context 'with multiple approval_policy_action_idx' do
      before_all do
        create(:approval_merge_request_rule,
          report_type: :scan_finding,
          merge_request: merge_request,
          orchestration_policy_idx: 0,
          approval_policy_action_idx: 1,
          security_orchestration_policy_configuration: policy_configuration
        )
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#approved_approvers' do
    context 'when some approvers has made the approvals' do
      before do
        create(:approval, merge_request: merge_request, user: approver1)
        create(:approval, merge_request: merge_request, user: approver2)

        rule.users = [approver1, approver3]
      end

      it 'returns approved approvers' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver1)
      end
    end

    context 'when merged' do
      let(:merge_request) { create(:merge_request, source_branch: 'test') }

      before do
        rule.approved_approvers << approver3

        merge_request.mark_as_merged!
      end

      it 'returns approved approvers from database' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver3)
      end
    end

    context 'when merged but without materialized approved_approvers' do
      let(:merge_request) { create(:merge_request, source_branch: 'test') }

      before do
        create(:approval, merge_request: merge_request, user: approver1)
        create(:approval, merge_request: merge_request, user: approver2)

        rule.users = [approver1, approver3]

        merge_request.mark_as_merged!
      end

      it 'returns computed approved approvers' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver1)
      end
    end

    context 'when project rule' do
      let(:rule) do
        create(:approval_project_rule, project: merge_request.project, approvals_required: approvals_required)
      end

      let(:merge_request) { create(:merged_merge_request) }

      before do
        create(:approval, merge_request: merge_request, user: approver1)
        create(:approval, merge_request: merge_request, user: approver2)

        rule.users = [approver1, approver3]
      end

      it 'returns computed approved approvers' do
        expect(approval_wrapped_rule.approved_approvers).to contain_exactly(approver1)
      end
    end

    it 'avoids N+1 queries' do
      rule = create(:approval_project_rule, project: merge_request.project, approvals_required: approvals_required)
      rule.users = [approver1]

      approved_approvers_for_rule_id(rule.id) # warm up the cache
      control = ActiveRecord::QueryRecorder.new { approved_approvers_for_rule_id(rule.id) }

      rule.users += [approver2, approver3]

      expect { approved_approvers_for_rule_id(rule.id) }.not_to exceed_query_limit(control)
    end

    def approved_approvers_for_rule_id(rule_id)
      described_class.new(merge_request, ApprovalProjectRule.find(rule_id)).approved_approvers
    end
  end

  describe "#commented_approvers" do
    let_it_be(:rule, freeze: false) do
      create(:approval_project_rule, project: merge_request.project, approvals_required: 0,
        users: [approver1, approver3])
    end

    it "returns an array" do
      expect(approval_wrapped_rule.commented_approvers).to be_an(Array)
    end

    it "returns an array of approvers who have commented" do
      non_approver = create(:user)
      create(:note, project: merge_request.project, noteable: merge_request, author: approver1)
      create(:note, project: merge_request.project, noteable: merge_request, author: non_approver)
      create(:system_note, project: merge_request.project, noteable: merge_request, author: approver3)

      expect(approval_wrapped_rule.commented_approvers).to include(approver1)
      expect(approval_wrapped_rule.commented_approvers).not_to include(non_approver)
      expect(approval_wrapped_rule.commented_approvers).not_to include(approver3)
    end
  end

  describe '#unactioned_approvers' do
    context 'when some approvers has not approved yet' do
      before do
        create(:approval, merge_request: merge_request, user: approver1)
        rule.users = [approver1, approver2]
      end

      it 'returns unactioned approvers' do
        expect(approval_wrapped_rule.unactioned_approvers).to contain_exactly(approver2)
      end
    end

    context 'when merged' do
      let(:merge_request) { create(:merge_request, source_branch: 'test') }

      before do
        rule.approved_approvers << approver3
        rule.users = [approver1, approver3]

        merge_request.mark_as_merged!
      end

      it 'returns approved approvers from database' do
        expect(approval_wrapped_rule.unactioned_approvers).to contain_exactly(approver1)
      end
    end
  end

  describe '#approvals_required' do
    let(:rule) { create(:approval_merge_request_rule, approvals_required: 19) }

    context 'when rule is not dismissed' do
      it 'returns the attribute saved on the model' do
        expect(approval_wrapped_rule.approvals_required).to eq(19)
      end

      context 'when rule is not a warn mode policy' do
        before do
          allow(rule).to receive(:warn_mode_policy?).and_return(false)
        end

        it 'returns the original approvals required' do
          expect(approval_wrapped_rule.approvals_required).to eq(19)
        end
      end

      context 'when rule is a warn mode policy but has no violations' do
        let_it_be(:policy_configuration, freeze: false) do
          create(:security_orchestration_policy_configuration)
        end

        let_it_be(:scan_result_policy_read, freeze: false) do
          create(:scan_result_policy_read,
            security_orchestration_policy_configuration: policy_configuration)
        end

        let(:rule) do
          create(
            :approval_merge_request_rule,
            merge_request: merge_request,
            approvals_required: 19,
            scan_result_policy_read: scan_result_policy_read
          )
        end

        before do
          allow(rule).to receive(:warn_mode_policy?).and_return(true)
        end

        it 'returns the original approvals required' do
          expect(approval_wrapped_rule.approvals_required).to eq(19)
        end
      end
    end

    context 'when rule is dismissed' do
      let_it_be(:policy_configuration, freeze: false) do
        create(:security_orchestration_policy_configuration)
      end

      let_it_be(:security_policy, freeze: false) do
        create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
      end

      let_it_be(:scan_result_policy_read, freeze: false) do
        create(:scan_result_policy_read,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let_it_be(:approval_policy_rule, freeze: false) do
        create(:approval_policy_rule, security_policy: security_policy)
      end

      let(:rule) do
        create(
          :approval_merge_request_rule,
          merge_request: merge_request,
          approvals_required: 19,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: approval_policy_rule
        )
      end

      let(:finding_uuids) { [SecureRandom.uuid, SecureRandom.uuid] }
      let!(:violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: approval_policy_rule,
          uuids: finding_uuids
        )
      end

      before do
        allow(rule).to receive(:warn_mode_policy?).and_return(true)
      end

      context 'when violation exists and is fully dismissed' do
        let!(:policy_dismissal) do
          create(:policy_dismissal,
            merge_request: merge_request,
            security_policy: security_policy,
            security_findings_uuids: finding_uuids
          )
        end

        it 'returns 0 when the rule is dismissed' do
          expect(approval_wrapped_rule.approvals_required).to eq(0)
        end
      end

      context 'when violation exists but is not dismissed' do
        it 'returns the original approvals required' do
          expect(approval_wrapped_rule.approvals_required).to eq(19)
        end
      end

      context 'when violation exists but is only partially dismissed' do
        let!(:policy_dismissal) do
          create(:policy_dismissal,
            merge_request: merge_request,
            security_policy: security_policy,
            security_findings_uuids: [finding_uuids.first] # Only dismiss one UUID
          )
        end

        it 'returns the original approvals required' do
          expect(approval_wrapped_rule.approvals_required).to eq(19)
        end
      end

      context 'when there are multiple violations for different rules' do
        let_it_be(:other_scan_result_policy_read, freeze: false) do
          create(:scan_result_policy_read,
            security_orchestration_policy_configuration: policy_configuration)
        end

        let_it_be(:other_approval_policy_rule, freeze: false) do
          create(:approval_policy_rule, security_policy: security_policy)
        end

        let(:finding_uuids_for_other_rule) { [SecureRandom.uuid, SecureRandom.uuid] }

        let!(:violation_for_other_rule) do
          create(:scan_result_policy_violation, :new_scan_finding,
            merge_request: merge_request,
            scan_result_policy_read: other_scan_result_policy_read,
            approval_policy_rule: other_approval_policy_rule,
            uuids: finding_uuids_for_other_rule
          )
        end

        let!(:policy_dismissal) do
          create(:policy_dismissal,
            merge_request: merge_request,
            security_policy: security_policy,
            security_findings_uuids: finding_uuids # Only dismiss the first rule's findings
          )
        end

        it 'returns 0 for the dismissed rule' do
          expect(approval_wrapped_rule.approvals_required).to eq(0)
        end
      end

      context 'when rule has no approval_policy_rule' do
        let(:rule) do
          create(
            :approval_merge_request_rule,
            merge_request: merge_request,
            approvals_required: 19,
            scan_result_policy_read: scan_result_policy_read
          )
        end

        before do
          allow(rule).to receive(:warn_mode_policy?).and_return(true)
        end

        it 'returns the original approvals required' do
          expect(approval_wrapped_rule.approvals_required).to eq(19)
        end
      end

      context 'when deprecate_scan_result_policies is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        context 'when violation exists and is fully dismissed' do
          let!(:policy_dismissal) do
            create(:policy_dismissal,
              merge_request: merge_request,
              security_policy: security_policy,
              security_findings_uuids: finding_uuids
            )
          end

          it 'returns 0 when the rule is dismissed' do
            expect(approval_wrapped_rule.approvals_required).to eq(0)
          end
        end
      end
    end

    context 'when rule is bypassed' do
      let_it_be(:security_policy, freeze: false) { create(:security_policy, :approval_policy) }
      let_it_be(:approval_policy_rule, freeze: false) do
        create(:approval_policy_rule, security_policy: security_policy)
      end

      let(:rule) do
        create(
          :approval_merge_request_rule,
          report_type: :scan_finding,
          merge_request: merge_request,
          approvals_required: 19,
          approval_policy_rule: approval_policy_rule
        )
      end

      before_all do
        create(:approval_policy_merge_request_bypass_event,
          security_policy: security_policy,
          merge_request: merge_request
        )
      end

      it 'returns 0 when the rule is bypassed' do
        expect(approval_wrapped_rule.approvals_required).to eq(0)
      end
    end
  end

  describe '#name' do
    let(:rule_name) { 'approval rule 2' }
    let(:rule) do
      create(:approval_merge_request_rule,
        merge_request: merge_request,
        report_type: report_type,
        name: rule_name
      )
    end

    context 'with report_type set to scan_finding' do
      let(:report_type) { :scan_finding }
      let(:expected_rule_name) { 'approval rule' }
      let(:policy_configuration) do
        create(:security_orchestration_policy_configuration)
      end

      let(:rule) do
        create(:approval_merge_request_rule,
          merge_request: merge_request,
          security_orchestration_policy_configuration: policy_configuration,
          report_type: report_type,
          name: rule_name
        )
      end

      it 'returns rule name without the sequential notation' do
        expect(approval_wrapped_rule.name).not_to eq(rule_name)
        expect(approval_wrapped_rule.name).to eq(expected_rule_name)
      end

      context 'when policy has multiple actions' do
        before do
          create(:approval_merge_request_rule,
            report_type: report_type,
            merge_request: merge_request,
            name: rule_name,
            orchestration_policy_idx: rule.orchestration_policy_idx,
            security_orchestration_policy_configuration: policy_configuration,
            approval_policy_action_idx: 1)
        end

        it 'returns rule name with action index suffix' do
          expect(approval_wrapped_rule.name).to eq("#{expected_rule_name} - Action 1")
        end
      end
    end

    context 'with report_type other than scan_finding' do
      let(:report_type) { :code_coverage }

      it 'returns rule name as is' do
        expect(approval_wrapped_rule.name).to eq(rule_name)
      end
    end

    context 'with report_type set to license_scanning' do
      let(:report_type) { :license_scanning }
      let(:expected_rule_name) { 'approval rule' }

      let_it_be(:name_policy_configuration, freeze: false) do
        create(:security_orchestration_policy_configuration)
      end

      let(:rule) do
        create(:approval_merge_request_rule,
          report_type: report_type,
          merge_request: merge_request,
          scan_result_policy_read: create(:scan_result_policy_read,
            security_orchestration_policy_configuration: name_policy_configuration),
          name: rule_name)
      end

      it 'returns rule name without the sequential notation' do
        expect(approval_wrapped_rule.name).not_to eq(rule_name)
        expect(approval_wrapped_rule.name).to eq(expected_rule_name)
      end
    end
  end

  describe '#fail_open?' do
    subject { approval_wrapped_rule.fail_open? }

    context 'when rule has a linked scan_result_policy_read' do
      before do
        rule.update!(report_type: :scan_finding, scan_result_policy_read: scan_result_policy_read)
      end

      context 'when rule is fail open' do
        let(:scan_result_policy_read) { build(:scan_result_policy_read, :fail_open) }

        it { is_expected.to be(true) }
      end

      context 'when rule is not fail closed' do
        let(:scan_result_policy_read) { build(:scan_result_policy_read, :fail_closed) }

        it { is_expected.to be(false) }
      end
    end

    context 'when rule has a linked approval_policy_rule' do
      let(:security_policy) { create(:security_policy, content: { fallback_behavior: { fail: 'open' } }) }
      let(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      before do
        rule.update!(report_type: :scan_finding, approval_policy_rule: approval_policy_rule)
      end

      it { is_expected.to be(true) }

      context 'when deprecate_scan_result_policies is disabled' do
        before do
          stub_feature_flags(deprecate_scan_result_policies: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when rule is not from a scan result policy' do
      it { is_expected.to be(false) }
    end
  end

  describe "#from_scan_result_policy?" do
    subject { approval_wrapped_rule.from_scan_result_policy? }

    it 'delegates from_scan_result_policy to approval_rule' do
      expect(rule).to receive(:from_scan_result_policy?)

      subject
    end

    context 'when the approval rule is from a scan result policy' do
      before do
        rule.update!(report_type: :scan_finding)
      end

      it { is_expected.to be(true) }
    end

    context 'when the approval rule is not from a scan result policy' do
      before do
        rule.update!(report_type: :code_coverage)
      end

      it { is_expected.to be(false) }
    end
  end

  describe "v2 approval rule method delegations" do
    context 'when v2_approval_rules ff is enabled' do
      before do
        stub_feature_flags(v2_approval_rules: true)
      end

      let(:v2_approval_rule) do
        create(:merge_requests_approval_rule, :from_merge_request, project_id: merge_request.project.id,
          merge_request: merge_request)
      end

      let(:approval_wrapped_rule) { described_class.new(merge_request, v2_approval_rule) }

      describe "originates_from_project?" do
        subject { approval_wrapped_rule.originates_from_project? }

        it { is_expected.to be(false) }
      end

      describe "originates_from_merge_request?" do
        subject { approval_wrapped_rule.originates_from_merge_request? }

        it { is_expected.to be(true) }
      end

      describe "user_defined?" do
        subject { approval_wrapped_rule.user_defined? }

        it { is_expected.to be(true) }
      end

      context 'when wrapping a v1 approval rule' do
        let(:v1_rule) { create(:approval_project_rule, project: merge_request.project) }
        let(:approval_wrapped_rule) { described_class.new(merge_request, v1_rule) }

        describe "originates_from_project?" do
          subject { approval_wrapped_rule.originates_from_project? }

          it { is_expected.to be_nil }
        end

        describe "originates_from_merge_request?" do
          subject { approval_wrapped_rule.originates_from_merge_request? }

          it { is_expected.to be_nil }
        end
      end
    end

    context 'when v2_approval_rules ff is disabled' do
      before do
        stub_feature_flags(v2_approval_rules: false)
      end

      describe "originates_from_project?" do
        subject { approval_wrapped_rule.originates_from_project? }

        it { is_expected.to be_nil }
      end

      describe "originates_from_merge_request?" do
        subject { approval_wrapped_rule.originates_from_merge_request? }

        it { is_expected.to be_nil }
      end

      describe "user_defined?" do
        subject { approval_wrapped_rule.user_defined? }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#approvers' do
    include_context 'with merge request approval settings' do
      let(:approval_rule_project) { merge_request.target_project }
    end

    let(:author) { merge_request.author }
    let(:author_relation) { User.id_in(author.id) }
    let(:committer_relation) { User.id_in(committer.id) }

    let_it_be(:committer, freeze: false) { create(:user) }

    subject(:approvers) { approval_wrapped_rule.approvers }

    before do
      allow(merge_request).to receive_messages(
        committers: committer_relation,
        committers_to_filter_from_approvers: committer_relation,
        committer_ids_to_filter_from_approvers: committer_relation.select(:id)
      )

      rule.users << author
      rule.users << committer
    end

    context 'when author and committer approval is allowed' do
      it { is_expected.to contain_exactly(author, committer) }
    end

    context 'when instance prevents author approval' do
      let(:instance_prevents_author_approval) { true }

      it { is_expected.to contain_exactly(committer) }
    end

    context 'when parent group prevents author approval' do
      let(:group_prevents_author_approval) { true }

      it { is_expected.to contain_exactly(committer) }
    end

    context 'when project prevents author approval' do
      let(:project_prevents_author_approval) { true }

      it { is_expected.to contain_exactly(committer) }
    end

    context 'when approval policy prevents author approval' do
      let(:approval_policy_prevents_author_approval) { true }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it { is_expected.to contain_exactly(committer) }

      context 'without licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to contain_exactly(author, committer) }
      end
    end

    context 'when instance prevents committer approval' do
      let(:instance_prevents_committer_approval) { true }

      it { is_expected.to contain_exactly(author) }
    end

    context 'when parent group prevents committer approval' do
      let(:group_prevents_committer_approval) { true }

      it { is_expected.to contain_exactly(author) }
    end

    context 'when project prevents committer approval' do
      let(:project_prevents_committer_approval) { true }

      it { is_expected.to contain_exactly(author) }
    end

    context 'when approval policy prevents committer approval' do
      let(:approval_policy_prevents_committer_approval) { true }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it { is_expected.to contain_exactly(author) }

      context 'without licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to contain_exactly(author, committer) }
      end
    end

    context 'when both author and committer approval are prevented at project level' do
      let(:project_prevents_author_approval) { true }
      let(:project_prevents_committer_approval) { true }

      it { is_expected.to be_empty }
    end

    context 'when both author and committer approval are prevented by policy' do
      let(:approval_policy_prevents_author_approval) { true }
      let(:approval_policy_prevents_committer_approval) { true }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it { is_expected.to be_empty }
    end

    context 'when author is also a committer' do
      before do
        allow(merge_request).to receive_messages(
          committers: author_relation,
          committers_to_filter_from_approvers: author_relation,
          committer_ids_to_filter_from_approvers: author_relation.select(:id)
        )

        rule.users.delete(committer)
      end

      context 'when project prevents author approval but allows committer approval' do
        let(:project_prevents_author_approval) { true }
        let(:project_prevents_committer_approval) { false }

        it { is_expected.to be_empty }
      end

      context 'when project prevents committer approval but allows author approval' do
        let(:project_prevents_author_approval) { false }
        let(:project_prevents_committer_approval) { true }

        it { is_expected.to be_empty }
      end

      context 'when project allows both' do
        let(:project_prevents_author_approval) { false }
        let(:project_prevents_committer_approval) { false }

        it { is_expected.to contain_exactly(author) }
      end
    end

    context 'with additional non-author, non-committer approvers' do
      before do
        rule.users << approver1
        rule.users << approver2
      end

      context 'when project prevents author approval' do
        let(:project_prevents_author_approval) { true }

        it { is_expected.to contain_exactly(committer, approver1, approver2) }
      end

      context 'when project prevents committer approval' do
        let(:project_prevents_committer_approval) { true }

        it { is_expected.to contain_exactly(author, approver1, approver2) }
      end

      context 'when project prevents both author and committer approval' do
        let(:project_prevents_author_approval) { true }
        let(:project_prevents_committer_approval) { true }

        it { is_expected.to contain_exactly(approver1, approver2) }
      end
    end

    context 'when merge request has no author' do
      let(:project_prevents_author_approval) { true }

      before do
        allow(merge_request).to receive(:author).and_return(nil)
      end

      it 'does not filter author from approvers' do
        is_expected.to contain_exactly(author, committer)
      end
    end

    context 'when approvers are preloaded' do
      let(:project_prevents_committer_approval) { true }

      before do
        rule.users.load
        rule.group_users.load
      end

      it 'filters committers from the loaded approvers' do
        is_expected.to contain_exactly(author)
      end
    end

    context 'when security_orchestration_policies is licensed but rule has no scan_result_policy_read' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
        rule.update!(scan_result_policy_read: nil)
      end

      it 'includes author in approvers' do
        is_expected.to contain_exactly(author, committer)
      end
    end

    context 'with multiple rules' do
      context 'when one rule has policy preventing author approval' do
        let_it_be(:approvers_policy_configuration, freeze: false) do
          create(:security_orchestration_policy_configuration)
        end

        let_it_be(:policy_read_preventing_author, freeze: false) do
          create(:scan_result_policy_read, :prevent_approval_by_author,
            security_orchestration_policy_configuration: approvers_policy_configuration)
        end

        let_it_be(:policy_read_allowing_author, freeze: false) do
          create(:scan_result_policy_read,
            security_orchestration_policy_configuration: approvers_policy_configuration)
        end

        let(:rule1) do
          create(:approval_merge_request_rule, merge_request: merge_request,
            scan_result_policy_read: policy_read_preventing_author)
        end

        let(:rule2) do
          create(:approval_merge_request_rule, merge_request: merge_request,
            scan_result_policy_read: policy_read_allowing_author)
        end

        let(:wrapped_rule1) { described_class.new(merge_request, rule1) }
        let(:wrapped_rule2) { described_class.new(merge_request, rule2) }

        before do
          stub_licensed_features(security_orchestration_policies: true)

          rule1.users << author
          rule1.users << committer

          rule2.users << author
          rule2.users << committer
        end

        it 'filters author only from the rule with the policy' do
          # Rule1 should exclude author due to policy
          expect(wrapped_rule1.approvers).to contain_exactly(committer)

          # Rule2 should include author since its policy allows it
          expect(wrapped_rule2.approvers).to contain_exactly(author, committer)
        end
      end
    end
  end
end

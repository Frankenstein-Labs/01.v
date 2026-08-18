# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalRuleParamsBuilder, feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:author) { create(:user) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let(:security_policy) do
    create(:security_policy,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration,
      policy_index: 0,
      name: 'Test Policy')
  end

  let(:approval_policy_rule) do
    create(:approval_policy_rule, :scan_finding, security_policy: security_policy, rule_index: 0)
  end

  let(:scan_result_policy_read) { create(:scan_result_policy_read) }
  let(:protected_branch) { create(:protected_branch, project: project) }

  let(:action_index) { 0 }
  let(:approval_action) do
    {
      type: 'require_approval',
      approvals_required: 2,
      user_approvers: ['user1'],
      user_approvers_ids: [1],
      group_approvers: ['group1'],
      group_approvers_ids: [1]
    }
  end

  let(:protected_branch_ids) { [protected_branch.id] }

  let(:builder) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rule: approval_policy_rule,
      scan_result_policy_read: scan_result_policy_read,
      approval_action: approval_action,
      action_index: action_index,
      protected_branch_ids: protected_branch_ids,
      author: author
    )
  end

  describe '#build' do
    subject(:params) { builder.build }

    before do
      allow(project.team).to receive(:users).and_return(class_double(User, get_ids_by_ids_or_usernames: [1]))
      allow(Security::ApprovalGroupsFinder).to receive(:new).and_return(instance_double(Security::ApprovalGroupsFinder,
        execute: [1]))
    end

    it 'returns hash with correct base parameters' do
      expect(params).to include(
        skip_authorization: true,
        approvals_required: 2,
        name: 'Test Policy',
        protected_branch_ids: protected_branch_ids,
        applies_to_all_protected_branches: true,
        rule_type: :report_approver,
        user_ids: [1],
        report_type: :scan_finding,
        orchestration_policy_idx: 0,
        group_ids: [1],
        scanners: %w[container_scanning],
        severity_levels: %w[critical],
        vulnerabilities_allowed: 0,
        vulnerability_states: %w[detected],
        security_orchestration_policy_configuration_id: security_orchestration_policy_configuration.id,
        approval_policy_rule_id: approval_policy_rule.id,
        scan_result_policy_id: scan_result_policy_read.id,
        approval_policy_action_idx: 0,
        permit_inaccessible_groups: true
      )
    end

    it 'includes scan finding specific parameters' do
      expect(params).to include(
        scanners: %w[container_scanning],
        severity_levels: %w[critical],
        vulnerabilities_allowed: 0,
        vulnerability_states: %w[detected]
      )
    end

    context 'with license finding rule type' do
      let(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding, security_policy: security_policy, rule_index: 1)
      end

      it 'sets correct report type and empty severity levels' do
        expect(params).to include(
          report_type: :license_scanning,
          severity_levels: []
        )
      end
    end

    context 'with any merge request rule type' do
      let(:approval_policy_rule) do
        create(:approval_policy_rule, :any_merge_request, security_policy: security_policy, rule_index: 2)
      end

      it 'sets correct report type' do
        expect(params[:report_type]).to eq(:any_merge_request)
      end
    end

    context 'when approval action is nil' do
      let(:approval_action) { nil }

      it 'defaults approvals_required to 0' do
        expect(params[:approvals_required]).to eq(0)
      end
    end

    context 'with global group approvers enabled' do
      before do
        stub_application_setting(security_policy_global_group_approvers_enabled: true)
      end

      it 'passes search_globally: true to ApprovalGroupsFinder' do
        expect(Security::ApprovalGroupsFinder).to receive(:new)
          .with(hash_including(search_globally: true))
          .and_return(instance_double(Security::ApprovalGroupsFinder, execute: [1]))

        params
      end
    end

    context 'with global group approvers disabled' do
      before do
        stub_application_setting(security_policy_global_group_approvers_enabled: false)
      end

      it 'passes search_globally: false to ApprovalGroupsFinder' do
        expect(Security::ApprovalGroupsFinder).to receive(:new)
          .with(hash_including(search_globally: false))
          .and_return(instance_double(Security::ApprovalGroupsFinder, execute: [1]))

        params
      end
    end

    context 'with atomic scanner rule criteria' do
      context 'with legacy scanner format (string array)' do
        let(:approval_policy_rule) do
          create(:approval_policy_rule, security_policy: security_policy, rule_index: 0, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => %w[sast dependency_scanning],
            'severity_levels' => %w[critical high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        it 'extracts scanner types as strings' do
          expect(params[:scanners]).to contain_exactly('sast', 'dependency_scanning')
        end
      end

      context 'with new scanner format (object array)' do
        let(:approval_policy_rule) do
          create(:approval_policy_rule, security_policy: security_policy, rule_index: 0, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              { 'type' => 'sast', 'vulnerability_attributes' => { 'fix_available' => true } },
              { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'known_exploited' => true } },
              { 'type' => 'container_scanning' }
            ],
            'severity_levels' => %w[critical high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        it 'extracts scanner types from objects' do
          expect(params[:scanners]).to contain_exactly('sast', 'dependency_scanning', 'container_scanning')
        end
      end

      context 'with per-scanner severity_levels and vulnerabilities_allowed' do
        let(:approval_policy_rule) do
          create(:approval_policy_rule, security_policy: security_policy, rule_index: 0, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              { 'type' => 'sast', 'severity_levels' => %w[low], 'vulnerabilities_allowed' => 10 },
              { 'type' => 'dependency_scanning', 'vulnerability_states' => %w[new_needs_triage] }
            ],
            'severity_levels' => %w[critical high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        it 'still extracts scanner types correctly' do
          expect(params[:scanners]).to contain_exactly('sast', 'dependency_scanning')
        end

        it 'preserves rule-level severity_levels and vulnerabilities_allowed in params' do
          expect(params[:severity_levels]).to eq(%w[critical high])
          expect(params[:vulnerabilities_allowed]).to eq(0)
          expect(params[:vulnerability_states]).to eq(%w[detected])
        end
      end

      context 'with mixed scanner format' do
        let(:approval_policy_rule) do
          create(:approval_policy_rule, security_policy: security_policy, rule_index: 0, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              'sast',
              { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } }
            ],
            'severity_levels' => %w[critical],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        it 'extracts scanner types from both strings and objects' do
          expect(params[:scanners]).to contain_exactly('sast', 'dependency_scanning')
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalProjectRule, feature_category: :compliance_management do
  subject(:rule) { create(:approval_project_rule) }

  describe Security::ApprovalPolicyFiltering do
    include_examples 'approval rules filtering' do
      let(:approval_rule_project) { rule.project }
    end
  end

  describe 'validations' do
    it 'is invalid when name not unique within rule type and project' do
      is_expected.to validate_uniqueness_of(:name).scoped_to([:project_id, :rule_type])
    end

    it 'is invalid when vulnerabilities_allowed is a negative integer' do
      is_expected.to validate_numericality_of(:vulnerabilities_allowed).only_integer.is_greater_than_or_equal_to(0)
    end

    describe 'coverage_minimum_threshold' do
      context 'when report_type is code_coverage' do
        subject { build(:approval_project_rule, :code_coverage) }

        it do
          is_expected.to validate_numericality_of(:coverage_minimum_threshold)
            .is_greater_than_or_equal_to(0)
            .is_less_than_or_equal_to(100)
            .allow_nil
        end
      end

      context 'when report_type is not code_coverage' do
        subject { build(:approval_project_rule, :license_scanning) }

        it { is_expected.to validate_absence_of(:coverage_minimum_threshold) }
      end
    end

    context 'DEFAULT_SEVERITIES' do
      it 'contains a valid subset of severity levels' do
        expect(::Enums::Vulnerability.severity_levels.keys).to include(*described_class::DEFAULT_SEVERITIES)
      end
    end

    context 'APPROVAL_VULNERABILITY_STATES' do
      let_it_be(:vulnerability_states) { Enums::Vulnerability.vulnerability_states }
      let_it_be(:newly_detected_states) { ApprovalProjectRule::NEWLY_DETECTED_STATES }

      let_it_be(:expected_states) { vulnerability_states.merge(newly_detected_states) }

      it 'contains all vulnerability states and the newly detected states' do
        expect(described_class::APPROVAL_VULNERABILITY_STATES).to include(*expected_states.keys)
      end
    end

    context 'name uniqueness' do
      let_it_be_with_reload(:project) { create(:project) }

      context 'when not from scan result policy' do
        it 'validates uniqueness of name scoped to project_id and rule_type' do
          create(:approval_project_rule, project: project, name: 'Test Rule')
          duplicate_rule = build(:approval_project_rule, project: project, name: 'Test Rule')

          expect(duplicate_rule).to be_invalid
          expect(duplicate_rule.errors[:name]).to include('has already been taken')
        end
      end

      context 'when from scan result policy' do
        let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
        let_it_be(:policy_idx) { 1 }
        let_it_be(:action_idx) { 0 }

        it 'validates uniqueness of name scoped to project_id, rule_type, policy_configuration_id, policy_idx, and action_idx' do
          create(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          duplicate_rule = build(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          expect(duplicate_rule).to be_invalid
          expect(duplicate_rule.errors[:name]).to include('has already been taken')
        end

        it 'allows same name with different policy configuration' do
          policy_configuration2 = create(:security_orchestration_policy_configuration)
          create(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration2,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          expect(rule2).to be_valid
        end

        it 'allows same name with different policy index' do
          create(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx + 1,
            approval_policy_action_idx: action_idx
          )

          expect(rule2).to be_valid
        end

        it 'allows same name with different action index' do
          create(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_project_rule, :any_merge_request,
            project: project,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx + 1
          )

          expect(rule2).to be_valid
        end
      end
    end
  end

  describe 'default values' do
    subject(:rule) { described_class.new }

    it { expect(rule.scanners).to eq([]) }
    it { expect(rule.vulnerabilities_allowed).to eq(0) }
  end

  describe 'scanners' do
    it 'transform existing NULL values into empty array' do
      rule.update_column(:scanners, nil)

      expect(rule.reload.scanners).to eq([])
    end

    it 'prevents assignment of NULL' do
      rule.scanners = nil

      expect(rule.scanners).to eq([])
    end

    it 'prevents assignment of NULL via assign_attributes' do
      rule.assign_attributes(scanners: nil)

      expect(rule.scanners).to eq([])
    end
  end

  describe 'associations' do
    subject { build_stubbed(:approval_project_rule) }

    it { is_expected.to have_many(:approval_merge_request_rule_sources) }
    it { is_expected.to have_many(:approval_merge_request_rules).through(:approval_merge_request_rule_sources) }
  end

  describe '.regular' do
    it 'returns non-report_approver records' do
      rules = create_list(:approval_project_rule, 2)
      create(:approval_project_rule, :license_scanning)

      expect(described_class.regular).to contain_exactly(*rules)
    end
  end

  describe '.for_all_branches' do
    it 'returns approval rules applied to no protected branches' do
      project = create(:project)

      create(:approval_project_rule, project: project, applies_to_all_protected_branches: true)
      create(:protected_branch, project: project, approval_project_rules: [
        create(:approval_project_rule, project: project)
      ])

      rule_for_all_branches = create(:approval_project_rule, project: project)

      expect(described_class.for_all_branches).to eq([rule_for_all_branches])
    end
  end

  describe '.for_all_protected_branches' do
    it 'returns approval rules applied to all protected branches' do
      project = create(:project)

      rule_for_protected_branches =
        create(:approval_project_rule, project: project, applies_to_all_protected_branches: true)

      create(:approval_project_rule, project: project)
      rule = create(:approval_project_rule, project: project)
      create(:protected_branch, project: project, approval_project_rules: [rule])

      expect(described_class.for_all_protected_branches).to eq([rule_for_protected_branches])
    end
  end

  describe '.for_project' do
    it 'returns approval rules belonging to a project' do
      project1 = create(:project)
      project2 = create(:project)

      rule_for_project1 = create(:approval_project_rule, project: project1)
      create(:approval_project_rule, project: project2)

      expect(described_class.for_project(project1)).to contain_exactly(rule_for_project1)
    end
  end

  describe '.with_protected_branches' do
    it 'returns approval rules attached to the given protected branches' do
      project = create(:project)

      matching_rule = create(:approval_project_rule, project: project)
      protected_branch = create(:protected_branch, project: project, approval_project_rules: [matching_rule])

      other_rule = create(:approval_project_rule, project: project)
      create(:protected_branch, project: project, approval_project_rules: [other_rule])

      create(:approval_project_rule, project: project)

      expect(described_class.with_protected_branches([protected_branch.id])).to contain_exactly(matching_rule)
    end

    it 'accepts a relation of protected branch IDs without an unbounded IN clause' do
      project = create(:project)

      matching_rule = create(:approval_project_rule, project: project)
      protected_branch = create(:protected_branch, project: project, approval_project_rules: [matching_rule])

      create(:approval_project_rule, project: project)

      branch_ids = ProtectedBranch.where(id: protected_branch.id).select(:id)

      expect(described_class.with_protected_branches(branch_ids)).to contain_exactly(matching_rule)
    end
  end

  describe '.regular_or_any_approver scope' do
    it 'returns regular or any-approver rules' do
      any_approver_rule = create(:approval_project_rule, rule_type: :any_approver)
      regular_rule = create(:approval_project_rule)
      create(:approval_project_rule, :license_scanning)

      expect(described_class.regular_or_any_approver).to(
        contain_exactly(any_approver_rule, regular_rule)
      )
    end
  end

  describe '.not_regular_or_any_approver scope' do
    it 'returns all rules but regular or any-approver' do
      create(:approval_project_rule, rule_type: :any_approver)
      create(:approval_project_rule)
      licence_rule = create(:approval_project_rule, :license_scanning)
      code_owner_rule = create(:approval_project_rule, :code_owner)
      code_coverage_rule = create(:approval_project_rule, :code_coverage)
      scan_finding_rule = create(:approval_project_rule, :scan_finding)
      any_mr_rule = create(:approval_project_rule, :any_merge_request)

      expect(described_class.not_regular_or_any_approver).to(
        contain_exactly(licence_rule, code_owner_rule, code_coverage_rule, scan_finding_rule, any_mr_rule)
      )
    end
  end

  describe '.for_policy_configuration scope' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:any_approver_rule) { create(:approval_project_rule, rule_type: :any_approver) }
    let_it_be(:approval_rule) do
      create(:approval_project_rule, :scan_finding, :requires_approval,
        project: project,
        orchestration_policy_idx: 1,
        scanners: [:sast],
        severity_levels: [:high],
        vulnerability_states: [:confirmed],
        vulnerabilities_allowed: 2,
        security_orchestration_policy_configuration: policy_configuration
      )
    end

    it 'returns rules matching configuration id' do
      expect(described_class.for_policy_configuration(policy_configuration.id)).to match_array([approval_rule])
    end
  end

  describe '.for_policy_index scope' do
    let_it_be(:policy_index) { 1 }
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:any_approver_rule) { create(:approval_project_rule, rule_type: :any_approver) }
    let_it_be(:policy_approval_rule) do
      create(:approval_project_rule, :scan_finding, :requires_approval,
        project: project, orchestration_policy_idx: policy_index, security_orchestration_policy_configuration: policy_configuration
      )
    end

    it 'returns rules matching configuration id' do
      expect(described_class.for_policy_index(policy_index)).to match_array([policy_approval_rule])
    end
  end

  describe '.code_owner scope' do
    it 'returns nothing' do
      create_list(:approval_project_rule, 2)

      expect(described_class.code_owner).to be_empty
    end
  end

  shared_examples '.not_from_scan_result_policy scope' do
    it 'returns regular or any-approver rules' do
      any_approver_rule = create(:approval_project_rule, rule_type: :any_approver)
      regular_rule = create(:approval_project_rule)
      create(:approval_project_rule, :license_scanning)
      create(:approval_project_rule, :scan_finding)
      create(:approval_project_rule, :any_merge_request)

      expect(subject).to(
        contain_exactly(any_approver_rule, regular_rule)
      )
    end
  end

  describe '.exportable' do
    subject { described_class.exportable }

    include_examples '.not_from_scan_result_policy scope'
  end

  describe '.not_from_scan_result_policy' do
    subject { described_class.not_from_scan_result_policy }

    include_examples '.not_from_scan_result_policy scope'
  end

  describe '.from_scan_result_policy' do
    it 'returns scan_finding, license_scanning and any_merge_request rules' do
      create(:approval_project_rule, rule_type: :any_approver)
      create(:approval_project_rule)
      license_scanning = create(:approval_project_rule, :license_scanning)
      scan_finding = create(:approval_project_rule, :scan_finding)
      any_merge_request = create(:approval_project_rule, :any_merge_request)

      expect(described_class.from_scan_result_policy).to(
        contain_exactly(license_scanning, scan_finding, any_merge_request)
      )
    end
  end

  describe '.report_approver_without_policy_report_types' do
    subject { described_class.report_approver_without_policy_report_types }

    let_it_be(:regular_rule) { create(:approval_project_rule) }
    let_it_be(:code_owner_rule) { create(:code_owner_rule) }
    let_it_be(:any_approver_rule) { create(:any_approver_rule) }
    let_it_be_with_reload(:code_coverage_rule) { create(:approval_project_rule, :code_coverage) }
    let_it_be(:license_scanning_rule) { create(:approval_project_rule, :license_scanning) }
    let_it_be(:scan_finding_rule) { create(:approval_project_rule, :scan_finding) }
    let_it_be(:any_merge_request_rule) { create(:approval_project_rule, :any_merge_request) }

    it { is_expected.to include(code_coverage_rule) }

    it do
      is_expected.not_to include(regular_rule, code_owner_rule, any_approver_rule, scan_finding_rule,
        license_scanning_rule, any_merge_request_rule)
    end
  end

  describe '#protected_branches' do
    let(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:rule_protected_branch) { create(:protected_branch) }
    let(:protected_branches) { create_list(:protected_branch, 3, project: project) }
    let(:group_protected_branches) { create_list(:protected_branch, 2, project: nil, group: group) }
    let(:rule) { create(:approval_project_rule, protected_branches: [rule_protected_branch], project: project) }

    subject(:associated_protected_branches) { rule.protected_branches }

    context 'when applies_to_all_protected_branches is true' do
      before do
        rule.update!(applies_to_all_protected_branches: true)
      end

      it 'returns a collection of all protected branches belonging to the project and the group' do
        expect(associated_protected_branches).to contain_exactly(*protected_branches, *group_protected_branches)
      end
    end

    context 'when applies_to_all_protected_branches is false' do
      before do
        rule.update!(applies_to_all_protected_branches: false)
      end

      it 'returns a collection of all protected branches belonging to the rule' do
        expect(associated_protected_branches).to contain_exactly(rule_protected_branch)
      end
    end
  end

  describe '#applies_to_branch?' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

    shared_context 'when rule is created from security policy' do |policy_type, with_protected_branches: true|
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
      let(:applies_for_all_protected_branches) { false }

      subject(:policy_rule) do
        create(:approval_project_rule, policy_type, :requires_approval,
          project: project,
          security_orchestration_policy_configuration: policy_configuration,
          applies_to_all_protected_branches: applies_for_all_protected_branches,
          protected_branches: with_protected_branches ? [protected_branch] : [],
          scan_result_policy_read: create(:scan_result_policy_read,
            project: project,
            security_orchestration_policy_configuration: policy_configuration)
        )
      end

      context "for #{policy_type} policy and #{with_protected_branches ? 'with' : 'without'} protected branches" do
        context 'when branch is not protected in project configuration' do
          if with_protected_branches
            it 'returns false' do
              expect(policy_rule.applies_to_branch?('unprotected_branch')).to be false
            end
          else
            context 'when applies_to_all_protected_branches is true' do
              let(:applies_for_all_protected_branches) { true }

              it 'returns false' do
                expect(policy_rule.applies_to_branch?('unprotected_branch')).to be false
              end
            end

            context 'when applies_to_all_protected_branches is false' do
              let(:applies_for_all_protected_branches) { false }

              it 'returns false' do
                expect(policy_rule.applies_to_branch?('unprotected_branch')).to be false
              end
            end
          end
        end

        context 'when branch is protected in project configuration' do
          it 'returns true' do
            expect(policy_rule.applies_to_branch?(protected_branch.name)).to be true
          end
        end
      end
    end

    # we are not testing scan_finding without protected branches as this is prevented from creation with validation rule
    it_behaves_like 'when rule is created from security policy', :scan_finding, with_protected_branches: true
    it_behaves_like 'when rule is created from security policy', :license_scanning, with_protected_branches: true
    it_behaves_like 'when rule is created from security policy', :license_scanning, with_protected_branches: false
    it_behaves_like 'when rule is created from security policy', :any_merge_request, with_protected_branches: true
    it_behaves_like 'when rule is created from security policy', :any_merge_request, with_protected_branches: false

    context 'when rule has no specific branches' do
      context 'when rule is not created from security policy' do
        it 'returns true' do
          expect(rule.applies_to_branch?('branch_name')).to be true
        end
      end
    end

    context 'when rule has specific branches' do
      before do
        rule.protected_branches << protected_branch
      end

      it 'returns true when the branch name matches' do
        expect(rule.applies_to_branch?(protected_branch.name)).to be true
      end

      it 'returns false when the branch name does not match' do
        expect(rule.applies_to_branch?('random-branch-name')).to be false
      end
    end

    context 'when rule applies to all protected branches' do
      let_it_be_with_reload(:wildcard_protected_branch) { create(:protected_branch, name: "stable-*") }

      before do
        rule.update!(applies_to_all_protected_branches: true)
      end

      context 'and project has protected branches' do
        before do
          rule.project.protected_branches << protected_branch
          rule.project.protected_branches << wildcard_protected_branch
        end

        it 'returns true when the branch name is a protected branch' do
          expect(rule.reload.applies_to_branch?(protected_branch.name)).to be true
        end

        it 'returns true when the branch name is a wildcard protected branch' do
          expect(rule.reload.applies_to_branch?('stable-12')).to be true
        end

        it 'returns false when the branch name does not match a wildcard protected branch' do
          expect(rule.reload.applies_to_branch?('unstable1-12')).to be false
        end

        it 'returns false when the branch name is an unprotected branch' do
          expect(rule.applies_to_branch?('add-balsamiq-file')).to be false
        end

        it 'returns false when the branch name does not exist' do
          expect(rule.applies_to_branch?('this-is-not-a-real-branch')).to be false
        end

        context 'when protected branches are already loaded' do
          it 'still returns true when the branch name is a protected branch' do
            rule.reload
            rule.protected_branches.load

            expect(rule.applies_to_branch?(protected_branch.name)).to be true
          end
        end
      end

      context 'and project has no protected branches' do
        it 'returns false for the passed branches' do
          expect(rule.applies_to_branch?('add-balsamiq-file')).to be false
        end
      end
    end
  end

  describe '#regular?' do
    let(:license_scanning_approver_rule) { build(:approval_project_rule, :license_scanning) }

    it 'returns true for regular rules' do
      expect(rule.regular?).to be(true)
    end

    it 'returns false for report_approver rules' do
      expect(license_scanning_approver_rule.regular?).to be(false)
    end
  end

  describe '#code_owner?' do
    it 'returns false' do
      expect(rule.code_owner?).to be(false)
    end
  end

  describe '#report_approver?' do
    let(:license_scanning_approver_rule) { build(:approval_project_rule, :license_scanning) }

    it 'returns false for regular rules' do
      expect(rule.report_approver?).to be(false)
    end

    it 'returns true for report_approver rules' do
      expect(license_scanning_approver_rule.report_approver?).to be(true)
    end
  end

  describe '#rule_type' do
    it 'returns the regular type for regular rules' do
      expect(build(:approval_project_rule).rule_type).to eq('regular')
    end

    it 'returns the report_approver type for license scanning approvers rules' do
      expect(build(:approval_project_rule, :license_scanning).rule_type).to eq('report_approver')
    end
  end

  describe "#apply_report_approver_rules_to" do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:merge_request) { create(:merge_request, target_branch: 'main') }
    let_it_be(:project, freeze: false) { merge_request.target_project }
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }

    let_it_be_with_reload(:approval_policy_rule) { create(:approval_policy_rule) }

    let_it_be(:security_orchestration_policy_configuration, freeze: false) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: merge_request.target_branch) }
    let_it_be_with_reload(:non_matching_protected_branch) { create(:protected_branch, project: project, name: 'non-matching-branch') }

    let_it_be(:approval_policy_rule_project_link, freeze: false) do
      create(:approval_policy_rule_project_link,
        approval_policy_rule: approval_policy_rule,
        project: project)
    end

    describe 'attributes' do
      where(:default_name, :report_type, :rules_count) do
        'License-Check'  | :license_scanning  | 2
        'Coverage-Check' | :code_coverage     | 1
        'Scan finding'   | :scan_finding      | 2
        'Any MR'         | :any_merge_request | 2
      end

      before do
        rules.each do |rule|
          rule.users << user
          rule.groups << group
        end
      end

      with_them do
        subject(:rules) do
          create_list(:approval_project_rule, rules_count, report_type, :requires_approval,
            :for_all_protected_branches,
            project: project,
            orchestration_policy_idx: 1,
            scanners: [:sast],
            severity_levels: [:high],
            vulnerability_states: [:confirmed],
            vulnerabilities_allowed: 2,
            approval_policy_rule: approval_policy_rule,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration,
            approvals_required: 2
          )
        end

        it 'creates merge_request approval rules with correct attributes', :aggregate_failures do
          result = rules.map { |rule| rule.apply_report_approver_rules_to(merge_request) }

          expect(merge_request.reload.approval_rules).to match_array(result)
          expect(rules.count).to eq rules_count

          result.each do |result_rule|
            expect(result_rule.users).to match_array([user])
            expect(result_rule.groups).to match_array([group])
            expect(result_rule.name).to include(default_name)
            expect(result_rule).to be_report_approver
            expect(result_rule.report_type).to eq(report_type.to_s)
            expect(result_rule.orchestration_policy_idx).to be 1
            expect(result_rule.approval_policy_action_idx).to be 0
            expect(result_rule.approval_policy_rule_id).to eq(approval_policy_rule.id)
            expect(result_rule.scanners).to contain_exactly('sast')
            expect(result_rule.severity_levels).to contain_exactly('high')
            expect(result_rule.vulnerability_states).to contain_exactly('confirmed')
            expect(result_rule.vulnerabilities_allowed).to be 2
            expect(result_rule.approvals_required).to be 2
            expect(result_rule.security_orchestration_policy_configuration.id).to be security_orchestration_policy_configuration.id
          end
        end

        context 'when a block is given' do
          it 'creates merge_request approval rules with correct attributes', :aggregate_failures do
            result = rules.map do |rule|
              rule.apply_report_approver_rules_to(merge_request) do |rule_attributes|
                rule_attributes[:approvals_required] = 0
              end
            end

            expect(merge_request.reload.approval_rules).to match_array(result)
            expect(rules.count).to eq rules_count

            result.each do |result_rule|
              expect(result_rule.users).to match_array([user])
              expect(result_rule.groups).to match_array([group])
              expect(result_rule.name).to include(default_name)
              expect(result_rule).to be_report_approver
              expect(result_rule.report_type).to eq(report_type.to_s)
              expect(result_rule.orchestration_policy_idx).to be 1
              expect(result_rule.scanners).to contain_exactly('sast')
              expect(result_rule.severity_levels).to contain_exactly('high')
              expect(result_rule.vulnerability_states).to contain_exactly('confirmed')
              expect(result_rule.vulnerabilities_allowed).to be 2
              expect(result_rule.approvals_required).to be 0
              expect(result_rule.security_orchestration_policy_configuration.id).to be security_orchestration_policy_configuration.id
            end
          end
        end

        context 'when approval project rule does not apply to target branch' do
          before do
            rules.each do |rule|
              rule.update!(protected_branches: [non_matching_protected_branch], applies_to_all_protected_branches: false)
            end
          end

          it 'does not create a merge_request approval rules' do
            result = rules.map { |rule| rule.apply_report_approver_rules_to(merge_request) }

            expect(result).to all(be_nil)
            expect(merge_request.reload.approval_rules).to be_empty
          end
        end
      end
    end

    describe "violations" do
      let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

      let_it_be_with_reload(:approval_rule) do
        create(
          :approval_project_rule,
          :scan_finding,
          :requires_approval,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read)
      end

      context "without existent violation" do
        before do
          Security::ScanResultPolicyViolation.delete_all
        end

        it "creates a violation" do
          expect { approval_rule.apply_report_approver_rules_to(merge_request) }.to change { project.reload.scan_result_policy_violations.count }.by(1)
        end

        it "sets attributes" do
          approval_rule.apply_report_approver_rules_to(merge_request)

          attrs = project.scan_result_policy_violations.reload.last.attributes

          expect(attrs).to include(
            "scan_result_policy_id" => scan_result_policy_read.id,
            "approval_policy_rule_id" => approval_policy_rule.id,
            "merge_request_id" => merge_request.id,
            "project_id" => project.id,
            "status" => "running")
        end
      end

      context "with existent violation" do
        it "upserts" do
          expect { 2.times { approval_rule.apply_report_approver_rules_to(merge_request) } }.to change { project.reload.scan_result_policy_violations.count }.by(1)
        end
      end

      context "when with_violation: false is passed" do
        before do
          Security::ScanResultPolicyViolation.delete_all
        end

        it "does not create a violation" do
          expect { approval_rule.apply_report_approver_rules_to(merge_request, with_violation: false) }
            .not_to change { project.reload.scan_result_policy_violations.count }
        end

        it "still creates the merge request approval rule" do
          expect { approval_rule.apply_report_approver_rules_to(merge_request, with_violation: false) }
            .to change { merge_request.reload.approval_rules.count }.by(1)
        end
      end

      context "when approval project rule does not apply to target branch" do
        before_all do
          approval_rule.update!(protected_branches: [non_matching_protected_branch], applies_to_all_protected_branches: false)
        end

        context 'without existent violation' do
          before do
            Security::ScanResultPolicyViolation.delete_all
          end

          it 'does not create a violation' do
            expect { approval_rule.apply_report_approver_rules_to(merge_request) }.not_to change { project.reload.scan_result_policy_violations.count }
          end
        end

        context "when rule and violation already exist" do
          before_all do
            mr_rule = create(:report_approver_rule, :scan_finding,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule)

            create(:approval_merge_request_rule_source,
              approval_merge_request_rule: mr_rule,
              approval_project_rule: approval_rule)

            create(:scan_result_policy_violation,
              merge_request: merge_request,
              project: project,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule)
          end

          it "deletes the existing outdated merge request rule" do
            expect { approval_rule.apply_report_approver_rules_to(merge_request) }
              .to change { merge_request.reload.approval_rules.count }.by(-1)
          end

          it "deletes the existing outdated violation" do
            expect { approval_rule.apply_report_approver_rules_to(merge_request) }
              .to change { project.reload.scan_result_policy_violations.count }.by(-1)
          end

          context 'when rule does not have scan_result_policy_id' do
            let_it_be(:code_coverage_rule, freeze: false) do
              create(:approval_project_rule, :code_coverage, :requires_approval, project: project)
            end

            before_all do
              mr_rule = create(:report_approver_rule, :code_coverage,
                merge_request: merge_request)

              create(:approval_merge_request_rule_source,
                approval_merge_request_rule: mr_rule,
                approval_project_rule: code_coverage_rule)

              code_coverage_rule.update!(protected_branches: [non_matching_protected_branch], applies_to_all_protected_branches: false)
            end

            it 'does not attempt to delete violations' do
              expect { code_coverage_rule.apply_report_approver_rules_to(merge_request) }
                .not_to change { project.reload.scan_result_policy_violations.count }
            end

            it 'still deletes the rule' do
              expect { code_coverage_rule.apply_report_approver_rules_to(merge_request) }
                .to change { merge_request.reload.approval_rules.count }.by(-1)
            end
          end
        end
      end
    end

    context 'logging' do
      let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

      let_it_be_with_reload(:approval_rule) do
        create(:approval_project_rule, :scan_finding, :requires_approval,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          approval_policy_rule: approval_policy_rule, scan_result_policy_read: scan_result_policy_read)
      end

      before do
        allow(Gitlab::AppJsonLogger).to receive(:info)
      end

      it 'logs when security_orchestration_policy_configuration_id is present' do
        returned_rule = approval_rule.apply_report_approver_rules_to(merge_request)

        expect(Gitlab::AppJsonLogger).to have_received(:info).with(
          hash_including(
            event: 'approval_merge_request_rule_changed',
            approval_project_rule_id: approval_rule.id,
            approval_merge_request_rule_id: returned_rule.id,
            merge_request_iid: merge_request.iid,
            approvals_required: returned_rule.approvals_required,
            security_orchestration_policy_configuration_id: approval_rule.security_orchestration_policy_configuration_id,
            scan_result_policy_id: returned_rule.scan_result_policy_id,
            project_path: project.full_path
          )
        )
      end

      it 'does not log when rule is not persisted' do
        approval_rule.update!(protected_branches: [non_matching_protected_branch], applies_to_all_protected_branches: false)
        approval_rule.apply_report_approver_rules_to(merge_request)

        expect(approval_rule.reload.approval_merge_request_rules).to be_empty
        expect(Gitlab::AppJsonLogger).not_to have_received(:info)
      end
    end

    describe 'retry on ActiveRecord::RecordNotUnique' do
      let_it_be(:approval_rule) do
        create(:approval_project_rule, :scan_finding, approval_policy_rule: approval_policy_rule, project: project)
      end

      it 'retries once and succeeds when the unique index conflicts' do
        call_count = 0
        allow(approval_rule).to receive(:update_report_approver_rule_for_merge_request).and_wrap_original do |original, *args, **kwargs, &blk|
          call_count += 1
          raise ActiveRecord::RecordNotUnique if call_count == 1

          original.call(*args, **kwargs, &blk)
        end

        expect { approval_rule.apply_report_approver_rules_to(merge_request) }
          .to change { merge_request.approval_rules.count }.by(1)

        expect(call_count).to eq(2)
      end

      it 're-raises when the conflict persists after a retry' do
        allow(approval_rule).to receive(:update_report_approver_rule_for_merge_request)
          .and_raise(ActiveRecord::RecordNotUnique)

        expect { approval_rule.apply_report_approver_rules_to(merge_request) }
          .to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'wraps the work in a transaction so racing inserts roll back atomically' do
        expect(ApplicationRecord).to receive(:transaction).and_call_original

        approval_rule.apply_report_approver_rules_to(merge_request)
      end
    end

    describe 'guard against concurrent unlink' do
      let_it_be(:approval_rule) do
        create(:approval_project_rule, :scan_finding, approval_policy_rule: approval_policy_rule, project: project)
      end

      context 'when the policy-project link is present' do
        it 'creates the merge request rule' do
          expect { approval_rule.apply_report_approver_rules_to(merge_request) }
            .to change { merge_request.approval_rules.count }.by(1)
        end
      end

      context 'when the policy-project link is absent' do
        before do
          Security::ApprovalPolicyRuleProjectLink
            .where(id: approval_policy_rule_project_link.id)
            .delete_all
        end

        it 'does not create a merge request rule' do
          expect { approval_rule.apply_report_approver_rules_to(merge_request) }
            .not_to change { merge_request.approval_rules.count }
        end

        it 'returns nil' do
          expect(approval_rule.apply_report_approver_rules_to(merge_request)).to be_nil
        end
      end

      context 'when approval_policy_rule_id is blank' do
        let_it_be(:non_policy_rule) do
          create(:approval_project_rule, :code_coverage, :requires_approval, project: project)
        end

        it 'creates the merge request rule without probing the link table' do
          expect(Security::ApprovalPolicyRuleProjectLink).not_to receive(:for_project_and_policy_rule)

          expect { non_policy_rule.apply_report_approver_rules_to(merge_request) }
            .to change { merge_request.approval_rules.count }.by(1)
        end
      end
    end
  end

  describe "validation" do
    let(:project_approval_rule) { create(:approval_project_rule) }
    let(:license_compliance_rule) { create(:approval_project_rule, :license_scanning) }
    let(:coverage_check_rule) { create(:approval_project_rule, :code_coverage) }

    context "when creating a new rule" do
      specify { expect(project_approval_rule).to be_valid }
      specify { expect(license_compliance_rule).to be_valid }
      specify { expect(coverage_check_rule).to be_valid }
    end

    context "when attempting to edit the name of the rule" do
      subject(:approval_rule) { project_approval_rule }

      before do
        approval_rule.name = SecureRandom.uuid
      end

      specify { expect(approval_rule).to be_valid }

      context "with a `Coverage-Check` rule" do
        subject(:approval_rule) { coverage_check_rule }

        specify { expect(approval_rule).not_to be_valid }
        specify { expect { approval_rule.valid? }.to change { approval_rule.errors[:report_type].present? } }
      end
    end

    context 'for report type different than scan_finding' do
      it 'is invalid when name not unique within rule type and project' do
        is_expected.to validate_uniqueness_of(:name).scoped_to([:project_id, :rule_type])
      end

      context 'is valid when protected branches are empty and is applied to all protected branches' do
        subject { build(:approval_project_rule, :code_coverage, protected_branches: [], applies_to_all_protected_branches: false) }

        it { is_expected.to be_valid }
      end
    end

    context 'for scan_finding report type' do
      subject { create(:approval_project_rule, :scan_finding) }

      it 'is invalid when name not unique within scan result policy, rule type and project' do
        is_expected.to validate_uniqueness_of(:name).scoped_to([
          :project_id, :rule_type, :security_orchestration_policy_configuration_id,
          :orchestration_policy_idx, :approval_policy_action_idx
        ])
      end

      context 'when no protected branches are selected and is not applied to all protected branches' do
        subject { build(:approval_project_rule, :scan_finding, protected_branches: [], applies_to_all_protected_branches: false) }

        it { is_expected.to be_valid }
      end

      context 'when protected branches are present and is not applied to all protected branches' do
        let_it_be_with_reload(:project) { create(:project) }
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, name: 'main', project: project) }

        subject { build(:approval_project_rule, :scan_finding, protected_branches: [protected_branch], applies_to_all_protected_branches: false, project: project) }

        it { is_expected.to be_valid }
      end

      context 'when protected branches are present and is applied to all protected branches' do
        let_it_be_with_reload(:project) { create(:project) }
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, name: 'main', project: project) }

        subject { build(:approval_project_rule, :scan_finding, protected_branches: [protected_branch], applies_to_all_protected_branches: true, project: project) }

        it { is_expected.to be_valid }
      end

      context 'when protected branches are not selected and is applied to all protected branches' do
        subject { build(:approval_project_rule, :scan_finding, protected_branches: [], applies_to_all_protected_branches: true) }

        it { is_expected.to be_valid }
      end
    end
  end

  context 'any_approver rules' do
    let(:project) { create(:project) }
    let(:rule) { build(:approval_project_rule, project: project, rule_type: :any_approver) }

    it 'creating only one any_approver rule is allowed' do
      create(:approval_project_rule, project: project, rule_type: :any_approver)

      expect(rule).not_to be_valid
      expect(rule.errors.messages).to eq(rule_type: ['any-approver for the project already exists'])
      expect { rule.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'callbacks', :request_store do
    let_it_be_with_reload(:user) { create(:user, name: 'Batman') }
    let_it_be(:group) { create(:group, name: 'Justice League') }

    let_it_be(:new_user) { create(:user, name: 'Spiderman') }
    let_it_be(:new_group) { create(:group, name: 'Avengers') }

    # using let_it_be_with_reload doesn't clear AfterCommitQueue properly and makes the tests order-dependent
    let!(:rule) { create(:approval_project_rule, name: 'Vulnerability', users: [user], groups: [group]) }

    describe '#track_creation_event tracks count after create' do
      let_it_be(:approval_project_rule, freeze: false) { build(:approval_project_rule) }

      it 'calls Gitlab::UsageDataCounters::HLLRedisCounter track event' do
        allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)

        approval_project_rule.save!

        expect(Gitlab::UsageDataCounters::HLLRedisCounter).to have_received(:track_event)
                                                                .with('approval_project_rule_created', values: approval_project_rule.id)
      end
    end

    describe '#audit_add users after :add' do
      let(:action!) { rule.update!(users: [user, new_user]) }
      let(:message) { 'Added User Spiderman to approval group on Vulnerability rule' }
      let(:invalid_action) do
        rule.update(users: [user, new_user], # rubocop:disable Rails/SaveBang
          approvals_required: ApprovalRuleLike::APPROVALS_REQUIRED_MAX + 1)
      end

      it_behaves_like 'audit event queue'
      it_behaves_like 'invalid record creates no audit event'
    end

    describe '#audit_remove users after :remove' do
      let(:action!) { rule.update!(users: []) }
      let(:message) { 'Removed User Batman from approval group on Vulnerability rule' }
      let(:invalid_action) do
        rule.update(users: [], # rubocop:disable Rails/SaveBang
          approvals_required: ApprovalRuleLike::APPROVALS_REQUIRED_MAX + 1)
      end

      it_behaves_like 'audit event queue'
      it_behaves_like 'invalid record creates no audit event'
    end

    describe '#audit_add groups after :add' do
      let(:action!) { rule.update!(groups: [group, new_group]) }
      let(:message) { 'Added Group Avengers to approval group on Vulnerability rule' }
      let(:invalid_action) do
        rule.update(groups: [group, new_group], # rubocop:disable Rails/SaveBang
          approvals_required: ApprovalRuleLike::APPROVALS_REQUIRED_MAX + 1)
      end

      it_behaves_like 'audit event queue'
      it_behaves_like 'invalid record creates no audit event'
    end

    describe '#audit_remove groups after :remove' do
      let(:action!) { rule.update!(groups: []) }
      let(:message) { 'Removed Group Justice League from approval group on Vulnerability rule' }
      let(:invalid_action) do
        rule.update(groups: [], # rubocop:disable Rails/SaveBang
          approvals_required: ApprovalRuleLike::APPROVALS_REQUIRED_MAX + 1)
      end

      it_behaves_like 'audit event queue'
      it_behaves_like 'invalid record creates no audit event'
    end

    describe "#audit_creation after approval rule is created" do
      let(:action!) { create(:approval_project_rule, approvals_required: 1) }
      let(:message) { 'Added approval rule with number of required approvals of 1' }

      it_behaves_like 'audit event queue'
    end

    describe '#vulnerability_states_for_branch' do
      let(:project) { create(:project) }
      let(:branch_name) { project.default_branch }
      let(:vulnerability_states) { %w[new_needs_triage resolved] }
      let!(:rule) { build(:approval_project_rule, project: project, protected_branches: protected_branches, vulnerability_states: vulnerability_states) }

      context 'with protected branch set to any' do
        let(:protected_branches) { [] }

        it 'returns all content of vulnerability states' do
          expect(rule.vulnerability_states_for_branch).to contain_exactly('new_needs_triage', 'resolved')
        end

        context 'when vulnerabilty_states is empty' do
          let(:vulnerability_states) { [] }

          it 'returns only default states' do
            expect(rule.vulnerability_states_for_branch).to contain_exactly('new_needs_triage', 'new_dismissed')
          end
        end
      end

      context 'with protected branch set to a custom branch' do
        let(:protected_branches) { [create(:protected_branch, project: project, name: 'custom_branch')] }

        it 'returns only the content of vulnerability states' do
          expect(rule.vulnerability_states_for_branch).to contain_exactly('new_needs_triage')
        end

        context 'when vulnerabilty_states is empty' do
          let(:vulnerability_states) { [] }

          it 'returns only default states' do
            expect(rule.vulnerability_states_for_branch).to contain_exactly('new_needs_triage', 'new_dismissed')
          end
        end
      end
    end
  end
end

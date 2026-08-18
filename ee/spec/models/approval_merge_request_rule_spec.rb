# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalMergeRequestRule, factory_default: :keep, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) { create_default(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create_default(:merge_request) }

  subject(:rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

  describe Security::ApprovalPolicyFiltering do
    include_examples 'approval rules filtering' do
      let(:approval_rule_project) { merge_request.target_project }
    end
  end

  describe 'associations' do
    subject { build_stubbed(:approval_merge_request_rule) }

    it { is_expected.to have_one(:approval_project_rule_project).through(:approval_project_rule) }
    it { is_expected.to have_one(:approval_project_rule).through(:approval_merge_request_rule_source) }
    it { is_expected.to have_many(:approval_merge_request_rules_users) }
    it { is_expected.to belong_to(:project) }

    it do
      is_expected.to have_many(:scan_result_policy_violations)
        .through(:scan_result_policy_read)
        .source(:violations)
    end
  end

  describe 'validations' do
    it 'is valid' do
      expect(build(:approval_merge_request_rule)).to be_valid
    end

    it 'is invalid when the name is missing' do
      expect(build(:approval_merge_request_rule, name: nil)).not_to be_valid
    end

    context 'when the merge request is merged' do
      let(:merge_request) { build_stubbed(:merge_request, :merged) }
      let(:rule) { build(:approval_merge_request_rule, merge_request: merge_request) }

      context 'when finalizing_rules is true' do
        before do
          merge_request.finalizing_rules = true
        end

        it 'is valid' do
          expect(rule).to be_valid
        end
      end

      context 'when finalizing_rules is not set' do
        it 'is not valid' do
          expect(rule).not_to be_valid
          expect(rule.errors[:merge_request]).to include(/must not be merged/)
        end
      end
    end

    context 'for report type different than scan_finding' do
      it 'is invalid when name not unique within rule type, merge request and applicable_post_merge' do
        is_expected.to validate_uniqueness_of(:name).scoped_to([:merge_request_id, :rule_type, :section,
          :applicable_post_merge])
      end
    end

    context 'for scan_finding report type' do
      subject { create(:approval_merge_request_rule, :scan_finding, merge_request: merge_request) }

      it 'is invalid when name not unique within scan result policy, rule type and merge request' do
        is_expected.to validate_uniqueness_of(:name).scoped_to([:merge_request_id, :rule_type,
          :security_orchestration_policy_configuration_id, :orchestration_policy_idx, :approval_policy_action_idx])
      end
    end

    context 'name uniqueness' do
      context 'when not from scan result policy' do
        it 'validates uniqueness of name scoped to merge_request_id and rule_type' do
          create(:approval_merge_request_rule, merge_request: merge_request, name: 'Test Rule')
          duplicate_rule = build(:approval_merge_request_rule, merge_request: merge_request, name: 'Test Rule')

          expect(duplicate_rule).to be_invalid
          expect(duplicate_rule.errors[:name]).to include('has already been taken')
        end
      end

      context 'when from scan result policy' do
        let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
        let_it_be(:policy_configuration2) { create(:security_orchestration_policy_configuration, :namespace) }

        let(:policy_idx) { 1 }
        let(:action_idx) { 0 }

        it 'validates name uniqueness scoped to rule_type, policy_config_id, policy_idx, action_idx' do
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          duplicate_rule = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          expect(duplicate_rule).to be_invalid
          expect(duplicate_rule.errors[:name]).to include('has already been taken')
        end

        it 'allows same name with different policy configuration' do
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration2,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          expect(rule2).to be_valid
        end

        it 'allows same name with different policy index' do
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx + 1,
            approval_policy_action_idx: action_idx
          )

          expect(rule2).to be_valid
        end

        it 'allows same name with different action index' do
          create(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx
          )

          rule2 = build(:approval_merge_request_rule, :any_merge_request,
            merge_request: merge_request,
            name: 'Test Rule',
            security_orchestration_policy_configuration: policy_configuration,
            orchestration_policy_idx: policy_idx,
            approval_policy_action_idx: action_idx + 1
          )

          expect(rule2).to be_valid
        end
      end
    end

    context 'approval_project_rule is set' do
      let(:approval_project_rule) { build(:approval_project_rule, project: build(:project)) }
      let(:merge_request_rule) do
        build(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule)
      end

      context 'when project of approval_project_rule and merge request matches' do
        let(:merge_request) { build(:merge_request, project: approval_project_rule.project) }

        it 'is valid' do
          expect(merge_request_rule).to be_valid
        end
      end

      context 'when the project of approval_project_rule and merge request does not match' do
        it 'is invalid' do
          expect(merge_request_rule).to be_invalid
        end
      end
    end

    context 'code owner rules' do
      it 'is valid' do
        expect(build(:code_owner_rule)).to be_valid
      end

      it 'is invalid when reusing the same name within the same merge request' do
        existing = create(:code_owner_rule, name: '*.rb', merge_request: merge_request, section: 'section')

        new = build(:code_owner_rule, merge_request: existing.merge_request, name: '*.rb', section: 'section')

        expect(new).not_to be_valid
        expect { new.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'allows a regular rule with the same name as the codeowner rule' do
        create(:code_owner_rule, name: '*.rb', merge_request: merge_request)

        new = build(:approval_merge_request_rule, name: '*.rb', merge_request: merge_request)

        expect(new).to be_valid
        expect { new.save! }.not_to raise_error
      end
    end

    context 'any_approver rules' do
      let(:rule) do
        build(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver,
          applicable_post_merge: true)
      end

      it 'only allows one rule for every any_approver rule type and applicable_post_merge value' do
        create(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver,
          applicable_post_merge: false)

        expect(rule).to be_valid
        expect { rule.save!(validate: false) }.not_to raise_error

        dup_rule = build(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver,
          applicable_post_merge: true)

        expect(dup_rule).not_to be_valid
        expect(dup_rule.errors.messages).to eq(rule_type: ['any-approver for the merge request already exists'])
        expect { dup_rule.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context 'when role_approvers' do
      context 'rule_type is :code_owner' do
        it 'is not valid when not access value' do
          rule = build(:approval_merge_request_rule, rule_type: :code_owner, role_approvers: [1])

          expect(rule).not_to be_valid
          expect(rule.errors.messages).to eq(role_approvers: ["is not included in the list"])
        end

        it 'is valid with an access value' do
          expect(build(:approval_merge_request_rule, rule_type: :code_owner,
            role_approvers: [Gitlab::Access::DEVELOPER])).to be_valid
        end

        it 'is valid with two access values' do
          expect(build(:approval_merge_request_rule, rule_type: :code_owner,
            role_approvers: [Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER])).to be_valid
        end
      end

      context 'when rule_type is not :code_owner' do
        it 'is not valid' do
          rule = build(:approval_merge_request_rule, rule_type: :any_approver, role_approvers: [Gitlab::Access::DEVELOPER])

          expect(rule).not_to be_valid
          expect(rule.errors.messages).to eq(role_approvers: ["can only be added to codeowner type rules"])
        end
      end
    end
  end

  describe '.regular_or_any_approver scope' do
    it 'returns regular or any-approver rules' do
      any_approver_rule = create(:any_approver_rule)
      regular_rule = create(:approval_merge_request_rule)
      create(:report_approver_rule)

      expect(described_class.regular_or_any_approver).to(
        contain_exactly(any_approver_rule, regular_rule)
      )
    end
  end

  describe '.not_regular_or_any_approver scope' do
    it 'returns all rules but regular or any-approver' do
      create(:any_approver_rule)
      create(:approval_merge_request_rule)
      licence_rule = create(:report_approver_rule, :license_scanning)
      code_owner_rule = create(:code_owner_rule)
      code_coverage_rule = create(:report_approver_rule, :code_coverage)
      scan_finding_rule = create(:report_approver_rule, :scan_finding)
      any_mr_rule = create(:report_approver_rule, :any_merge_request)

      expect(described_class.not_regular_or_any_approver).to(
        contain_exactly(licence_rule, code_owner_rule, code_coverage_rule, scan_finding_rule, any_mr_rule)
      )
    end
  end

  context 'scopes' do
    let_it_be(:rb_rule) { create(:code_owner_rule, name: '*.rb') }
    let_it_be(:js_rule) { create(:code_owner_rule, name: '*.js') }
    let_it_be(:css_rule) { create(:code_owner_rule, name: '*.css') }
    let_it_be(:approval_rule) { create(:approval_merge_request_rule) }
    let_it_be(:report_approver_rule) { create(:report_approver_rule) }
    let_it_be(:coverage_rule) { create(:report_approver_rule, :code_coverage) }
    let_it_be(:license_rule) { create(:report_approver_rule, :license_scanning) }

    describe '.not_matching_id' do
      it 'returns the correct rules' do
        expect(described_class.not_matching_id([rb_rule.id, js_rule.id]))
          .to contain_exactly(css_rule)
      end
    end

    describe '.matching_pattern' do
      it 'returns the correct rules' do
        expect(described_class.matching_pattern(%w[*.rb *.js]))
          .to contain_exactly(rb_rule, js_rule)
      end
    end

    describe '.code_owners' do
      it 'returns the correct rules' do
        expect(described_class.code_owner)
          .to contain_exactly(rb_rule, js_rule, css_rule)
      end
    end

    describe '.license_compliance' do
      it 'returns the correct rules' do
        expect(described_class.license_compliance)
          .to contain_exactly(license_rule, report_approver_rule)
      end
    end

    describe '.coverage' do
      it 'returns the correct rules' do
        expect(described_class.coverage)
          .to contain_exactly(coverage_rule)
      end
    end

    describe '.with_projects_that_can_override_rules' do
      let_it_be(:disabled_project) do
        create(:project, :small_repo, disable_overriding_approvers_per_merge_request: true)
      end

      let_it_be(:enabled_project) do
        create(:project, :small_repo, disable_overriding_approvers_per_merge_request: false)
      end

      let_it_be(:nil_project) do
        create(:project, :small_repo, disable_overriding_approvers_per_merge_request: nil)
      end

      let_it_be(:disabled_rule) do
        create(:approval_merge_request_rule,
          merge_request: create(:merge_request, source_project: disabled_project, target_project: disabled_project),
          approval_project_rule: create(:approval_project_rule, project: disabled_project))
      end

      let_it_be(:enabled_rule) do
        create(:approval_merge_request_rule,
          merge_request: create(:merge_request, source_project: enabled_project, target_project: enabled_project),
          approval_project_rule: create(:approval_project_rule, project: enabled_project))
      end

      let_it_be(:nil_rule) do
        create(:approval_merge_request_rule,
          merge_request: create(:merge_request, source_project: nil_project, target_project: nil_project),
          approval_project_rule: create(:approval_project_rule, project: nil_project))
      end

      it 'returns the correct rules' do
        results = described_class.with_projects_that_can_override_rules

        expect(results).to contain_exactly(enabled_rule, nil_rule)
        expect(results).not_to include(disabled_rule)
      end
    end
  end

  describe '.for_project' do
    let_it_be(:project_a) { create(:project, :small_repo) }
    let_it_be(:project_b) { create(:project, :small_repo) }
    let_it_be(:mr_a) { create(:merge_request, source_project: project_a, target_project: project_a) }
    let_it_be(:mr_b) { create(:merge_request, source_project: project_b, target_project: project_b) }
    let_it_be(:rule_a) { create(:approval_merge_request_rule, merge_request: mr_a) }
    let_it_be(:rule_b) { create(:approval_merge_request_rule, merge_request: mr_b) }

    it 'returns rules for the given project' do
      expect(described_class.for_project(project_a.id)).to contain_exactly(rule_a)
    end
  end

  describe '.applicable_post_merge' do
    it 'returns only the rules applicable_post_merge true or nil' do
      create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: false)
      rule_2 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: true)
      rule_3 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: nil)

      expect(described_class.applicable_post_merge).to contain_exactly(rule_2, rule_3)
    end
  end

  describe '.find_or_create_code_owner_rule' do
    subject(:rule) { described_class.find_or_create_code_owner_rule(merge_request, entry) }

    let(:entry) { Gitlab::CodeOwners::Entry.new("*.js", "@user") }

    context "when there is an existing rule" do
      context "when the entry does not have the approvals_required field" do
        let_it_be(:existing_code_owner_rule) do
          create(:code_owner_rule, name: '*.rb', merge_request: merge_request)
        end

        let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user") }

        it 'finds the existing rule' do
          expect(rule).to eq(existing_code_owner_rule)
        end

        context "when the existing rule matches name but not section" do
          let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user", section: "example_section") }

          it "creates a new rule" do
            expect(rule).not_to eq(existing_code_owner_rule)
          end
        end
      end

      context "when the entry has the approvals_required field" do
        let_it_be(:existing_code_owner_rule) do
          create(:code_owner_rule, name: '*.rb', merge_request: merge_request, approvals_required: 2)
        end

        let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user", section: "codeowners", optional: false, approvals_required: 2) }

        it 'finds the existing rule' do
          expect(rule).to eq(existing_code_owner_rule)
        end

        context "when the existing rule matches name but not section" do
          let(:entry) { Gitlab::CodeOwners::Entry.new("*.rb", "@user", section: "example_section", optional: false, approvals_required: 2) }

          it "creates a new rule" do
            expect(rule).not_to eq(existing_code_owner_rule)
          end
        end
      end
    end

    it 'creates a new rule if it does not exist' do
      expect { rule }
        .to change { merge_request.approval_rules.matching_pattern('*.js').count }.by(1)
    end

    it 'finds an existing rule using rule_type column' do
      regular_rule_type_rule = create(
        :code_owner_rule,
        name: entry.pattern,
        merge_request: merge_request,
        rule_type: described_class.rule_types[:regular]
      )

      expect(rule).not_to eq(regular_rule_type_rule)
    end

    it 'retries when a record was created between the find and the create' do
      expect(described_class).to receive(:code_owner).and_raise(ActiveRecord::RecordNotUnique)
      allow(described_class).to receive(:code_owner).and_call_original

      expect(rule).not_to be_nil
    end

    context "when section is present" do
      let(:entry) { Gitlab::CodeOwners::Entry.new("*.js", "@user", section: "Test Section") }

      it "creates a new rule and saves section when present" do
        expect(subject.section).to eq(entry.section)
      end
    end
  end

  describe '#project' do
    it 'returns project of MergeRequest' do
      expect(subject.project).to be_present
      expect(subject.project).to eq(merge_request.project)
    end
  end

  describe '#regular' do
    it 'returns true for regular records' do
      subject = create(:approval_merge_request_rule, merge_request: merge_request)

      expect(subject.regular).to be(true)
      expect(subject.regular?).to be(true)
    end

    it 'returns false for code owner records' do
      subject = create(:code_owner_rule, merge_request: merge_request)

      expect(subject.regular).to be(false)
      expect(subject.regular?).to be(false)
    end

    it 'returns false for any approver records' do
      subject = create(:approval_merge_request_rule, merge_request: merge_request, rule_type: :any_approver)

      expect(subject.regular).to be(false)
      expect(subject.regular?).to be(false)
    end
  end

  describe '#code_owner?' do
    let(:code_owner_rule) { build(:code_owner_rule) }

    context "rule_type is :code_owner" do
      it "returns true" do
        expect(code_owner_rule.code_owner?).to be true
      end
    end

    context "rule_type is :regular" do
      before do
        code_owner_rule.rule_type = :regular
      end

      it "returns false" do
        expect(code_owner_rule.code_owner?).to be false
      end
    end
  end

  describe '#approvers' do
    include_context 'with merge request approval settings' do
      let(:approval_rule_project) { merge_request.target_project }
    end

    subject(:approvers) { described_class.find(rule.id).approvers }

    before_all do
      group.add_guest(merge_request.author)
    end

    before do
      rule.groups << group
    end

    shared_examples 'with preloaded users' do
      context 'when the rules users have already been loaded' do
        before do
          rule.users.to_a
          rule.group_users.to_a
        end

        it 'does not perform any new queries when all users are loaded already' do
          # single query is triggered for license check
          expect { rule.approvers }.not_to exceed_query_limit(1)
        end

        it { is_expected.to expected_approvers }
      end
    end

    context 'when author approval is allowed' do
      let(:expected_approvers) { contain_exactly(merge_request.author) }

      it { is_expected.to contain_exactly(merge_request.author) }

      it_behaves_like 'with preloaded users'
    end

    context 'when instance prevents author approval' do
      let(:instance_prevents_author_approval) { true }
      let(:expected_approvers) { be_empty }

      it { is_expected.to be_empty }

      it_behaves_like 'with preloaded users'
    end

    context 'when parent group prevents author approval' do
      let(:group_prevents_author_approval) { true }
      let(:expected_approvers) { be_empty }

      it { is_expected.to be_empty }

      it_behaves_like 'with preloaded users'
    end

    context 'when project prevents author approval' do
      let(:project_prevents_author_approval) { true }
      let(:expected_approvers) { be_empty }

      it { is_expected.to be_empty }

      it_behaves_like 'with preloaded users'
    end

    context 'when approval policy prevents author approval' do
      let(:approval_policy_prevents_author_approval) { true }
      let(:expected_approvers) { be_empty }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it { is_expected.to be_empty }

      it_behaves_like 'with preloaded users'

      context 'without licensed feature' do
        let(:expected_approvers) { contain_exactly(merge_request.author) }

        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to contain_exactly(merge_request.author) }

        it_behaves_like 'with preloaded users'
      end
    end

    context 'when project allows author approval but policy prevents it' do
      let(:approval_policy_prevents_author_approval) { true }
      let(:project_prevents_author_approval) { false }
      let(:expected_approvers) { be_empty }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it { is_expected.to be_empty }

      it_behaves_like 'with preloaded users'
    end
  end

  describe '#sync_approved_approvers' do
    let_it_be(:member1) { create(:user) }
    let_it_be(:member2) { create(:user) }
    let_it_be(:member3) { create(:user) }
    let!(:approval1) { create(:approval, merge_request: merge_request, user: member1) }
    let!(:approval2) { create(:approval, merge_request: merge_request, user: member2) }
    let!(:approval3) { create(:approval, merge_request: merge_request, user: member3) }

    let!(:any_approver_rule) { create(:any_approver_rule, merge_request: merge_request) }

    before do
      subject.users = [member1, member2]
    end

    context 'when not merged' do
      it 'does nothing' do
        subject.sync_approved_approvers
        any_approver_rule.sync_approved_approvers

        expect(subject.approved_approvers.reload).to be_empty
        expect(any_approver_rule.approved_approvers).to be_empty
      end
    end

    context 'when merged' do
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_branch: 'test') }

      before do
        merge_request.mark_as_merged!
      end

      context 'when merge request finalizing_rules is true' do
        before do
          subject.merge_request.finalizing_rules = true
        end

        it 'records approved approvers as approved_approvers association' do
          subject.sync_approved_approvers

          expect(subject.reload.approved_approvers).to contain_exactly(member1, member2)
        end

        it 'stores all the approvals for any-approver rule' do
          any_approver_rule.sync_approved_approvers

          expect(any_approver_rule.approved_approvers.reload).to contain_exactly(member1, member2, member3)
        end
      end

      context 'when finalizing_rules is false' do
        before do
          subject.merge_request.finalizing_rules = false
        end

        it 'does nothing' do
          subject.sync_approved_approvers
          any_approver_rule.sync_approved_approvers

          expect(subject.approved_approvers.reload).to be_empty
          expect(any_approver_rule.approved_approvers).to be_empty
        end
      end
    end
  end

  describe 'validations' do
    describe 'approvals_required' do
      subject { build(:approval_merge_request_rule, merge_request: merge_request) }

      it 'is a natural number' do
        subject.assign_attributes(approvals_required: 2)
        expect(subject).to be_valid

        subject.assign_attributes(approvals_required: 0)
        expect(subject).to be_valid

        subject.assign_attributes(approvals_required: -1)
        expect(subject).to be_invalid
      end
    end
  end

  describe '#vulnerability_states_for_branch' do
    let(:vulnerability_states) { [:detected, :new_needs_triage] }
    let(:approval_rule) do
      create(:approval_merge_request_rule, :scan_finding, vulnerability_states: vulnerability_states,
        merge_request: merge_request)
    end

    subject { approval_rule.vulnerability_states_for_branch }

    context 'with target branch equal to project default branch' do
      before do
        allow(merge_request).to receive(:target_branch).and_return("master")
      end

      it 'returns all vulnerability states' do
        expect(subject).to contain_exactly('detected', 'new_needs_triage')
      end
    end

    context 'with target branch different from project default branch' do
      it 'returns only newly detected' do
        expect(subject).to contain_exactly('new_needs_triage')
      end

      context 'when vulnerabilty_states is empty' do
        let(:vulnerability_states) { [] }

        it 'returns only default states' do
          expect(subject).to contain_exactly('new_needs_triage', 'new_dismissed')
        end
      end

      context 'without newly_detected' do
        let(:vulnerability_states) { [:detected, :confirmed] }

        it 'returns empty array' do
          expect(subject).to be_blank
        end
      end
    end
  end

  describe '#hook_attrs' do
    let_it_be(:rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

    subject(:hook_attrs) { rule.hook_attrs }

    it 'returns the expected attributes' do
      expect(hook_attrs).to eq({
        id: rule.id,
        approvals_required: rule.approvals_required,
        name: rule.name,
        rule_type: rule.rule_type,
        report_type: rule.report_type,
        merge_request_id: rule.merge_request_id,
        section: rule.section,
        modified_from_project_rule: rule.modified_from_project_rule,
        orchestration_policy_idx: rule.orchestration_policy_idx,
        vulnerabilities_allowed: rule.vulnerabilities_allowed,
        scanners: rule.scanners,
        severity_levels: rule.severity_levels,
        vulnerability_states: rule.vulnerability_states,
        security_orchestration_policy_configuration_id: rule.security_orchestration_policy_configuration_id,
        scan_result_policy_id: rule.scan_result_policy_id,
        applicable_post_merge: rule.applicable_post_merge,
        project_id: rule.project_id,
        approval_policy_rule_id: rule.approval_policy_rule_id,
        updated_at: rule.updated_at,
        created_at: rule.created_at
      })
    end
  end

  describe '#applicable_to_branch?' do
    let_it_be(:rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let(:branch) { 'stable' }

    subject { rule.applicable_to_branch?(branch) }

    shared_examples_for 'with applicable rules to specified branch' do
      it { is_expected.to be_truthy }
    end

    context 'with approval policy branch exceptions' do
      let_it_be(:security_policy) { build(:security_policy) }
      let_it_be(:approval_policy_rule) do
        build(:approval_policy_rule, :scan_finding, security_policy: security_policy)
      end

      let_it_be(:rule) do
        build(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: approval_policy_rule)
      end

      before do
        security_policy.content[:bypass_settings] = {
          branches: [{
            source: { name: merge_request.source_branch }, target: { name: merge_request.target_branch }
          }]
        }
      end

      it 'returns false' do
        expect(rule.applicable_to_branch?(branch)).to be_falsey
      end
    end

    context 'when there are no associated source rules' do
      it_behaves_like 'with applicable rules to specified branch'
    end

    describe 'policy target branch matching' do
      let!(:source_rule) do
        create(:approval_project_rule, project: merge_request.target_project,
          approval_policy_rule: approval_policy_rule)
      end

      let!(:rule) do
        create(:approval_merge_request_rule, approval_project_rule: source_rule, merge_request: merge_request,
          approval_policy_rule: approval_policy_rule)
      end

      before do
        merge_request.update!(target_branch: "release/staging")

        source_rule.protected_branches = [create(:protected_branch, project: merge_request.project, name: "release/*")]
        source_rule.save!
      end

      subject(:applies?) { rule.applicable_to_branch?(merge_request.target_branch) }

      context 'with `branches`' do
        let(:approval_policy_rule) do
          build(:approval_policy_rule, :scan_finding) do |policy_rule|
            policy_rule.update!(content: policy_rule.content.merge("branches" => branches))
          end
        end

        context 'with matching branch specification' do
          let(:branches) { ["release/staging"] }

          it { is_expected.to be(true) }
        end

        context 'with matching branch specification' do
          let(:branches) { ["master", "release/staging"] }

          it { is_expected.to be(true) }
        end

        context 'with matching branch specification' do
          let(:branches) { ["release/*"] }

          it { is_expected.to be(true) }
        end

        context 'with mismatching branch specification' do
          let(:branches) { ["release/production"] }

          it { is_expected.to be(false) }
        end
      end

      context 'with `branch_type`' do
        let(:approval_policy_rule) do
          build(:approval_policy_rule, :scan_finding) do |policy_rule|
            policy_rule.update!(content: policy_rule.content.excluding("branches").merge("branch_type" => branch_type))
          end
        end

        context 'with `protected` branch type' do
          let(:branch_type) { 'protected' }

          context 'when MR targets protected branch' do
            it { is_expected.to be(true) }
          end

          context 'when MR targets unprotected branch' do
            before do
              merge_request.update!(target_branch: "unprotected")
            end

            it { is_expected.to be(false) }
          end
        end

        context 'with `default` branch type' do
          let(:branch_type) { 'default' }

          before do
            allow(merge_request.project).to receive(:default_branch).and_return(default_branch)
          end

          context 'when MR targets default branch' do
            let(:default_branch) { "release/staging" }

            it { is_expected.to be(true) }
          end

          context 'when MR does not target default branch' do
            let(:default_branch) { "release/production" }

            it { is_expected.to be(false) }
          end
        end
      end
    end

    context 'when there are associated source rules' do
      let_it_be_with_reload(:source_rule) { create(:approval_project_rule, project: merge_request.target_project) }
      let_it_be_with_reload(:rule) do
        create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: source_rule)
      end

      context 'and rule is not modified_from_project_rule' do
        before do
          rule.update!(
            name: source_rule.name,
            approvals_required: source_rule.approvals_required,
            users: source_rule.users,
            groups: source_rule.groups
          )
        end

        context 'and there are no associated protected branches to source rule' do
          it_behaves_like 'with applicable rules to specified branch'
        end

        context 'and there are associated protected branches to source rule' do
          before do
            source_rule.update!(protected_branches: protected_branches)
          end

          context 'and branch matches' do
            let(:protected_branches) { Array.new(1) { create(:protected_branch, name: branch, project: project) } }

            it_behaves_like 'with applicable rules to specified branch'
          end

          context 'and branch does not match anything' do
            let(:protected_branches) do
              Array.new(1) do
                create(:protected_branch, name: branch.reverse, project: project)
              end
            end

            it { is_expected.to be_falsey }
          end
        end
      end

      context 'and rule is modified_from_project_rule' do
        before do
          rule.update!(name: 'Overridden Rule')
        end

        it_behaves_like 'with applicable rules to specified branch'
      end

      context 'and rule is overridden but not modified_from_project_rule' do
        let_it_be_with_reload(:rule) do
          create(:approval_merge_request_rule, name: 'test', merge_request: merge_request,
            approval_project_rule: source_rule)
        end

        it_behaves_like 'with applicable rules to specified branch'

        context 'and protected branches exist but branch does not match anything' do
          let(:protected_branches) do
            Array.new(1) do
              create(:protected_branch, name: branch.reverse, project: project)
            end
          end

          before do
            source_rule.update!(protected_branches: protected_branches)
          end

          it 'does not find applicable rules' do
            expect(subject).to be_falsey
          end
        end
      end
    end
  end

  context 'with loose foreign key on approval_merge_request_rules.approval_policy_rule_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:approval_policy_rule) }
      let_it_be(:model) { create(:approval_merge_request_rule, approval_policy_rule: parent) }
    end
  end
end

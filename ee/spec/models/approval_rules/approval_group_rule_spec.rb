# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::ApprovalGroupRule, feature_category: :source_code_management do
  let(:group_approval_rule) { build(:approval_group_rule) }

  describe 'validations' do
    it { expect(group_approval_rule).to validate_presence_of(:name) }
    it { expect(group_approval_rule).to validate_uniqueness_of(:name).scoped_to([:group_id, :rule_type]) }
    it { expect(group_approval_rule).to validate_numericality_of(:approvals_required).is_less_than_or_equal_to(100) }
    it { expect(group_approval_rule).to validate_numericality_of(:approvals_required).is_greater_than_or_equal_to(0) }

    context 'for applies_to_all_protected_branches' do
      it 'is default true' do
        expect(group_approval_rule.applies_to_all_protected_branches).to be_truthy
      end

      it 'cannot be false' do
        expect do
          group_approval_rule.update!(applies_to_all_protected_branches: false)
        end.to raise_error(ActiveRecord::RecordInvalid,
          'Validation failed: Applies to all protected branches must be enabled.')
      end
    end

    context 'for groups' do
      let_it_be(:parent, freeze: false) { create(:group) }
      let_it_be(:child, freeze: false) { create(:group, parent: parent) }

      it 'supports top level groups' do
        group_approval_rule.update!(group: parent)
        expect(group_approval_rule.group).to eq(parent)
      end

      it 'child groups are not supported' do
        expect do
          group_approval_rule.update!(group: child)
        end.to raise_error(ActiveRecord::RecordInvalid,
          'Validation failed: Group must be a top level Group')
      end
    end
  end

  describe 'associations' do
    it { expect(group_approval_rule).to belong_to(:group).inverse_of(:approval_rules) }
    it { expect(group_approval_rule).to belong_to(:security_orchestration_policy_configuration) }
    it { expect(group_approval_rule).to belong_to(:scan_result_policy_read) }
    it { expect(group_approval_rule).to have_and_belong_to_many(:users) }
    it { expect(group_approval_rule).to have_and_belong_to_many(:groups) }
    it { expect(group_approval_rule).to have_and_belong_to_many(:protected_branches) }
  end

  describe 'any_approver rules' do
    let_it_be(:group, freeze: false) { create(:group) }

    let(:rule) { build(:approval_group_rule, group: group, rule_type: :any_approver) }

    it 'allows to create only one any_approver rule', :aggregate_failures do
      create(:approval_group_rule, group: group, rule_type: :any_approver)

      expect(rule).not_to be_valid
      expect(rule.errors.messages).to eq(rule_type: ['any-approver for the group already exists'])
    end
  end

  describe '#protected_branches' do
    let_it_be(:group, freeze: false) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:project_1, freeze: false) { create(:project, group: group) }
    let_it_be(:project_2, freeze: false) { create(:project, group: group) }
    let_it_be(:project_3, freeze: false) { create(:project, group: sub_group) }
    let_it_be(:rule) { create(:approval_group_rule, group: group) }
    let_it_be(:protected_branches_project_1, freeze: false) { create_list(:protected_branch, 3, project: project_1) }
    let_it_be(:protected_branches_project_2) { create_list(:protected_branch, 3, project: project_2) }

    # protected_branches_project_3 belong to 'project_2' which is a member of 'sub_group'.
    # It is used to demonstrate that protected branches from subgroups are not included.
    let_it_be(:protected_branches_project_3) { create_list(:protected_branch, 3, project: project_3) }
    let_it_be(:group_protected_branches) { create_list(:protected_branch, 2, project: nil, group: group) }

    subject(:group_approval_rule) { rule.protected_branches }

    it 'returns all protected branches belonging to group projects and group level protected branches',
      quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/470289' do
      expect(group_approval_rule).to contain_exactly(*protected_branches_project_1, *protected_branches_project_2,
        *group_protected_branches)
    end
  end
end

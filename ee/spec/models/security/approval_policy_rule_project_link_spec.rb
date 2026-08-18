# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicyRuleProjectLink, feature_category: :security_policy_management do
  subject { create(:approval_policy_rule_project_link) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:approval_policy_rule) }

    it { is_expected.to validate_uniqueness_of(:approval_policy_rule).scoped_to(:project_id) }
  end

  describe '.for_project' do
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule) }

    before do
      create(:approval_policy_rule_project_link, project: project1, approval_policy_rule: approval_policy_rule)
    end

    it 'returns links for the specified project' do
      result = described_class.for_project(project1)

      expect(result.count).to eq(1)
      expect(result.first.project).to eq(project1)
    end

    it 'returns an empty relation if no links exist for the project' do
      result = described_class.for_project(project2)

      expect(result).to be_empty
    end
  end

  describe '.for_project_and_policy_rule' do
    let_it_be(:project) { create(:project) }
    let_it_be(:other_project) { create(:project) }
    let_it_be(:policy_rule) { create(:approval_policy_rule) }
    let_it_be(:other_policy_rule) { create(:approval_policy_rule) }

    let_it_be(:matching_link) do
      create(:approval_policy_rule_project_link, project: project, approval_policy_rule: policy_rule)
    end

    before_all do
      create(:approval_policy_rule_project_link, project: other_project, approval_policy_rule: policy_rule)
      create(:approval_policy_rule_project_link, project: project, approval_policy_rule: other_policy_rule)
    end

    it 'returns the link matching both project and policy rule' do
      result = described_class.for_project_and_policy_rule(project.id, policy_rule.id)

      expect(result).to contain_exactly(matching_link)
    end

    it 'returns an empty relation when only the project matches' do
      unrelated_rule = create(:approval_policy_rule)

      expect(described_class.for_project_and_policy_rule(project.id, unrelated_rule.id)).to be_empty
    end

    it 'returns an empty relation when only the policy rule matches' do
      unrelated_project = create(:project)

      expect(described_class.for_project_and_policy_rule(unrelated_project.id, policy_rule.id)).to be_empty
    end
  end
end

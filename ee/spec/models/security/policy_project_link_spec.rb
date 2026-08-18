# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyProjectLink, feature_category: :security_policy_management do
  subject { create(:security_policy_project_link) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:security_policy) }

    it { is_expected.to validate_uniqueness_of(:security_policy).scoped_to(:project_id) }
  end

  describe '.for_project' do
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }
    let_it_be(:security_policy) { create(:security_policy) }

    before do
      create(:security_policy_project_link, project: project1, security_policy: security_policy)
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

  describe '.linked_project_counts' do
    let_it_be(:policy1) { create(:security_policy) }
    let_it_be(:policy2) { create(:security_policy) }
    let_it_be(:policy3) { create(:security_policy) }
    let_it_be(:link1) { create(:security_policy_project_link, security_policy: policy1) }
    let_it_be(:link2) { create(:security_policy_project_link, security_policy: policy1) }
    let_it_be(:link3) { create(:security_policy_project_link, security_policy: policy2) }

    it 'returns counts grouped by policy ID' do
      result = described_class.linked_project_counts([policy1.id, policy2.id, policy3.id])

      expect(result).to eq({
        policy1.id => 2,
        policy2.id => 1,
        policy3.id => 0
      })
    end

    it 'returns zero for policies with no links' do
      result = described_class.linked_project_counts([policy3.id])

      expect(result).to eq({ policy3.id => 0 })
    end

    it 'returns empty hash for empty input' do
      result = described_class.linked_project_counts([])

      expect(result).to eq({})
    end
  end
end

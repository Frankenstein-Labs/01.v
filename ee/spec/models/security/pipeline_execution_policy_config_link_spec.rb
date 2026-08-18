# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicyConfigLink, feature_category: :security_policy_management do
  subject { create(:security_pipeline_execution_policy_config_link) }

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
      create(:security_pipeline_execution_policy_config_link, project: project1, security_policy: security_policy)
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
end

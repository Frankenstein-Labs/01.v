# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::DefaultBranchUpdationCheckService, '#execute', feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be(:protected_branch) do
    create(:protected_branch, project: project, name: project.default_branch)
  end

  let(:default_branch) { project.default_branch }
  let(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: project)
  end

  subject { described_class.new(project: project).execute }

  context 'when security_orchestration_policies is not licensed' do
    before do
      stub_licensed_features(security_orchestration_policies: false)
    end

    it { is_expected.to be_falsey }
  end

  context 'without blocking scan result policy' do
    it { is_expected.to be_falsey }
  end

  context 'with blocking scan result policy' do
    include_context 'with approval policy blocking protected branches' do
      let(:branch_name) { default_branch }

      it_behaves_like 'when policy is applicable based on the policy scope configuration' do
        it { is_expected.to be_truthy }
      end

      it_behaves_like 'when no policy is applicable due to the policy scope' do
        it { is_expected.to be_falsey }
      end
    end

    context 'with mismatching branch specification' do
      include_context 'with approval policy blocking protected branches' do
        let(:branch_name) { default_branch }
        let(:approval_policy) do
          build(:approval_policy, branches: [default_branch.reverse],
            approval_settings: { block_branch_modification: true })
        end

        it { is_expected.to be_falsey }
      end
    end
  end
end

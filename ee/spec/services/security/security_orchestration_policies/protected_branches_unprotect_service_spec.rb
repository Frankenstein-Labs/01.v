# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::ProtectedBranchesUnprotectService, feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let(:branch_name) { protected_branch.name }

  subject(:result) { described_class.new(project: project).execute }

  context 'with blocking scan result policy' do
    include_context 'with approval security policy preventing force pushing'

    context 'when protected branch is not backed by git ref' do
      it "includes the protected branch" do
        expect(project.repository.branches.map(&:name)).to exclude(branch_name)
        expect(result).to include(branch_name)
      end
    end
  end
end

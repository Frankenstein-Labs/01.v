# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::ExternalStatusChecks::BaseService, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }

  subject(:service) { described_class.new(branch_rule, user: user) }

  describe '#execute_on_all_branches_rule' do
    it 'returns a not supported error', :aggregate_failures do
      response = service.send(:execute_on_all_branches_rule)

      expect(response).to be_error
      expect(response.message).to eq('All branch rules cannot configure external status checks')
      expect(response.payload[:errors]).to contain_exactly('All branch rules not allowed')
      expect(response.reason).to eq(:unprocessable_entity)
    end
  end

  describe '#execute_on_all_protected_branches_rule' do
    it 'returns a not supported error', :aggregate_failures do
      response = service.send(:execute_on_all_protected_branches_rule)

      expect(response).to be_error
      expect(response.message).to eq('All protected branch rules cannot configure external status checks')
      expect(response.payload[:errors]).to contain_exactly('All protected branches not allowed')
      expect(response.reason).to eq(:unprocessable_entity)
    end
  end
end

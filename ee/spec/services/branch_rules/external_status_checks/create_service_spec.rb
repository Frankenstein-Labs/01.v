# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::ExternalStatusChecks::CreateService, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let(:user) { maintainer }
  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:create_service) { ExternalStatusChecks::CreateService }
  let(:create_service_instance) { instance_double(update_service) }
  let(:status_check_name) { 'Test' }
  let(:params) do
    {
      name: status_check_name,
      external_url: 'https://external_url.text/hello.json',
      shared_secret: 'shared_secret'
    }
  end

  subject(:execute) { described_class.new(branch_rule, user: user, params: params).execute }

  before do
    stub_licensed_features(audit_events: true)
  end

  context 'when the given branch rule is a Projects::AllBranchesRule' do
    let(:branch_rule) { Projects::AllBranchesRule.new(project) }
    let(:protected_branch) { nil }

    it_behaves_like 'create external status services'
  end

  describe 'when the user is not authorized' do
    let_it_be(:user) { create(:user, developer_of: project) }

    it 'returns the corresponding error response' do
      expect(execute.message).to eq('Failed to create external status check')
      expect(execute.payload[:errors]).to contain_exactly('Not allowed')
      expect(execute.reason).to eq(:access_denied)
    end
  end

  context 'when the given branch rule is an invalid type' do
    let(:branch_rule) { create(:protected_branch) }

    it 'is unsuccessful' do
      expect(execute.error?).to be true
    end

    it 'does not create a new rule' do
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end

    it 'responds with the expected errors' do
      expect(execute.message).to eq('Unknown branch rule type.')
    end
  end

  context 'with ::Projects::AllProtectedBranchesRule' do
    let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }
    let(:protected_branch) { nil }

    it 'responds with the expected errors' do
      expect(execute.error?).to be true
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
      expect(execute.message).to eq('All protected branch rules cannot configure external status checks')
      expect(execute.payload[:errors]).to contain_exactly('All protected branches not allowed')
    end
  end
end

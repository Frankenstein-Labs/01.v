# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::ExternalStatusChecks::DestroyService, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let(:user) { maintainer }
  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:external_status_check) do
    create(:external_status_check, project: project, protected_branches: [protected_branch])
  end

  let(:params) { { id: external_status_check.id } }

  subject(:execute) { described_class.new(branch_rule, user: user, params: params).execute }

  before do
    stub_licensed_features(audit_events: true)
  end

  shared_examples 'the service execution succeeds' do
    context 'with request store', :request_store do
      specify '#success? is true' do
        expect(execute.success?).to be(true)
      end

      it 'destroys the external_status_check record' do
        execute

        expect { external_status_check.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'does not include errors in payload' do
        response = execute

        expect(response.errors).to be_empty
      end
    end
  end

  shared_examples 'with invalid branch rules' do |message|
    it 'responds with the expected errors' do
      expect(execute.error?).to be true
      expect { execute }.not_to change { external_status_check }
      expect(execute.message).to eq(message)
    end
  end

  it_behaves_like 'the service execution succeeds'

  context 'with ::Projects::AllBranchesRule' do
    let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }

    it_behaves_like 'the service execution succeeds'
  end

  context 'when the service execution fails' do
    context 'when id parameter is missing' do
      let(:params) { { branch_rule_id: branch_rule.id } }

      it 'returns a service error response', :aggregate_failures do
        expect(execute.success?).to be(false)
        expect(execute.message).to eq('Record not found')
        expect(execute.payload[:errors]).to contain_exactly('Not found')
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when user is not allowed to destroy an external_status_check record' do
      let_it_be(:user) { create(:user, developer_of: project) }

      it 'returns a service error response', :aggregate_failures do
        expect(execute.error?).to be(true)
        expect(execute.message).to eq('Failed to destroy external status check')
        expect(execute.reason).to eq(:access_denied)
        expect(execute.payload[:errors]).to contain_exactly('Not allowed')
      end

      it 'does not destroy the external_status_check record' do
        expect { execute }.not_to change { external_status_check }
      end
    end

    context 'when the given branch rule is not and instance of Projects::BranchRule' do
      let(:branch_rule) { create(:protected_branch) }

      it 'returns an error' do
        expect(execute.error?).to be true
      end

      it 'does not destroy the external status check' do
        expect { execute }.not_to change { external_status_check }
      end

      it 'responds with the expected errors' do
        expect(execute.message).to eq('Unknown branch rule type.')
      end
    end

    context 'with ::Projects::AllProtectedBranchesRule' do
      let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }

      it_behaves_like 'with invalid branch rules', 'All protected branch rules cannot configure external status checks'
    end
  end
end

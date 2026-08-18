# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::ExternalStatusChecks::UpdateService, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let(:user) { maintainer }
  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:external_status_check) do
    create(:external_status_check, project: project, protected_branches: [protected_branch])
  end

  let(:shared_secret) { 'shared secret' }
  let(:params) do
    {
      id: external_status_check.id,
      name: 'Updated name',
      external_url: 'https://external_url_updated.com',
      shared_secret: shared_secret
    }
  end

  subject(:execute) { described_class.new(branch_rule, user: user, params: params).execute }

  before do
    stub_licensed_features(audit_events: true)
  end

  shared_examples 'the service execution succeeds' do
    context 'with request store', :request_store do
      specify '#success? is true' do
        expect(execute.success?).to be(true)
      end

      it 'updates the external_status_check record' do
        execute

        external_status_check.reload
        expect(external_status_check.name).to eq('Updated name')
        expect(external_status_check.external_url).to eq('https://external_url_updated.com')
        expect(external_status_check.shared_secret).to eq(shared_secret)
      end

      it 'includes the updated external_status_check record in payload' do
        external_status_check = execute.payload[:external_status_check]

        expect(external_status_check).to be_instance_of(MergeRequests::ExternalStatusCheck)
        expect(external_status_check.project).to eq(project)
        expect(external_status_check.name).to eq('Updated name')
        expect(external_status_check.external_url).to eq('https://external_url_updated.com')
        expect(external_status_check.shared_secret).to eq(shared_secret)
        expect(external_status_check.protected_branches).to contain_exactly(protected_branch)
      end
    end
  end

  it_behaves_like 'the service execution succeeds'

  context 'with ::Projects::AllBranchesRule' do
    let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }

    it_behaves_like 'the service execution succeeds'
  end

  context 'when the service execution fails' do
    context 'when id parameter is missing' do
      let(:params) { { name: 'Updated name', external_url: 'https://external_url_updated.com' } }

      it 'returns a service error response', :aggregate_failures do
        result = execute

        expect(result.success?).to be(false)
        expect(result.message).to eq('Record not found')
        expect(result.payload[:errors]).to contain_exactly('Not found')
        expect(result.reason).to eq(:not_found)
      end
    end

    context 'when user is not allowed to update an external_status_check record' do
      let_it_be(:user) { create(:user, developer_of: project) }

      it 'returns a service error response' do
        expect(execute.error?).to be(true)
        expect(execute.message).to eq('Failed to update external status check')
        expect(execute.reason).to eq(:access_denied)
        expect(execute.payload[:errors]).to contain_exactly('Not allowed')
      end

      it 'does not update the external_status_check record' do
        expect { execute }.not_to change { external_status_check }
      end
    end

    context 'when the given branch rule is not and instance of Projects::BranchRule' do
      let(:branch_rule) { create(:protected_branch) }

      it 'returns an error' do
        expect(execute.error?).to be true
      end

      it 'does not update the external status check' do
        expect { execute }.not_to change { external_status_check }
      end

      it 'responds with the expected errors' do
        expect(execute.message).to eq('Unknown branch rule type.')
      end
    end

    context 'with ::Projects::AllProtectedBranchesRule' do
      let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }

      it 'responds with the expected errors' do
        expect(execute.error?).to be true
        expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
        expect(execute.message).to eq('All protected branch rules cannot configure external status checks')
        expect(execute.payload[:errors]).to contain_exactly('All protected branches not allowed')
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::DestroyService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  describe '#execute' do
    subject(:execute) { described_class.new(branch_rule, user: user).execute }

    context 'when branch_rule is a Projects::AllBranchesRule' do
      let(:branch_rule) { Projects::AllBranchesRule.new(project) }

      let_it_be(:approval_project_rules) { create_list(:approval_project_rule, 2, project: project) }
      let_it_be(:external_status_checks) { create_list(:external_status_check, 2, project: project) }

      it 'deletes the approval rules and external status checks' do
        expect { execute }
          .to change { ApprovalProjectRule.count }.by(-2)
          .and change { MergeRequests::ExternalStatusCheck.count }.by(-2)
      end

      it 'returns a success response' do
        expect(execute).to be_success
      end

      context 'if approval rule deletion fails' do
        let(:destroy_service) { ApprovalRules::ProjectRuleDestroyService }
        let(:destroy_service_instance) { instance_double(destroy_service) }
        let(:destroy_service_error) { ServiceResponse.error(message: 'error') }

        before do
          allow(destroy_service).to receive(:new).and_return(destroy_service_instance)
          allow(destroy_service_instance).to receive(:execute).and_return(destroy_service_error)
        end

        it 'returns an error response' do
          response = execute
          expect(response).to be_error
          expect(response[:message]).to eq('Failed to delete approval rules.')
        end
      end

      context 'if external status check deletion fails' do
        let(:destroy_service) { ExternalStatusChecks::DestroyService }
        let(:destroy_service_instance) { instance_double(destroy_service) }
        let(:destroy_service_error) { ServiceResponse.error(message: 'error') }

        before do
          allow(destroy_service).to receive(:new).and_return(destroy_service_instance)
          allow(destroy_service_instance).to receive(:execute).and_return(destroy_service_error)
        end

        it 'returns an error response' do
          response = execute
          expect(response).to be_error
          expect(response[:message]).to eq('Failed to delete external status checks.')
        end
      end
    end

    context 'when branch_rule is a Projects::AllProtectedBranchesRule' do
      let(:branch_rule) { Projects::AllProtectedBranchesRule.new(project) }

      let_it_be(:approval_project_rules) do
        create_list(:approval_project_rule, 2, :for_all_protected_branches, project: project)
      end

      it 'deletes the approval rules' do
        expect { execute }.to change { ApprovalProjectRule.count }.by(-2)
      end

      it 'returns a success response' do
        expect(execute).to be_success
      end

      context 'if approval rule deletion fails' do
        let(:destroy_service) { ApprovalRules::ProjectRuleDestroyService }
        let(:destroy_service_instance) { instance_double(destroy_service) }
        let(:destroy_service_error) { ServiceResponse.error(message: 'error') }

        before do
          allow(destroy_service).to receive(:new).and_return(destroy_service_instance)
          allow(destroy_service_instance).to receive(:execute).and_return(destroy_service_error)
        end

        it 'returns an error response' do
          response = execute
          expect(response).to be_error
          expect(response[:message]).to eq('Failed to delete approval rules.')
        end
      end
    end
  end
end

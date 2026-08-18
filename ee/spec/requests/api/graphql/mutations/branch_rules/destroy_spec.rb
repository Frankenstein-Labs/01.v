# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deleting a BranchRule', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: current_user) }

  let(:global_id) { branch_rule.to_global_id.to_s }
  let(:mutation) { graphql_mutation(:branch_rule_delete, { id: global_id }) }
  let(:mutation_response) { graphql_mutation_response(:branch_rule_delete) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when the branch rule is for all branches' do
    let(:branch_rule) { Projects::AllBranchesRule.new(project) }

    let_it_be(:approval_project_rules) { create_list(:approval_project_rule, 2, project: project) }
    let_it_be(:external_status_checks) { create_list(:external_status_check, 2, project: project) }

    it 'destroys the BranchRule' do
      expect { mutation_request }
        .to change { ApprovalProjectRule.count }.by(-2)
        .and change { MergeRequests::ExternalStatusCheck.count }.by(-2)
    end

    it 'returns an empty BranchRule' do
      mutation_request

      expect(mutation_response).to have_key('branchRule')
      expect(mutation_response['branchRule']).to be_nil
    end
  end

  context 'when the branch rule is for all protected branches' do
    let(:branch_rule) { Projects::AllProtectedBranchesRule.new(project) }

    let_it_be(:approval_project_rules) do
      create_list(:approval_project_rule, 2, :for_all_protected_branches, project: project)
    end

    it 'destroys the BranchRule' do
      expect { mutation_request }.to change { ApprovalProjectRule.count }.by(-2)
    end

    it 'returns an empty BranchRule' do
      mutation_request

      expect(mutation_response).to have_key('branchRule')
      expect(mutation_response['branchRule']).to be_nil
    end
  end

  context 'when an invalid global id is given' do
    let(:global_id) { project.to_gid.to_s }
    let(:error_message) { %("#{global_id}" does not represent an instance of Projects::BranchRule) }
    let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

    it 'returns an error' do
      mutation_request

      expect(graphql_errors).to include(global_id_error)
    end

    it 'does not destroy the BranchRule' do
      expect { mutation_request }.not_to change { ProtectedBranch.count }
      expect { mutation_request }.not_to change { ApprovalProjectRule.count }
      expect { mutation_request }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end
  end

  context 'when deleting a branch rule associated to security policy approval rules' do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration) }

    shared_examples 'rejects mutation' do
      let(:expected_error) { a_hash_including('message' => a_string_including(error_message)) }
      let(:error_message) do
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      end

      specify do
        mutation_request

        expect(graphql_errors).to include(expected_error)
      end
    end

    context 'with approval rule applied to all protected branches' do
      let!(:rule_for_protected_branches) do
        create(
          :approval_project_rule,
          project: project,
          applies_to_all_protected_branches: true,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let(:global_id) { "gid://gitlab/Projects::AllProtectedBranchesRule/#{project.id}" }

      it_behaves_like 'rejects mutation'
    end

    context 'with approval rule applied to no protected branches' do
      let!(:rule_for_all_branches) do
        create(
          :approval_project_rule,
          project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let(:global_id) { "gid://gitlab/Projects::AllBranchesRule/#{project.id}" }

      it_behaves_like 'rejects mutation'
    end
  end
end

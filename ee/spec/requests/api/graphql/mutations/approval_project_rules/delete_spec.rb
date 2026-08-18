# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'approvalProjectRuleDelete', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:approval_project_rule) { create(:approval_project_rule) }
  let_it_be(:project) { approval_project_rule.project }
  let_it_be(:current_user) { create(:user) }

  let(:mutation_name) { 'approvalProjectRuleDelete' }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:id) { approval_project_rule.to_global_id.to_s }
  let(:params) { { id: id } }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when the user does not have permission' do
    before_all do
      project.add_developer(current_user)
    end

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create an approval project rule' do
      expect { post_mutation }.not_to change { ApprovalProjectRule.count }
    end
  end

  context 'when the user can edit approval rules' do
    before_all do
      project.add_maintainer(current_user)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_approval_rule do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:mutation) { graphql_mutation(mutation_name, params, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'deletes the approval project rule' do
      expect { post_mutation }.to change { ApprovalProjectRule.count }.from(1).to(0)
    end

    it 'returns the approval project rule' do
      post_mutation

      expect(mutation_response).to have_key('approvalRule')
      expect(mutation_response.dig('approvalRule', 'name')).to eq(approval_project_rule.name)
      expect(mutation_response['errors']).to be_empty
    end

    context 'when approval rule cannot be found' do
      let(:id) { project.to_gid.to_s }
      let(:error_message) { %("#{id}" does not represent an instance of ApprovalProjectRule) }
      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error' do
        post_mutation

        expect(graphql_errors).to include(global_id_error)
      end
    end

    context 'when approval rule originates from security policy' do
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
      let_it_be(:approval_project_rule) do
        create(:approval_project_rule,
          project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      let(:resource_not_available_error) { a_hash_including('message' => a_string_including(error_message)) }
      let(:error_message) do
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      end

      it 'returns an error' do
        post_mutation

        expect(graphql_errors).to include(resource_not_available_error)
      end
    end
  end
end

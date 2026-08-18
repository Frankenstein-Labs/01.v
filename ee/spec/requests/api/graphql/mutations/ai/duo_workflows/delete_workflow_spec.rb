# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete an AI Duo Workflow', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, :agentic_chat, user: user) }
  let_it_be(:other_workflow) { create(:duo_workflows_workflow, :agentic_chat, user: other_user) }

  let(:current_user) { user }
  let(:mutation) { graphql_mutation(:deleteDuoWorkflowsWorkflow, { 'workflowId' => workflow.to_global_id.to_s }) }
  let(:mutation_response) { graphql_mutation_response(:delete_duo_workflows_workflow) }

  context 'when the user owns the workflow' do
    it 'deletes the workflow' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { Ai::DuoWorkflows::Workflow.count }.by(-1)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end
  end

  context 'when the user does not own the workflow' do
    let(:workflow) { other_workflow }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the workflow does not exist' do
    before do
      workflow.destroy!
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end
end

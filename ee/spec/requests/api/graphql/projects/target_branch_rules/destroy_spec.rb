# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy project target branch rule', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:target_branch_rule) { create(:target_branch_rule, project: project) }

  let(:input) { { id: target_branch_rule.to_global_id } }

  let(:mutation) { graphql_mutation(:project_target_branch_rule_destroy, input) }
  let(:mutation_response) { graphql_mutation_response(:project_target_branch_rule_destroy) }

  context 'when license is invalid' do
    before do
      stub_licensed_features(target_branch_rules: false)
    end

    it 'returns null' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response).to be_nil
    end
  end

  context 'when license is valid' do
    before do
      stub_licensed_features(target_branch_rules: true)
    end

    it 'deletes the target branch rule' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { ::Projects::TargetBranchRule.count }.by(-1)
    end
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_target_branch_rule do
    let(:user) { create(:user, maintainer_of: project) }
    let(:boundary_object) { project }

    before do
      stub_licensed_features(target_branch_rules: true)
    end

    let(:mutation) do
      graphql_mutation(:project_target_branch_rule_destroy, { id: target_branch_rule.to_global_id }, 'errors')
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end

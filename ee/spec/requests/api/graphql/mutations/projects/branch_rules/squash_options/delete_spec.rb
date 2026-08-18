# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deleting a squash option', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:protected_branch) { create(:protected_branch) }
  let_it_be(:project) { protected_branch.project }

  let!(:squash_option) { create(:branch_rule_squash_option, protected_branch: protected_branch, project: project) }
  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:global_id) { branch_rule.to_global_id.to_s }
  let(:mutation) { graphql_mutation(:branch_rule_squash_option_delete, { branch_rule_id: global_id }) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(branch_rule_squash_options: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_squash_option do
    let(:user) { create(:user, maintainer_of: project) }
    let(:boundary_object) { project }
    let(:request) do
      post_graphql_mutation(
        graphql_mutation(:branch_rule_squash_option_delete,
          { branch_rule_id: branch_rule.to_global_id.to_s }, 'errors'),
        token: { personal_access_token: pat })
    end
  end

  context 'when the user does not have permission' do
    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]

    it 'does not destroy the squash option' do
      expect { mutation_request }.not_to change { Projects::BranchRules::SquashOption.count }.from(1)
    end
  end

  context 'when the user has permission' do
    before_all do
      project.add_maintainer(current_user)
    end

    context 'and the feature is not available' do
      let(:mutation_response) { graphql_mutation_response(:branch_rule_squash_option_delete) }

      before do
        stub_licensed_features(branch_rule_squash_options: false)
      end

      it 'returns an error in the response' do
        mutation_request

        expect(mutation_response['errors']).to contain_exactly('Squash options are not available for this branch rule')
      end
    end

    context 'and there is a squash option' do
      it 'destroys the squash option' do
        expect { mutation_request }.to change { Projects::BranchRules::SquashOption.count }.by(-1)
      end
    end

    context 'and there is no squash option' do
      let(:squash_option) { nil }
      let(:mutation_response) { graphql_mutation_response(:branch_rule_squash_option_delete) }

      it_behaves_like 'a mutation that returns errors in the response', errors: ['Record not found']
    end
  end
end

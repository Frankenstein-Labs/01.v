# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a squash option', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:protected_branch) { create(:protected_branch) }
  let_it_be(:project) { protected_branch.project }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }

  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:global_id) { branch_rule.to_global_id.to_s }

  let(:mutation) do
    graphql_mutation(:branch_rule_squash_option_create, { branch_rule_id: global_id, squash_option: 'NEVER' })
  end

  let(:mutation_response) { graphql_mutation_response(:branch_rule_squash_option_create) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(branch_rule_squash_options: true)
  end

  context 'when the user does not have permission' do
    let_it_be(:current_user) { create(:user, developer_of: project) }

    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]

    it 'does not create a squash option' do
      expect { mutation_request }.not_to change { ::Projects::BranchRules::SquashOption.count }
    end
  end

  context 'when the feature is not available' do
    before do
      stub_licensed_features(branch_rule_squash_options: false)
    end

    it 'returns an error in the response' do
      mutation_request

      expect(mutation_response['errors']).to contain_exactly('Squash options are not available for this branch rule')
    end
  end

  context 'when no squash option exists' do
    it 'creates the squash option' do
      expect { mutation_request }.to change { ::Projects::BranchRules::SquashOption.count }.by(1)
    end

    it 'responds with the created squash option' do
      mutation_request

      expect(mutation_response['squashOption']['option']).to eq('Do not allow')
      expect(mutation_response['squashOption']['helpText']).to eq(
        'Squashing is never performed and the checkbox is hidden.'
      )
    end
  end

  context 'when a squash option already exists' do
    before do
      create(:branch_rule_squash_option, protected_branch: protected_branch, project: project)
    end

    it 'does not create a duplicate' do
      expect { mutation_request }.not_to change { ::Projects::BranchRules::SquashOption.count }
    end

    it 'responds with an error' do
      mutation_request

      expect(mutation_response['errors']).to be_present
    end
  end
end

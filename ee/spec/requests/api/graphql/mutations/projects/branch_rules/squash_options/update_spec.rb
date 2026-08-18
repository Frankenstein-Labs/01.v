# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a squash option', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:exact_protected_branch, freeze: false) { create(:protected_branch) }
  let_it_be(:project, freeze: false) { exact_protected_branch.project }
  let_it_be(:wildcard_protected_branch, freeze: false) { create(:protected_branch, project: project, name: '*') }
  let_it_be(:current_user, freeze: false) { create(:user, maintainer_of: project) }

  let(:global_id) { branch_rule.to_global_id.to_s }
  let(:protected_branch) { exact_protected_branch }

  let(:mutation) do
    graphql_mutation(:branch_rule_squash_option_update, { branch_rule_id: global_id, squash_option: 'NEVER' })
  end

  let(:mutation_response) { graphql_mutation_response(:branch_rule_squash_option_update) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_licensed_features(branch_rule_squash_options: true)
  end

  context 'with branch rule' do
    let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }

    context 'when the feature is not available' do
      before do
        stub_licensed_features(branch_rule_squash_options: false)
      end

      it 'returns an error' do
        mutation_request

        expect(mutation_response['errors']).to eq(['Squash options are not available for this branch rule'])
      end
    end

    context 'and a squash option exists' do
      let!(:squash_option) do
        create(:branch_rule_squash_option, protected_branch: protected_branch, project: project)
      end

      it 'updates the squash option' do
        expect { mutation_request }.to change { squash_option.reload.squash_option }.from('default_off').to('never')
      end

      it 'responds with the updated squash option' do
        mutation_request

        expect(mutation_response['squashOption']['option']).to eq('Do not allow')
        expect(mutation_response['squashOption']['helpText']).to eq(
          'Squashing is never performed and the checkbox is hidden.'
        )
      end
    end

    context 'when there are validation errors' do
      let(:protected_branch) { wildcard_protected_branch }

      it 'responds with the validation errors' do
        mutation_request

        expect(mutation_response['errors']).to eq([
          'Squash option cannot be used with wildcard branch rules. Use an exact branch name.'
        ])
      end
    end

    context 'and a squash option does not exist' do
      it 'creates a squash option' do
        expect { mutation_request }.to change {
          protected_branch.reload&.squash_option&.squash_option
        }.from(nil).to('never')
      end
    end
  end
end

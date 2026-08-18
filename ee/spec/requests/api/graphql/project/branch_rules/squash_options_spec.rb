# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting squash options for a branch rule', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:maintainer_user) { create(:user, maintainer_of: project) }
  let_it_be(:guest_user) { create(:user, guest_of: project) }
  let_it_be(:variables) { { path: project.full_path } }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:squash_option) { create(:branch_rule_squash_option, protected_branch: protected_branch, project: project) }

  let(:fields) { all_graphql_fields_for('SquashOption') }

  let(:query) do
    <<~GQL
    query($path: ID!) {
      project(fullPath: $path) {
        branchRules {
          nodes{
            name
            squashOption {
              #{fields}
            }
          }
        }
      }
    }
    GQL
  end

  let(:branch_rules_data) do
    graphql_data_at(:project, :branch_rules, :nodes)
  end

  let(:feature_available) { true }

  before do
    stub_licensed_features(branch_rule_squash_options: feature_available)
    post_graphql(query, current_user: current_user, variables: variables)
  end

  context 'when user is not authorized' do
    let(:current_user) { guest_user }

    it_behaves_like 'a working graphql query'

    it { expect(branch_rules_data).to be_empty }
  end

  context 'when user is authorized' do
    let(:current_user) { maintainer_user }

    context 'and the feature is not available' do
      let(:feature_available) { false }

      it 'returns squashOption for all branches only' do
        expect(branch_rules_data).to contain_exactly(
          a_hash_including({
            "name" => "All branches",
            "squashOption" => {
              "option" => "Allow",
              "helpText" =>
              "Checkbox is visible and unselected by default."
            }
          }),
          a_hash_including({
            "name" => protected_branch.name,
            "squashOption" => nil
          })
        )
      end
    end

    it_behaves_like 'a working graphql query'

    it 'returns squash option attributes' do
      expect(branch_rules_data.size).to eq(2)

      expect(branch_rules_data).to contain_exactly(
        a_hash_including(
          "name" => "All branches",
          "squashOption" =>
           { "option" => "Allow",
             "helpText" =>
             "Checkbox is visible and unselected by default." }),
        a_hash_including(
          "name" => protected_branch.name,
          "squashOption" =>
            { "option" => "Allow",
              "helpText" =>
              "Checkbox is visible and unselected by default." })
      )
    end
  end
end

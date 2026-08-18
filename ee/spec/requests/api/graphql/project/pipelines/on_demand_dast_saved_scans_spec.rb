# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SavedScans GraphQL Query', feature_category: :dynamic_application_security_testing do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let(:graphql_response) { post_graphql(query, current_user: current_user, variables: variables) }
  let_it_be_with_reload(:developer) { create(:user, developer_of: project) }
  # `freeze: false` is kept here because this `let_it_be` subject is not an
  # ActiveRecord record (or memoizes internal state); freezing raises
  # FrozenError and reload/refind are no-ops on it. Keep as-is (see
  # gitlab-org/gitlab#602925).
  let_it_be(:repository, freeze: false) { project.repository }
  let_it_be(:master_branch) { repository.add_branch(developer, 'master', repository.commit.sha) }
  let_it_be(:feature_branch) do
    repository.add_branch(developer, 'feature-branch', repository.commit.sha)
  end

  let_it_be(:dast_profile1) do
    create(:dast_profile,
      project: project,
      branch_name: 'master',
      name: 'Profile 1'
    )
  end

  let_it_be(:dast_profile2) do
    create(:dast_profile,
      project: project,
      branch_name: 'feature-branch',
      name: 'Profile 2'
    )
  end

  let(:current_user) { developer }
  let(:repository_access_level) { ProjectFeature::ENABLED }
  let(:query) do
    <<~GRAPHQL
      query SavedScans($fullPath: ID!) {
        project(fullPath: $fullPath) {
          id
          pipelines: dastProfiles {
            nodes {
              id
              name
              branch {
                name
                exists
                __typename
              }
            }
          }
        }
      }
    GRAPHQL
  end

  let(:variables) { { fullPath: project.full_path } }
  let(:profiles) { graphql_data_at(:project, :pipelines, :nodes) }
  let(:profile1_data) do
    hash_including(
      'name' => 'Profile 1',
      'branch' => {
        'name' => 'master',
        'exists' => true,
        '__typename' => 'DastProfileBranch'
      }
    )
  end

  let(:profile2_data) do
    hash_including(
      'name' => 'Profile 2',
      'branch' => {
        'name' => 'feature-branch',
        'exists' => true,
        '__typename' => 'DastProfileBranch'
      }
    )
  end

  let(:expected_profiles) { [profile1_data, profile2_data] }

  before do
    stub_licensed_features(security_on_demand_scans: true)
    project.project_feature.update!(
      repository_access_level: repository_access_level,
      merge_requests_access_level: repository_access_level,
      builds_access_level: repository_access_level
    )
  end

  context 'when feature is not licensed' do
    before do
      stub_licensed_features(security_on_demand_scans: false)
    end

    it 'returns empty nodes array' do
      graphql_response

      expect(profiles).to eq([])
    end
  end

  context 'when feature is licensed' do
    context 'when user is member of the project' do
      context 'when repository access is enabled' do
        it 'returns profiles with branch information' do
          graphql_response

          expect(profiles).to match_array(expected_profiles)
        end
      end

      context 'when repository access is disabled' do
        let(:repository_access_level) { ProjectFeature::DISABLED }

        let(:profile2_data) do
          hash_including(
            'name' => 'Profile 2',
            'branch' => nil
          )
        end

        let(:profile1_data) do
          hash_including(
            'name' => 'Profile 1',
            'branch' => nil
          )
        end

        it 'returns profiles with nil branch names' do
          graphql_response

          expect(profiles).to match_array(expected_profiles)
        end
      end
    end

    context 'when user is not member of the project' do
      let(:current_user) { create(:user) }

      it 'returns nil for project data' do
        graphql_response

        expect(graphql_data_at(:project)).to be_nil
      end
    end
  end
end

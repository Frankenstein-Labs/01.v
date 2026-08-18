# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerabilities.representationInformation', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project) }
  let_it_be(:vulnerability_params) { { id: global_id_of(vulnerability) } }
  let_it_be(:representation_information) do
    create(:vulnerability_representation_information,
      vulnerability: vulnerability,
      project: project,
      resolved_in_commit_sha: 'abc123def456')
  end

  let_it_be(:fields) do
    <<~QUERY
      representationInformation {
        resolvedInCommitSha
      }
    QUERY
  end

  let_it_be(:vulnerabilities_query) do
    <<~QUERY
    {
      project(fullPath: "#{project.full_path}") {
        vulnerabilities {
          nodes {
            representationInformation {
              resolvedInCommitSha
            }
          }
        }
      }
    }
    QUERY
  end

  let_it_be(:query) { graphql_query_for('vulnerability', vulnerability_params, fields) }

  subject(:representation_info) { graphql_data.dig('vulnerability', 'representationInformation') }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  it 'returns the resolved commit SHA for the vulnerability on' do
    post_graphql(query, current_user: user)
    expect(representation_info['resolvedInCommitSha']).to eq(representation_information.resolved_in_commit_sha)
  end

  it 'avoids N+1 queries' do
    post_graphql(vulnerabilities_query, current_user: user)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      post_graphql(vulnerabilities_query, current_user: user)
    end

    vulnerability3 = create(:vulnerability, project: project)
    create(:vulnerability_representation_information,
      vulnerability: vulnerability3,
      project: project,
      resolved_in_commit_sha: 'ghi345jkl678')

    expect do
      post_graphql(vulnerabilities_query, current_user: user)
    end.to issue_same_number_of_queries_as(control).or_fewer
  end
end

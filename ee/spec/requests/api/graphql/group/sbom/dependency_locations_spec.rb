# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group(fullPath).dependencyLocations', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:component) { create(:sbom_component) }
  let_it_be(:component_version) { create(:sbom_component_version, component: component) }
  let_it_be(:occurrence) do
    create(:sbom_occurrence, component: component, component_version: component_version, project: project)
  end

  let(:fields) do
    <<~FIELDS
      occurrenceId
      location {
        blobPath
        path
        topLevel
      }
      hasDependencyPaths
      project {
        name
        fullPath
      }
    FIELDS
  end

  let(:args) { { component_version_id: component_version.to_global_id.to_s } }
  let(:query) do
    nodes = query_nodes(:dependencyLocations, fields, args: args)
    graphql_query_for(:group, { fullPath: group.full_path }, nodes)
  end

  before do
    stub_licensed_features(dependency_scanning: true, security_dashboard: true)
  end

  it 'returns dependency locations' do
    post_graphql(query, current_user: current_user)

    locations = graphql_data_at(:group, :dependency_locations, :nodes)

    expect(locations).to contain_exactly(
      {
        'occurrenceId' => occurrence.to_global_id.to_s,
        'hasDependencyPaths' => false,
        'location' => {
          'blobPath' => occurrence.location[:blob_path],
          'path' => occurrence.location[:path],
          'topLevel' => occurrence.location[:top_level]
        },
        'project' => {
          'name' => project.name,
          'fullPath' => project.full_path
        }
      }
    )
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    [:read_group, :read_dependency] do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:fields) { 'occurrenceId hasDependencyPaths' }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end

  context 'when user is not authorized' do
    let_it_be(:unauthorized_user) { create(:user) }

    it 'returns nil' do
      post_graphql(query, current_user: unauthorized_user)

      expect(graphql_data_at(:group, :dependency_locations)).to be_nil
    end
  end

  context 'with search argument' do
    let_it_be(:occurrence_with_path) do
      create(:sbom_occurrence,
        component: component,
        component_version: component_version,
        project: project,
        input_file_path: 'Gemfile.lock'
      )
    end

    let(:args) { { component_version_id: component_version.to_global_id.to_s, search: 'Gemfile' } }

    it 'filters locations by file path' do
      post_graphql(query, current_user: current_user)

      locations = graphql_data_at(:group, :dependency_locations, :nodes)

      expect(locations).to contain_exactly(
        a_hash_including('occurrenceId' => occurrence_with_path.to_global_id.to_s)
      )
    end
  end

  it 'avoids N+1 database queries', :request_store do
    post_graphql(query, current_user: current_user)

    control = ActiveRecord::QueryRecorder.new do
      post_graphql(query, current_user: current_user)
    end

    create_list(:sbom_occurrence, 3,
      component: component,
      component_version: component_version,
      project: project
    )

    expect do
      post_graphql(query, current_user: current_user)
    end.not_to exceed_query_limit(control)
  end
end

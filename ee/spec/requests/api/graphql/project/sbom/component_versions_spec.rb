# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).component_versions', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:variables) { { full_path: project.full_path } }
  let_it_be(:sbom_component) { create(:sbom_component) }
  let_it_be(:component_version_1) { create(:sbom_component_version, component: sbom_component) }
  let_it_be(:component_version_2) { create(:sbom_component_version, component: sbom_component) }

  let_it_be(:occurrence_1) do
    create(:sbom_occurrence, project: project, component: sbom_component, component_version: component_version_1)
  end

  let_it_be(:occurrence_2) do
    create(:sbom_occurrence, project: project, component: sbom_component, component_version: component_version_2)
  end

  let(:component_versions) { graphql_data_at(:project, :component_versions, :nodes) }
  let(:page_info) { graphql_data_at(:project, :component_versions, :page_info) }

  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          name
          componentVersions(componentName: "#{sbom_component.name}") {
            nodes {
              id
              version
            }
            pageInfo {
              endCursor
              hasNextPage
            }
          }
        }
      }
    )
  end

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)
  end

  subject(:results) do
    post_graphql(query, current_user: current_user)
  end

  context 'when current user is not authorized' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(component_versions).to be_nil
    end
  end

  context 'when current user is an authorized user' do
    it 'returns the expected component versions data when performing a well-formed query' do
      project.add_maintainer(current_user)

      post_graphql(query, current_user: current_user)

      expected = Sbom::ComponentVersion.where(component_id: sbom_component.id).map do |component_version|
        {
          'id' => component_version.to_gid.to_s,
          'version' => component_version.version
        }
      end

      expect(component_versions).to match_array(expected)
      expect(page_info).to be_present
    end
  end
end

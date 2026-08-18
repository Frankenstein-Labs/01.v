# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyPathPage, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let(:dependency_paths) { graphql_response.dig('data', 'project', 'dependencyPaths') }
  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          dependencyPaths(occurrence: "#{target_occ.to_global_id}") {
            nodes {
              path {
                name
                version
              }
              isCyclic
            }

            edges {
              node {
                path {
                  name
                  version
                }
                isCyclic
              }
              cursor
            }

            pageInfo {
              hasPreviousPage
              hasNextPage
              startCursor
              endCursor
            }
          }
        }
      }
    )
  end

  let_it_be(:fields) { %i[nodes edges pageInfo] }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)
  end

  subject(:graphql_response) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe "data parsing" do
    let_it_be(:sbom_occurrence_1) do
      create(:sbom_occurrence, component_name: 'component-1', project: project)
    end

    let_it_be(:sbom_component_2) do
      create(:sbom_occurrence, component_name: 'component-2', project: project)
    end

    let_it_be(:sbom_occurrence_3) do
      create(:sbom_occurrence, component_name: 'component-3', project: project)
    end

    let_it_be(:target_occ) { sbom_occurrence_3 }

    let_it_be(:paths) do
      {
        paths: [{
          path: [sbom_occurrence_1, sbom_component_2, sbom_occurrence_3],
          is_cyclic: false
        }],
        has_next_page: false,
        has_previous_page: false

      }
    end

    let_it_be(:cursor) do
      cursor_for([sbom_occurrence_1.id, sbom_component_2.id, sbom_occurrence_3.id])
    end

    let_it_be(:path) do
      {
        path: [
          { name: sbom_occurrence_1.component_name, version: sbom_occurrence_1.version },
          { name: sbom_component_2.component_name, version: sbom_component_2.version },
          { name: sbom_occurrence_3.component_name, version: sbom_occurrence_3.version }
        ],
        isCyclic: false
      }
    end

    let_it_be(:expected_response) do
      {
        nodes: [
          path
        ],
        edges: [
          {
            node: path,
            cursor: cursor
          }
        ],
        pageInfo: {
          hasPreviousPage: false,
          hasNextPage: false,
          startCursor: cursor,
          endCursor: cursor
        }
      }.as_json
    end

    it 'prases the data from the Sbom::PathFinder and adds appropriate cursors' do
      expect(::Sbom::PathFinder).to receive(:execute).and_return(paths)
      expect(dependency_paths).to match_array(expected_response)
    end
  end

  private

  def cursor_for(ids)
    Base64.encode64(ids.to_json).strip
  end
end

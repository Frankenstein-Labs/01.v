# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyPathType, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let(:dependency_paths) { graphql_response.dig('data', 'project', 'dependencyPaths', 'nodes') }
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
          }
        }
      }
    )
  end

  let_it_be(:fields) { %i[path isCyclic] }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)
  end

  subject(:graphql_response) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe "path parsing" do
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

    let_it_be(:expected_response) do
      [{
        path: [
          { name: sbom_occurrence_1.component_name, version: sbom_occurrence_1.version },
          { name: sbom_component_2.component_name, version: sbom_component_2.version },
          { name: sbom_occurrence_3.component_name, version: sbom_occurrence_3.version }
        ],
        isCyclic: false
      }].as_json
    end

    it "parses the sbom path provided" do
      expect(::Sbom::PathFinder).to receive(:execute).and_return(paths)
      expect(dependency_paths).to match_array(expected_response)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::DependencyLocationsResolver, feature_category: :dependency_management do
  include GraphqlHelpers

  it { expect(described_class).to require_graphql_authorizations(:read_dependency) }

  it 'returns the correct type' do
    expect(described_class.type).to eq(Types::Sbom::DependencyLocationType.connection_type)
  end

  describe '#resolve' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user, developer_of: group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:component_version) { create(:sbom_component_version) }
    let_it_be(:other_component_version) { create(:sbom_component_version) }

    let_it_be(:gemfile_occurrence) do
      create(:sbom_occurrence,
        project: project, component_version: component_version, input_file_path: 'Gemfile.lock')
    end

    let_it_be(:package_occurrence) do
      create(:sbom_occurrence,
        project: project, component_version: component_version, input_file_path: 'package.json')
    end

    let_it_be(:unrelated_occurrence) do
      create(:sbom_occurrence, project: project, component_version: other_component_version)
    end

    before do
      stub_licensed_features(dependency_scanning: true, security_dashboard: true)
    end

    subject(:result) do
      sync(resolve(described_class, obj: group, args: args, ctx: { current_user: user }))
    end

    context 'with component_version_id only' do
      let(:args) { { component_version_id: component_version.to_gid } }

      it { is_expected.to match_array([gemfile_occurrence, package_occurrence]) }
    end

    context 'with a search argument' do
      let(:args) { { component_version_id: component_version.to_gid, search: 'Gemfile' } }

      it { is_expected.to match_array([gemfile_occurrence]) }
    end
  end
end

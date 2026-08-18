# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group(fullPath).dependencyAggregations', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, admin: true, developer_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:component) { create(:sbom_component) }
  let_it_be(:occurrence) { create(:sbom_occurrence, component: component, project: project) }
  let_it_be(:occurrences) { [occurrence] }
  let_it_be(:variables) { { fullPath: group.full_path } }
  let_it_be(:fields) do
    <<~FIELDS
      id
      name
      version
      componentVersion {
        id
        version
      }
      packager
      vulnerabilityCount
      occurrenceCount
      projectCount
      licenses {
        name
        spdxIdentifier
        url
      }
    FIELDS
  end

  let(:query) { pagination_query }
  let(:nodes_path) { %i[group dependencyAggregations nodes] }

  def pagination_query(params = {})
    nodes = query_nodes(:dependencyAggregations, fields, include_pagination_info: true, args: params)
    graphql_query_for(:group, variables, nodes)
  end

  def package_manager_enum(value)
    Types::Sbom::PackageManagerEnum.values.find { |_, custom_value| custom_value.value == value }.first
  end

  before do
    stub_licensed_features(dependency_scanning: true, security_dashboard: true)
  end

  it_behaves_like 'sbom dependency node' do
    let(:licensed_features) { { dependency_scanning: true, security_dashboard: true } }
  end

  it 'returns aggregated dependencies with occurrence count' do
    post_graphql(query, current_user: current_user)

    expect(graphql_data_at(:group, :dependencyAggregations)).not_to be_nil
    expect(graphql_data_at(:group, :dependencyAggregations, :nodes)).to include(
      a_hash_including(
        'name' => component.name,
        'version' => occurrence.version,
        'componentVersion' => {
          'id' => occurrence.component_version.to_gid.to_s,
          'version' => occurrence.component_version.version
        },
        'occurrenceCount' => 1,
        'projectCount' => 1
      )
    )
  end

  it_behaves_like 'when dependencies graphql query sorted paginated'
  it_behaves_like 'when dependencies graphql query sorted by license'
  it_behaves_like 'when dependencies graphql query filtered by package manager' do
    let(:query) { pagination_query({ package_managers: [:BUNDLER] }) }
    let(:expected_packager) { 'BUNDLER' }
  end

  it_behaves_like 'when dependencies graphql query sorted by severity'
  it_behaves_like 'when dependencies graphql query sorted by name'
  it_behaves_like 'when dependencies graphql query sorted by packager'
  it_behaves_like 'when dependencies graphql query filtered by component name'
  it_behaves_like 'when dependencies graphql query filtered by source type'

  describe 'malware field' do
    let_it_be(:project_b) { create(:project, group: group) }

    let(:malware_fields) { 'name malware' }
    let(:malware_query) do
      nodes = query_nodes(:dependencyAggregations, malware_fields)
      graphql_query_for(:group, variables, nodes)
    end

    it 'avoids N+1 database queries', :request_store do
      vuln = create(:vulnerability, :with_finding, project: project)
      create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vuln)
      vuln.vulnerability_read.update!(identifier_names: ['CVE-2021-1234'])

      # Warmup to flush one-time initialization queries before recording the control
      post_graphql(malware_query, current_user: current_user)

      control = ActiveRecord::QueryRecorder.new do
        post_graphql(malware_query, current_user: current_user)
      end

      # Add more occurrences across multiple projects to verify no N+1
      3.times do
        extra_occurrence = create(:sbom_occurrence, project: project_b)
        extra_vuln = create(:vulnerability, :with_finding, project: project_b)
        create(:sbom_occurrences_vulnerability, occurrence: extra_occurrence, vulnerability: extra_vuln)
        extra_vuln.vulnerability_read.update!(identifier_names: ['CVE-2021-1234'])
      end

      expect do
        post_graphql(malware_query, current_user: current_user)
      end.not_to exceed_query_limit(control)
    end
  end
end

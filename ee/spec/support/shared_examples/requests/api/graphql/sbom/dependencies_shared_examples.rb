# frozen_string_literal: true

RSpec.shared_examples 'sbom dependency node' do
  let(:expected_parent_path) { defined?(group) ? group.full_path : project.full_path }
  let(:subject_entity) { defined?(group) ? :group : :project }
  let(:nodes_path) { defined?(group) ? %i[group dependencyAggregations nodes] : %i[project dependencies nodes] }
  let(:query_base_args) { defined?(group) ? { fullPath: expected_parent_path } : { full_path: expected_parent_path } }
  let(:licensed_features) { { dependency_scanning: true } }

  before do
    stub_licensed_features(**licensed_features)
  end

  it 'returns the expected dependency data when performing a well-formed query with an authorized user' do
    post_graphql(query, current_user: current_user)

    actual = graphql_data_at(*nodes_path)
    expect(actual).not_to be_nil
    expect(actual).to include(a_hash_including('name' => occurrences.first.name))
  end

  context 'with an unauthorized user' do
    let_it_be(:current_user, freeze: false) { create(:user) }

    it 'does not return dependency data' do
      post_graphql(query, current_user: current_user)

      root_path = nodes_path[0...-1]
      expect(graphql_data_at(*root_path)).to be_blank
    end
  end

  it 'does not make N+1 queries' do
    control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

    create(:sbom_occurrence, project: project)

    expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
  end
end

RSpec.shared_context 'when dependencies graphql query sorted paginated' do
  def pagination_results_data(nodes)
    nodes.pluck('id')
  end

  let(:data_path) { defined?(group) ? %i[group dependencyAggregations] : %i[project dependencies] }
  let(:sort_argument) { {} }
  let(:first_param) { 2 }
  let(:all_records) { occurrences.sort_by(&:id).map { |occurrence| occurrence.to_gid.to_s } }
end

RSpec.shared_context 'with dependency sort assertions' do
  # Keeps the response order but drops any node the host spec seeded, so a single
  # expectation holds for both the aggregations and the project dependencies path.
  def sorted_fixture_ids(expected_ids)
    graphql_data_at(*nodes_path).pluck('id').select { |id| expected_ids.include?(id) }
  end

  def gids_in_order(fixtures, *keys)
    fixtures.values_at(*keys).map { |occurrence| occurrence.to_gid.to_s }
  end
end

RSpec.shared_examples 'when dependencies graphql query sorted by severity' do
  include_context 'with dependency sort assertions'

  let_it_be(:severity_dependencies, freeze: false) do
    %w[high low critical medium].index_with do |severity|
      create(:sbom_occurrence, project: project, highest_severity: severity,
        component: create(:sbom_component, name: "severity-#{severity}"))
    end
  end

  let(:expected_asc) { gids_in_order(severity_dependencies, 'low', 'medium', 'high', 'critical') }

  context 'with sort as an argument' do
    let(:desc_query) { pagination_query({ sort: :SEVERITY_DESC }) }
    let(:asc_query) { pagination_query({ sort: :SEVERITY_ASC }) }

    it 'sorts by severity descending' do
      post_graphql(desc_query, current_user: current_user)

      expect(sorted_fixture_ids(expected_asc)).to eq(expected_asc.reverse)
    end

    it 'sorts by severity ascending' do
      post_graphql(asc_query, current_user: current_user)

      expect(sorted_fixture_ids(expected_asc)).to eq(expected_asc)
    end
  end
end

RSpec.shared_examples 'when dependencies graphql query sorted by name' do
  include_context 'with dependency sort assertions'

  let_it_be(:name_dependencies, freeze: false) do
    %w[ccc aaa ddd bbb].index_with do |name|
      create(:sbom_occurrence, project: project, component: create(:sbom_component, name: name))
    end
  end

  let(:expected_asc) { gids_in_order(name_dependencies, 'aaa', 'bbb', 'ccc', 'ddd') }

  context 'with sort as an argument' do
    let(:desc_query) { pagination_query({ sort: :NAME_DESC }) }
    let(:asc_query) { pagination_query({ sort: :NAME_ASC }) }

    it 'sorts by name descending' do
      post_graphql(desc_query, current_user: current_user)

      expect(sorted_fixture_ids(expected_asc)).to eq(expected_asc.reverse)
    end

    it 'sorts by name ascending' do
      post_graphql(asc_query, current_user: current_user)

      expect(sorted_fixture_ids(expected_asc)).to eq(expected_asc)
    end
  end
end

RSpec.shared_examples 'when dependencies graphql query sorted by packager' do
  include_context 'with dependency sort assertions'

  let_it_be(:packager_dependencies, freeze: false) do
    %i[nuget bundler yarn npm].index_with do |packager|
      create(:sbom_occurrence, packager, project: project,
        component: create(:sbom_component, name: "packager-#{packager}"))
    end
  end

  let(:expected_asc) { gids_in_order(packager_dependencies, :bundler, :npm, :nuget, :yarn) }

  context 'with sort as an argument' do
    let(:desc_query) { pagination_query({ sort: :PACKAGER_DESC }) }
    let(:asc_query) { pagination_query({ sort: :PACKAGER_ASC }) }

    it 'sorts by packager descending' do
      post_graphql(desc_query, current_user: current_user)

      expect(sorted_fixture_ids(expected_asc)).to eq(expected_asc.reverse)
    end

    it 'sorts by packager ascending', :aggregate_failures do
      post_graphql(asc_query, current_user: current_user)

      expect(sorted_fixture_ids(expected_asc)).to eq(expected_asc)

      nodes = graphql_data_at(*nodes_path).select { |node| expected_asc.include?(node['id']) }
      expect(nodes.pluck('packager')).to eq(%w[BUNDLER NPM NUGET YARN])
    end
  end
end

RSpec.shared_examples 'when dependencies graphql query sorted by license' do
  let_it_be(:test_dependencies, freeze: false) do
    components = create_list(:sbom_component, 6)

    [
      create(:sbom_occurrence, project: project, component: components[0], licenses: []),
      create(:sbom_occurrence, project: project, component: components[1], licenses: [
        { "name" => "Apache License 2.0", "spdx_identifier" => "Apache-2.0", "url" => "https://spdx.org/licenses/Apache-2.0.html" }
      ]),
      create(:sbom_occurrence, project: project, component: components[2], licenses: [
        { "name" => "BSD 2-Clause License", "spdx_identifier" => "BSD-2-Clause", "url" => "https://spdx.org/licenses/BSD-2-Clause.html" }
      ]),
      create(:sbom_occurrence, project: project, component: components[3], licenses: [
        { "name" => "MIT License", "spdx_identifier" => "MIT", "url" => "https://spdx.org/licenses/MIT.html" }
      ]),
      create(:sbom_occurrence, project: project, component: components[4], licenses: [
        { "name" => "Unknown License", "spdx_identifier" => "NOASSERTION", "url" => nil }
      ]),
      create(:sbom_occurrence, project: project, component: components[5], licenses: [
        { "name" => "Custom License", "spdx_identifier" => nil, "url" => "https://example.com/license" }
      ])
    ]
  end

  let(:desc_query) { pagination_query({ sort: :LICENSE_DESC }) }
  let(:asc_query) { pagination_query({ sort: :LICENSE_ASC }) }

  before do
    test_dependencies.each(&:reload)
  end

  it 'sorts by license ascending' do
    post_graphql(asc_query, current_user: current_user)

    spdx_identifiers = graphql_data_at(*nodes_path).map do |node|
      licenses = node['licenses']
      next nil if licenses.nil? || licenses.empty?

      licenses.first&.dig('spdxIdentifier')
    end

    non_null_identifiers = spdx_identifiers.compact
    expect(non_null_identifiers).to eq(non_null_identifiers.sort)

    expected_non_null_order = ["Apache-2.0", "BSD-2-Clause", "MIT", "NOASSERTION"]
    expect(non_null_identifiers).to eq(expected_non_null_order)
  end

  it 'sorts by license descending' do
    post_graphql(desc_query, current_user: current_user)

    spdx_identifiers = graphql_data_at(*nodes_path).map do |node|
      licenses = node['licenses']
      next nil if licenses.nil? || licenses.empty?

      licenses.first&.dig('spdxIdentifier')
    end

    non_null_identifiers = spdx_identifiers.compact
    expect(non_null_identifiers).to eq(non_null_identifiers.sort.reverse)

    null_count = spdx_identifiers.count(&:nil?)
    expect(null_count).to be > 0

    expected_non_null_order = ["NOASSERTION", "MIT", "BSD-2-Clause", "Apache-2.0"]
    expect(non_null_identifiers).to eq(expected_non_null_order)
  end

  it 'produces different results for ASC and DESC' do
    post_graphql(asc_query, current_user: current_user)
    asc_results = graphql_data_at(*nodes_path).pluck('id')

    post_graphql(desc_query, current_user: current_user)
    desc_results = graphql_data_at(*nodes_path).pluck('id')

    expect(asc_results).not_to eq(desc_results)
  end

  it 'handles empty licenses consistently' do
    post_graphql(asc_query, current_user: current_user)

    results = graphql_data_at(*nodes_path)
    empty_license_nodes = results.select { |node| node['licenses'].empty? }

    expect(empty_license_nodes).not_to be_empty
  end

  it 'handles null spdx_identifier values' do
    post_graphql(asc_query, current_user: current_user)

    results = graphql_data_at(*nodes_path)
    null_spdx_nodes = results.select do |node|
      licenses = node['licenses']
      next false if licenses.nil? || licenses.empty?

      licenses.any? { |license| license['spdxIdentifier'].nil? }
    end

    expect(null_spdx_nodes).not_to be_empty
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by package manager' do
  it 'returns only matching package manager results' do
    post_graphql(query, current_user: current_user)
    result = graphql_data_at(*nodes_path)
    packagers = result.pluck('packager')

    expect(packagers).to all(eq expected_packager)
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by component name' do
  let!(:test_occurrence) { create(:sbom_occurrence, project: project) }
  let(:component_name) { test_occurrence.name }
  let(:component_query) { pagination_query({ component_names: [component_name] }) }

  it 'filters records based on the component name' do
    post_graphql(component_query, current_user: current_user)

    result = graphql_data_at(*nodes_path)
    names = result.pluck('name')
    expect(names).to eq([component_name])
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by source type' do
  let!(:registry_occurrence) { create(:sbom_occurrence, :registry_occurrence, project: project) }
  let(:source_type_query) { pagination_query({ source_types: [:CONTAINER_SCANNING_FOR_REGISTRY] }) }

  it 'filters records based on the source type' do
    post_graphql(source_type_query, current_user: current_user)

    result = graphql_data_at(*nodes_path)
    expect(result).not_to be_empty
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by component versions' do
  let_it_be(:matching_component_version, freeze: false) { '1.2.3' }
  let_it_be(:other_component_version, freeze: false) { '4.5.6' }
  let_it_be(:matching_occurrence, freeze: false) do
    create(:sbom_occurrence, project: project,
      component_version: create(:sbom_component_version, version: matching_component_version))
  end

  let_it_be(:other_occurrence, freeze: false) do
    create(:sbom_occurrence, project: project,
      component_version: create(:sbom_component_version, version: other_component_version))
  end

  let(:queried_component_version) { [matching_component_version] }
  let(:component_version_query_payload) { { component_versions: queried_component_version } }
  let(:dependencies_query) { pagination_query(component_version_query_payload) }

  context 'when the version filtering is available for the project' do
    it 'returns only records matching the specified component version(s)' do
      post_graphql(dependencies_query, current_user: current_user)

      result_nodes = graphql_data_at(*nodes_path)
      versions_in_result = result_nodes.pluck('version')
      component_versions_in_result = result_nodes.map { |node| node.dig('componentVersion', 'version') }

      expect(component_versions_in_result).to contain_exactly(matching_component_version)
      expect(versions_in_result).to contain_exactly(matching_component_version)
      expect(result_nodes.size).to eq(1)
    end
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by not component versions' do
  let_it_be(:excluded_component_versions, freeze: false) { ['1.2.3', '1.2.5', '1.2.7'] }
  let_it_be(:included_component_version, freeze: false) { '4.5.6' }
  let_it_be(:excluded_occurrences, freeze: false) do
    excluded_component_versions.map do |version|
      create(:sbom_occurrence, project: project,
        component_version: create(:sbom_component_version, version: version))
    end
  end

  let_it_be(:included_occurrence, freeze: false) do
    create(:sbom_occurrence, project: project,
      component_version: create(:sbom_component_version, version: included_component_version))
  end

  let(:queried_not_component_version) { excluded_component_versions }
  let(:not_component_version_query_payload) { { not_component_versions: queried_not_component_version } }
  let(:dependencies_query) { pagination_query(not_component_version_query_payload) }

  it 'returns only records not matching the specified component version(s)' do
    post_graphql(dependencies_query, current_user: current_user)

    result_nodes = graphql_data_at(*nodes_path)
    versions_in_result = result_nodes.map { |node| node.dig('componentVersion', 'version') }

    expect(versions_in_result).to include(included_component_version)
    expect(versions_in_result).not_to include(*excluded_component_versions)
  end
end

RSpec.shared_examples 'when dependencies graphql query filtered by policy violations' do
  let(:policy_violations_query) { pagination_query({ policy_violations: [:DISMISSED_IN_MR] }) }

  let_it_be(:non_dismissed_occurrence, freeze: false) { create(:sbom_occurrence, project: project) }
  let_it_be(:dismissed_occurrence, freeze: false) { create(:sbom_occurrence, project: project) }

  before do
    create(:policy_dismissal, :preserved, project: project, license_occurrence_uuids: [dismissed_occurrence.uuid])
  end

  it 'filters records based on the policy violations' do
    post_graphql(policy_violations_query, current_user: current_user)

    result_nodes = graphql_data_at(*nodes_path)
    id_in_result = result_nodes.pluck('id')

    expect(result_nodes.size).to eq(1)
    expect(id_in_result).to include("gid://gitlab/Sbom::Occurrence/#{dismissed_occurrence.id}")
  end
end

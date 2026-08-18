# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.dependency(id)', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:occurrence) { create(:sbom_occurrence, project: project) }
  let_it_be(:global_id) { occurrence.to_gid.to_s }

  let_it_be(:vulnerabilities) { create_list(:vulnerability, 3, :with_findings, project: project) }

  let_it_be(:occurrence_vulnerabilities) do
    vulnerabilities.map.with_index do |vulnerability, index|
      create(:sbom_occurrences_vulnerability,
        occurrence: occurrence,
        vulnerability: vulnerability,
        project: project,
        created_at: index.days.ago)
    end
  end

  let_it_be(:fields) do
    <<~FIELDS
      id
      name
      vulnerabilities {
        nodes {
          id
          name
          severity
          description
          webUrl
        }
      }
    FIELDS
  end

  let(:variables) { { id: global_id } }
  let(:query) { graphql_query_for(:dependency, variables, fields) }

  before do
    stub_licensed_features(dependency_scanning: true, security_dashboard: true)
    post_graphql(query, current_user: current_user)
  end

  it 'returns the expected dependency data' do
    dependency_data = graphql_data_at(:dependency)
    expect(dependency_data['id']).to eq(global_id)
    expect(dependency_data['name']).to eq(occurrence.name)
  end

  it 'returns the expected vulnerabilities' do
    vulnerability_nodes = graphql_data_at(:dependency, :vulnerabilities, :nodes)
    expect(vulnerability_nodes.length).to eq(vulnerabilities.length)

    expected_vulnerabilities = vulnerabilities.map do |vulnerability|
      {
        'id' => vulnerability.to_gid.to_s,
        'name' => vulnerability.title,
        'severity' => vulnerability.severity.upcase,
        'description' => vulnerability.description,
        'webUrl' => Gitlab::Routing.url_helpers.project_security_vulnerability_url(vulnerability.project,
          vulnerability)
      }
    end

    expected_sorted = expected_vulnerabilities.sort_by { |v| v['id'] }
    actual_sorted = vulnerability_nodes.sort_by { |v| v['id'] }

    expect(actual_sorted).to eq(expected_sorted)
  end

  it 'avoids N+1 queries when loading vulnerabilities' do
    post_graphql(query, current_user: current_user)
    control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

    create_list(:vulnerability, 3, :with_findings, project: project).each do |vulnerability|
      create(:sbom_occurrences_vulnerability,
        occurrence: occurrence,
        vulnerability: vulnerability,
        project: project
      )
    end

    expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)

    vulnerability_nodes = graphql_data_at(:dependency, :vulnerabilities, :nodes)
    expect(vulnerability_nodes.length).to eq(vulnerabilities.length + 3)
  end

  context 'when the user does not have permission to read dependencies' do
    let_it_be(:unauthorized_user) { create(:user) }

    it 'returns nil' do
      post_graphql(query, current_user: unauthorized_user)

      expect(graphql_data_at(:dependency)).to be_nil
    end
  end

  context 'when the dependency id is invalid' do
    let(:variables) { { id: "gid://gitlab/Sbom::Occurrence/0" } }
    let_it_be(:unauthorized_user) { create(:user) }

    it 'returns nil' do
      post_graphql(query, current_user: unauthorized_user)

      expect(graphql_data_at(:dependency)).to be_nil
    end
  end

  context 'when the dependency has no vulnerabilities' do
    let_it_be(:occurrence_without_vulnerabilities) { create(:sbom_occurrence, project: project) }
    let(:variables) { { id: occurrence_without_vulnerabilities.to_gid.to_s } }

    it 'returns an empty array for vulnerabilities' do
      vulnerability_nodes = graphql_data_at(:dependency, :vulnerabilities, :nodes)
      expect(vulnerability_nodes).to eq([])
    end
  end
end

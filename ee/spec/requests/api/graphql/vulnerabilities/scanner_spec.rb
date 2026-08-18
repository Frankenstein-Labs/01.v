# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerabilities.scanner', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }

  let_it_be(:fields) do
    <<~QUERY
      scanner {
        name
        externalId
      }
    QUERY
  end

  let_it_be(:query) do
    graphql_query_for('vulnerabilities', {}, query_graphql_field('nodes', {}, fields))
  end

  let_it_be(:vulnerability) { create(:vulnerability, project: project, report_type: :container_scanning) }

  let_it_be(:vulnerabilities_scanner) do
    create(
      :vulnerabilities_scanner,
      name: 'Vulnerability Scanner',
      external_id: 'vulnerabilities_scanner',
      project: project
    )
  end

  let_it_be(:finding) do
    create(
      :vulnerabilities_finding,
      vulnerability: vulnerability,
      scanner: vulnerabilities_scanner
    )
  end

  subject { graphql_data.dig('vulnerabilities', 'nodes') }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)

    post_graphql(query, current_user: user)
  end

  it 'returns a vulnerability scanner' do
    scanner = subject.first['scanner']

    expect(scanner['name']).to eq(vulnerabilities_scanner.name)
    expect(scanner['externalId']).to eq(vulnerabilities_scanner.external_id)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    [:read_project, :read_vulnerability_scanner] do
    let(:boundary_object) { project }
    let(:query) do
      graphql_query_for(
        :project,
        { full_path: project.full_path },
        query_graphql_field('vulnerabilityScanners', {}, query_graphql_field('nodes', {}, 'id'))
      )
    end

    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    [:read_group, :read_vulnerability_scanner] do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_project) { create(:project, group: group) }
    let_it_be(:group_scanner) { create(:vulnerabilities_scanner, project: group_project) }
    let_it_be(:group_vulnerability) { create(:vulnerability, project: group_project) }
    let_it_be(:group_finding) do
      create(:vulnerabilities_finding, vulnerability: group_vulnerability, scanner: group_scanner)
    end

    let(:boundary_object) { group }
    let(:query) do
      graphql_query_for(
        :group,
        { full_path: group.full_path },
        query_graphql_field('vulnerabilityScanners', {}, query_graphql_field('nodes', {}, 'id'))
      )
    end

    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }

    before_all do
      group.add_developer(user)
    end
  end
end

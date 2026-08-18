# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerabilities.severityOverride', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, :detected, project: project, severity: :high) }
  let_it_be(:severity_override) do
    create(:vulnerability_severity_override,
      vulnerability: vulnerability,
      project: project,
      author: user,
      original_severity: :high,
      new_severity: :critical
    )
  end

  let(:fields) do
    <<~QUERY
      nodes {
        id
        severity
        state
        severityOverrides {
          nodes {
            originalSeverity
            newSeverity
            author {
              name
            }
          }
        }
      }
    QUERY
  end

  let(:query) { graphql_query_for('vulnerabilities', { projectId: project.id }, fields) }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'severity override data' do
    before do
      post_graphql(query, current_user: user)
    end

    it_behaves_like 'a working graphql query'

    it 'returns severity override data' do
      result = graphql_data.dig('vulnerabilities', 'nodes', 0, 'severityOverrides', 'nodes', 0)

      aggregate_failures do
        expect(result).to be_present
        expect(result['originalSeverity']).to eq('HIGH')
        expect(result['newSeverity']).to eq('CRITICAL')
        expect(result['author']['name']).to eq(user.name)
      end
    end

    context 'when vulnerability has no severity override' do
      let_it_be(:vulnerability_without_override) { create(:vulnerability, :with_finding, :detected, project: project) }

      it 'returns empty nodes for severityOverrides' do
        result = graphql_data.dig('vulnerabilities', 'nodes', 0, 'severityOverrides', 'nodes')

        expect(result).to be_empty
      end
    end
  end

  context 'when security_dashboard feature is not licensed' do
    before do
      stub_licensed_features(security_dashboard: false)
      post_graphql(query, current_user: user)
    end

    it_behaves_like 'a working graphql query'

    it 'returns no vulnerabilities' do
      nodes = graphql_data.dig('vulnerabilities', 'nodes')

      expect(nodes).to be_empty
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerabilities.cveEnrichment', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }

  let_it_be(:fields) do
    <<~QUERY
      cveEnrichment {
        cve
        epssScore
        isKnownExploit
      }
    QUERY
  end

  let_it_be(:query) do
    graphql_query_for('vulnerabilities', {}, query_graphql_field('nodes', {}, fields))
  end

  let_it_be(:vulnerability) { create(:vulnerability, project: project, report_type: :container_scanning) }

  let_it_be(:cve_enrichment) { create(:pm_cve_enrichment) }
  let_it_be(:identifier) do
    create(:vulnerabilities_identifier, external_type: 'cve', external_id: cve_enrichment.cve, name: cve_enrichment.cve)
  end

  let_it_be(:finding) do
    create(
      :vulnerabilities_finding,
      vulnerability: vulnerability,
      identifiers: [identifier]
    )
  end

  subject(:data) { graphql_data.dig('vulnerabilities', 'nodes') }

  before_all do
    project.add_developer(user)
  end

  context 'when security_dashboard feature is licensed' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    it 'returns cve enrichment' do
      post_graphql(query, current_user: user)

      result = data.first['cveEnrichment']

      expect(result['cve']).to eq(cve_enrichment.cve)
      expect(result['epssScore']).to eq(cve_enrichment.epss_score)
      expect(result['isKnownExploit']).to eq(cve_enrichment.is_known_exploit)
    end

    it 'returns nil for non-cve identifier' do
      non_cve_identifier = create(
        :vulnerabilities_identifier,
        external_type: 'non-cve',
        external_id: 'non-cve',
        name: 'non-cve')

      non_cve_vuln = create(:vulnerability, project: project, report_type: :container_scanning)

      create(
        :vulnerabilities_finding,
        vulnerability: non_cve_vuln,
        identifiers: [non_cve_identifier]
      )

      post_graphql(query, current_user: user)

      expect(data).to contain_exactly(
        { "cveEnrichment" => nil },
        { "cveEnrichment" => { "cve" => cve_enrichment.cve,
                               "epssScore" => cve_enrichment.epss_score,
                               "isKnownExploit" => cve_enrichment.is_known_exploit } })
    end

    it 'does not have N+1 queries' do
      # warm up
      post_graphql(query, current_user: user)

      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }

      new_vuln = create(:vulnerability, project: project, report_type: :container_scanning)

      new_cve = "CVE-2020-1234"
      create(
        :vulnerabilities_finding,
        vulnerability: new_vuln,
        identifiers: [create(:vulnerabilities_identifier, external_type: 'cve', external_id: new_cve, name: new_cve)]
      )

      expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(control)
    end
  end
end

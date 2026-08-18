# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Security metrics through OrganizationQuery', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }

  let(:query) do
    graphql_query_for('organization', { 'id' => organization.to_global_id.to_s }, 'securityMetrics { __typename }')
  end

  subject(:post_query) { post_graphql(query, current_user: current_user) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  def security_metrics_data
    graphql_dig_at(graphql_data, :organization, :security_metrics)
  end

  context 'when the user is an organization owner' do
    it 'exposes the security metrics field' do
      post_query

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
      expect(security_metrics_data).to eq('__typename' => 'SecurityMetrics')
    end

    context 'when the organization_security_dashboard feature flag is disabled' do
      before do
        stub_feature_flags(organization_security_dashboard: false)
      end

      it 'returns null for security metrics' do
        post_query

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
        expect(security_metrics_data).to be_nil
      end
    end

    context 'when filtering by project IDs' do
      let(:query) do
        graphql_query_for(
          'organization',
          { 'id' => organization.to_global_id.to_s },
          "securityMetrics(projectId: [\"gid://gitlab/Project/1\"]) { __typename }"
        )
      end

      it 'accepts the filter without error' do
        post_query

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
        expect(security_metrics_data).to eq('__typename' => 'SecurityMetrics')
      end
    end

    context 'when filtering by security attributes' do
      let(:query) do
        graphql_query_for(
          'organization',
          { 'id' => organization.to_global_id.to_s },
          'securityMetrics(securityAttributesFilters: ' \
            '[{ operator: IS_ONE_OF, attributes: ["gid://gitlab/Security::Attribute/1"] }]) { __typename }'
        )
      end

      it 'ignores the filter without error' do
        post_query

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
        expect(security_metrics_data).to eq('__typename' => 'SecurityMetrics')
      end
    end

    context 'when the security_dashboard feature is not licensed' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'returns null for security metrics' do
        post_query

        expect(response).to have_gitlab_http_status(:ok)
        expect(graphql_errors).to be_nil
        expect(security_metrics_data).to be_nil
      end
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'returns null for security metrics' do
      post_query

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
      expect(security_metrics_data).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'returns null for security metrics' do
      post_query

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
      expect(security_metrics_data).to be_nil
    end
  end

  context 'when the user is not authenticated' do
    let(:current_user) { nil }

    it 'returns null for security metrics' do
      post_query

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil
      expect(security_metrics_data).to be_nil
    end
  end

  context 'when resolving metrics end to end', :elastic_delete_by_query, :sidekiq_inline do
    let_it_be(:root_group_a) { create(:group, organization: organization) }
    let_it_be(:root_group_b) { create(:group, organization: organization) }
    let_it_be(:project_a) { create(:project, group: root_group_a) }
    let_it_be(:project_b) { create(:project, group: root_group_b) }

    let_it_be(:critical_vulnerability) do
      create(:vulnerability, :with_finding, severity: :critical, report_type: :sast, state: :detected,
        project: project_a)
    end

    let_it_be(:high_vulnerability) do
      create(:vulnerability, :with_finding, severity: :high, report_type: :sast, state: :detected,
        project: project_b)
    end

    let(:query) do
      graphql_query_for(
        'organization',
        { 'id' => organization.to_global_id.to_s },
        <<~FIELDS
          securityMetrics {
            vulnerabilitiesPerSeverity {
              critical { count }
              high { count }
            }
          }
        FIELDS
      )
    end

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      set_elasticsearch_migration_to(:backfill_organization_id_in_vulnerabilities)

      Elastic::ProcessBookkeepingService.track!(critical_vulnerability, high_vulnerability)
      ensure_elasticsearch_index!
    end

    it 'aggregates vulnerability counts across the organization root groups', :aggregate_failures do
      post_query

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      per_severity = security_metrics_data['vulnerabilitiesPerSeverity']
      expect(per_severity['critical']['count']).to eq(1)
      expect(per_severity['high']['count']).to eq(1)
    end
  end

  context 'when resolving the risk score end to end', :elastic_delete_by_query, :sidekiq_inline do
    let_it_be(:root_group_a) { create(:group, organization: organization) }
    let_it_be(:root_group_b) { create(:group, organization: organization) }
    let_it_be(:project_a) { create(:project, :public, group: root_group_a, organization: organization) }
    let_it_be(:project_b) { create(:project, :public, group: root_group_b, organization: organization) }

    let_it_be(:vulnerability_a) do
      create(:vulnerability, :with_finding_risk_score, :confirmed, severity: :high, project: project_a)
    end

    let_it_be(:vulnerability_b) do
      create(:vulnerability, :with_finding_risk_score, :detected, severity: :critical, project: project_b)
    end

    let(:query) do
      graphql_query_for(
        'organization',
        { 'id' => organization.to_global_id.to_s },
        <<~FIELDS
          securityMetrics {
            riskScore {
              score
              rating
              byProject { nodes { score project { id } } }
            }
          }
        FIELDS
      )
    end

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      set_elasticsearch_migration_to(:backfill_organization_id_in_vulnerabilities)
      ::Elastic::ProcessBookkeepingService.track!(vulnerability_a, vulnerability_b)
      ensure_elasticsearch_index!
    end

    it 'resolves the risk score with a by-project breakdown aggregated across the organization',
      :aggregate_failures do
      post_query

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      risk_score = security_metrics_data['riskScore']
      expect(risk_score['score']).to be_a(Numeric)
      expect(risk_score['rating']).to be_in(%w[LOW MEDIUM HIGH CRITICAL UNKNOWN])
      expect(graphql_dig_at(risk_score, :by_project, :nodes)).to contain_exactly(
        a_hash_including('project' => a_graphql_entity_for(project_a)),
        a_hash_including('project' => a_graphql_entity_for(project_b))
      )
    end
  end
end

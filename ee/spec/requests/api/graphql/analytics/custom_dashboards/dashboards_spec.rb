# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query custom dashboards', feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_organization) { organization }
  let_it_be(:namespace) { create(:group, organization: organization) }

  let(:fields) do
    <<~QUERY
      nodes {
        id
        name
        description
        ... on CustomDashboard {
          namespace {
            id
          }
        }
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      :custom_dashboards,
      { organization_id: organization.to_global_id.to_s },
      fields
    )
  end

  before do
    stub_licensed_features(product_analytics: true)
    allow(Analytics::CustomDashboards::SystemDashboardsLoader).to receive(:all).and_return([])
  end

  context 'when querying organization-scoped dashboards' do
    let_it_be(:org_dashboard1) do
      create(:dashboard, :organization_scoped, organization: organization, name: 'Org Dashboard 1')
    end

    let_it_be(:org_dashboard2) do
      create(:dashboard, :organization_scoped, organization: organization, name: 'Org Dashboard 2')
    end

    context 'when user is organization member' do
      let_it_be(:user) { create(:user, organization: organization) }

      before_all do
        Organizations::OrganizationUser.find_or_create_by!(
          organization: organization,
          user: user
        )
      end

      it 'returns organization-scoped dashboards' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(:custom_dashboards, :nodes)).to contain_exactly(
          a_hash_including('id' => org_dashboard1.to_global_id.to_s, 'name' => 'Org Dashboard 1', 'namespace' => nil),
          a_hash_including('id' => org_dashboard2.to_global_id.to_s, 'name' => 'Org Dashboard 2', 'namespace' => nil)
        )
      end
    end
  end

  context 'when querying namespace-scoped dashboards' do
    let_it_be(:ns_dashboard1) do
      create(:dashboard, organization: organization, namespace: namespace, name: 'Namespace Dashboard 1')
    end

    let_it_be(:ns_dashboard2) do
      create(:dashboard, organization: organization, namespace: namespace, name: 'Namespace Dashboard 2')
    end

    context 'when user has reporter access to namespace' do
      let_it_be(:user) { create(:user, organization: organization) }

      before_all do
        Organizations::OrganizationUser.find_or_create_by!(
          organization: organization,
          user: user
        )

        create(:group_member, :reporter, group: namespace, user: user)
      end

      it 'returns namespace-scoped dashboards' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(:custom_dashboards, :nodes)).to contain_exactly(
          a_hash_including(
            'id' => ns_dashboard1.to_global_id.to_s,
            'name' => 'Namespace Dashboard 1',
            'namespace' => a_hash_including('id' => namespace.to_global_id.to_s)
          ),
          a_hash_including(
            'id' => ns_dashboard2.to_global_id.to_s,
            'name' => 'Namespace Dashboard 2',
            'namespace' => a_hash_including('id' => namespace.to_global_id.to_s)
          )
        )
      end
    end
  end

  context 'when querying mixed scope dashboards' do
    let_it_be(:user) { create(:user, organization: organization) }

    let_it_be(:org_dashboard) do
      create(:dashboard, :organization_scoped, organization: organization, name: 'Org Dashboard')
    end

    let_it_be(:ns_dashboard) do
      create(:dashboard, organization: organization, namespace: namespace, name: 'NS Dashboard')
    end

    before_all do
      Organizations::OrganizationUser.find_or_create_by!(
        organization: organization,
        user: user
      )

      create(:group_member, :reporter, group: namespace, user: user)
    end

    it 'returns both organization and namespace-scoped dashboards user has access to' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(:custom_dashboards, :nodes)).to contain_exactly(
        a_hash_including('id' => org_dashboard.to_global_id.to_s, 'name' => 'Org Dashboard', 'namespace' => nil),
        a_hash_including(
          'id' => ns_dashboard.to_global_id.to_s,
          'name' => 'NS Dashboard',
          'namespace' => a_hash_including('id' => namespace.to_global_id.to_s)
        )
      )
    end
  end

  context 'when querying with gitlab scope filter' do
    let_it_be(:user) { create(:user, organization: organization) }

    let(:system_dashboard) do
      Analytics::CustomDashboards::SystemDashboard.new(
        slug: 'gitlab_duo',
        config: { 'title' => 'GitLab Duo and SDLC trends', 'version' => '2', 'panels' => [] }
      )
    end

    let(:query) do
      <<~GQL
        {
          customDashboards(organizationId: "#{organization.to_global_id}", scope: GITLAB) {
            nodes {
              id
              name
              description
              ... on CustomDashboard {
                namespace {
                  id
                }
              }
            }
          }
        }
      GQL
    end

    before_all do
      Organizations::OrganizationUser.find_or_create_by!(
        organization: organization,
        user: user
      )
    end

    before do
      allow(Analytics::CustomDashboards::SystemDashboardsLoader).to receive(:all).and_return([system_dashboard])
    end

    it 'returns only system dashboards' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(:custom_dashboards, :nodes)).to contain_exactly(
        a_hash_including('name' => 'GitLab Duo and SDLC trends')
      )
    end

    it 'does not return db dashboards' do
      create(:dashboard, :organization_scoped, organization: organization)

      post_graphql(query, current_user: user)

      expect(graphql_data_at(:custom_dashboards, :nodes)).not_to include(
        a_hash_including('name' => 'Org Dashboard 1')
      )
    end
  end
end

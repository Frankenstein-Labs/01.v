# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query single custom dashboard', feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_organization) { organization }
  let_it_be(:namespace) { create(:group, organization: organization) }
  let_it_be(:creator) { create(:user) }

  let_it_be(:valid_config) do
    {
      version: '2',
      title: 'Test Dashboard',
      panels: [
        {
          title: 'Test Panel',
          visualization: 'number',
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    }
  end

  let(:fields) do
    <<~GRAPHQL
      id
      name
      description
      config
      organization { id }
      namespace { id }
      createdBy { id username }
      createdAt
      updatedAt
    GRAPHQL
  end

  let(:query) do
    graphql_query_for(
      :custom_dashboard,
      { id: dashboard.to_global_id.to_s },
      fields
    )
  end

  subject(:execute_query) do
    post_graphql(query, current_user: current_user)
  end

  context 'when dashboard is organization-scoped' do
    let_it_be(:dashboard) do
      create(
        :dashboard,
        :organization_scoped,
        organization: organization,
        created_by: creator,
        name: 'Org Scoped Dashboard',
        description: 'Org scoped description',
        config: valid_config
      )
    end

    context 'when user is organization member' do
      let_it_be(:current_user) { create(:user) }

      before do
        create(:organization_user, organization: organization, user: current_user)
      end

      it 'returns the dashboard' do
        execute_query

        dashboard_data = graphql_data_at(:custom_dashboard)

        expect(dashboard_data).to include(
          'id' => dashboard.to_global_id.to_s,
          'name' => 'Org Scoped Dashboard',
          'description' => 'Org scoped description',
          'config' => valid_config.deep_stringify_keys
        )

        expect(dashboard_data['namespace']).to be_nil
        expect(dashboard_data['organization']).to include(
          'id' => organization.to_global_id.to_s
        )
      end
    end

    context 'when user is not an organization member' do
      let(:current_user) { create(:user) }

      it 'returns nil' do
        execute_query

        expect(graphql_data_at(:custom_dashboard)).to be_nil
      end
    end
  end

  context 'when dashboard is namespace-scoped' do
    let_it_be(:dashboard) do
      create(
        :dashboard,
        organization: organization,
        namespace: namespace,
        created_by: creator,
        name: 'Namespace Scoped Dashboard',
        description: 'Namespace scoped description',
        config: valid_config
      )
    end

    context 'when user has namespace access' do
      let_it_be(:current_user) { create(:user) }

      before do
        create(:organization_user, organization: organization, user: current_user)
        create(:group_member, :reporter, group: namespace, user: current_user)
      end

      it 'returns the dashboard' do
        execute_query

        dashboard_data = graphql_data_at(:custom_dashboard)

        expect(dashboard_data).to include(
          'id' => dashboard.to_global_id.to_s,
          'name' => 'Namespace Scoped Dashboard',
          'description' => 'Namespace scoped description'
        )

        expect(dashboard_data['namespace']).to include(
          'id' => namespace.to_global_id.to_s
        )
      end
    end

    context 'when user is organization member but lacks namespace access' do
      let(:current_user) { create(:user) }

      before do
        create(:organization_user, organization: organization, user: current_user)
      end

      it 'returns nil' do
        execute_query

        expect(graphql_data_at(:custom_dashboard)).to be_nil
      end
    end

    context 'when user is not an organization member' do
      let(:current_user) { create(:user) }

      it 'returns nil' do
        execute_query

        expect(graphql_data_at(:custom_dashboard)).to be_nil
      end
    end
  end

  context 'when custom dashboard feature flag is disabled' do
    let_it_be(:dashboard) do
      create(:dashboard, :organization_scoped, organization: organization)
    end

    let(:current_user) { create(:user) }

    before do
      create(:organization_user, organization: organization, user: current_user)
      stub_feature_flags(custom_dashboard_storage: false)
    end

    it 'returns nil' do
      execute_query

      expect(graphql_data_at(:custom_dashboard)).to be_nil
    end
  end

  context 'when dashboard does not exist' do
    let(:current_user) { create(:user) }

    let(:query) do
      graphql_query_for(
        :custom_dashboard,
        { id: "gid://gitlab/Analytics::CustomDashboards::Dashboard/#{non_existing_record_id}" },
        'id name'
      )
    end

    before do
      create(:organization_user, organization: organization, user: current_user)
    end

    it 'returns nil' do
      execute_query

      expect(graphql_data_at(:custom_dashboard)).to be_nil
    end
  end
end

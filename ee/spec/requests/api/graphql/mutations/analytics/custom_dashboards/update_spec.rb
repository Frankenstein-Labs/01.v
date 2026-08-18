# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a custom dashboard', :without_current_organization, feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:namespace, freeze: false) { create(:group, organization: organization) }

  let_it_be(:dashboard) do
    create(
      :dashboard,
      organization: organization,
      namespace: namespace,
      created_by: user,
      name: 'Original Name',
      description: 'Original Description',
      config: {
        version: '2',
        title: 'Original Dashboard',
        panels: []
      }
    )
  end

  let(:new_config) do
    {
      title: 'Updated Dashboard',
      panels: [
        {
          title: 'New Panel',
          visualization: 'line_chart',
          grid_attributes: { width: 6, height: 3 }
        }
      ]
    }
  end

  let(:expected_persisted_config) do
    {
      'version' => '2',
      'title' => 'Updated Dashboard',
      'panels' => [
        {
          'title' => 'New Panel',
          'visualization' => 'line_chart',
          'gridAttributes' => { 'width' => 6, 'height' => 3 }
        }
      ]
    }
  end

  let(:variables) do
    {
      id: dashboard.to_global_id.to_s,
      name: 'Updated Name',
      description: 'Updated Description',
      config: new_config
    }
  end

  let(:mutation) do
    graphql_mutation(
      :update_custom_dashboard,
      variables,
      <<~QL
        dashboard {
          id
          name
          description
          config
          updatedBy {
            id
            username
          }
        }
        errors
      QL
    )
  end

  let(:mutation_response) { graphql_mutation_response(:update_custom_dashboard) }

  before do
    stub_feature_flags(custom_dashboard_storage: true)
  end

  context 'with granular token authorization' do
    before do
      create(:organization_user, organization: organization, user: user)
      user.update!(organization: organization)
      create(:group_member, :developer, group: namespace, user: user)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_custom_dashboard do
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:update_custom_dashboard, variables, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when user can update dashboard' do
    before_all do
      create(:organization_user, organization: organization, user: user)
      user.update!(organization: organization)
      create(:group_member, :developer, group: namespace, user: user)
    end

    it 'updates the dashboard' do
      expect do
        post_graphql_mutation(mutation, current_user: user)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['dashboard']).to include(
        'id' => dashboard.to_global_id.to_s,
        'name' => 'Updated Name',
        'description' => 'Updated Description',
        'config' => expected_persisted_config
      )

      dashboard.reload
      expect(dashboard.name).to eq('Updated Name')
      expect(dashboard.description).to eq('Updated Description')
      expect(dashboard.config).to eq(expected_persisted_config)
      expect(dashboard.updated_by).to eq(user)
    end

    it 'updates only provided fields' do
      partial_variables = {
        id: dashboard.to_global_id.to_s,
        name: 'Only Name Changed'
      }

      partial_mutation = graphql_mutation(
        :update_custom_dashboard,
        partial_variables,
        'dashboard { name description } errors'
      )

      post_graphql_mutation(partial_mutation, current_user: user)

      expect(mutation_response['dashboard']).to include(
        'name' => 'Only Name Changed',
        'description' => 'Original Description'
      )

      dashboard.reload
      expect(dashboard.name).to eq('Only Name Changed')
      expect(dashboard.description).to eq('Original Description')
    end

    context 'when config is missing required fields' do
      let(:variables) do
        {
          id: dashboard.to_global_id.to_s,
          config: { title: 'No panels dashboard' }
        }
      end

      it 'returns a GraphQL argument error' do
        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_include(/was provided invalid value/i)
      end
    end

    context 'when a panel visualization is a JSON config object' do
      let(:visualization_config) do
        {
          version: 1,
          type: 'LineChart',
          options: { xAxis: { name: 'Time', type: 'time' } },
          data: { type: 'glql', query: { glql: 'type = Issue' } }
        }
      end

      let(:new_config) do
        {
          title: 'Updated Dashboard',
          panels: [
            {
              title: 'GLQL Panel',
              visualizationConfig: visualization_config,
              grid_attributes: { width: 6, height: 3 }
            }
          ]
        }
      end

      let(:expected_persisted_config) do
        {
          'version' => '2',
          'title' => 'Updated Dashboard',
          'panels' => [
            {
              'title' => 'GLQL Panel',
              'visualization' => {
                'version' => 1,
                'type' => 'LineChart',
                'options' => { 'xAxis' => { 'name' => 'Time', 'type' => 'time' } },
                'data' => { 'type' => 'glql', 'query' => { 'glql' => 'type = Issue' } }
              },
              'gridAttributes' => { 'width' => 6, 'height' => 3 }
            }
          ]
        }
      end

      it 'persists the JSON visualization config object' do
        post_graphql_mutation(mutation, current_user: user)

        expect(mutation_response['errors']).to be_empty
        expect(dashboard.reload.config).to eq(expected_persisted_config)
      end
    end

    context 'when validating panel visualizations' do
      let(:new_config) { { title: 'Updated Dashboard', panels: panels } }

      it_behaves_like 'a custom dashboard mutation validating panel visualizations'
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(custom_dashboard_storage: false)
      end

      it 'returns an authorization error' do
        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
      end
    end
  end

  context 'when user is dashboard creator but only has reporter access' do
    let_it_be(:creator) { create(:user, organization: organization) }
    let_it_be(:dashboard_by_creator) do
      create(
        :dashboard,
        organization: organization,
        namespace: namespace,
        created_by: creator
      )
    end

    before_all do
      create(:group_member, :reporter, group: namespace, user: creator)
    end

    it 'allows the creator to update their dashboard' do
      update_mutation = graphql_mutation(
        :update_custom_dashboard,
        { id: dashboard_by_creator.to_global_id.to_s, name: 'Updated by Creator' },
        'dashboard { name } errors'
      )

      post_graphql_mutation(update_mutation, current_user: creator)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['dashboard']['name']).to eq('Updated by Creator')
    end
  end

  context 'when user is organization member but lacks namespace access' do
    let_it_be(:unauthorized_user) { create(:user, organization: organization) }

    it 'returns an authorization error' do
      post_graphql_mutation(mutation, current_user: unauthorized_user)

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end

  context 'when user is not organization member' do
    let_it_be(:unauthorized_user) { create(:user) }

    it 'returns an authorization error' do
      post_graphql_mutation(mutation, current_user: unauthorized_user)

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end

  context 'when dashboard does not exist' do
    let(:variables) do
      {
        id: "gid://gitlab/Analytics::CustomDashboards::Dashboard/#{non_existing_record_id}",
        name: 'Updated Name'
      }
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: user)

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end
end

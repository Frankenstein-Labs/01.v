# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a custom dashboard', feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }

  let(:valid_config) do
    {
      title: "Quarterly Sales Dashboard",
      description: "Revenue performance tracking",
      panels: [
        {
          title: "Total Revenue",
          visualization: "number",
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    }
  end

  let(:variables) do
    {
      organizationId: GitlabSchema.id_from_object(organization).to_s,
      name: "Quarterly Sales",
      description: "Revenue performance KPIs",
      config: valid_config
    }
  end

  let(:mutation) do
    graphql_mutation(
      :create_custom_dashboard,
      variables,
      <<~QL
        dashboard {
          id
          name
          description
          config
          organization {
            id
          }
          createdBy {
            id
          }
        }
        errors
      QL
    )
  end

  let(:mutation_response) { graphql_mutation_response(:create_custom_dashboard) }

  before do
    stub_feature_flags(custom_dashboard_storage: true)
  end

  context 'with granular token authorization' do
    before do
      create(:organization_user, :owner, organization: organization, user: user)
      user.update!(organization: organization)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_custom_dashboard do
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:create_custom_dashboard, variables, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when user is organization owner' do
    before_all do
      create(:organization_user, :owner, organization: organization, user: user)
    end

    let(:expected_persisted_config) do
      {
        'title' => 'Quarterly Sales Dashboard',
        'description' => 'Revenue performance tracking',
        'version' => '2',
        'panels' => [
          {
            'title' => 'Total Revenue',
            'visualization' => 'number',
            'gridAttributes' => { 'width' => 4, 'height' => 2 }
          }
        ]
      }
    end

    it 'creates a dashboard with valid config' do
      expect do
        user.update!(organization: organization)
        post_graphql_mutation(mutation, current_user: user)
      end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

      dashboard = Analytics::CustomDashboards::Dashboard.last

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['dashboard']).to include(
        'name' => 'Quarterly Sales',
        'description' => 'Revenue performance KPIs'
      )
      expect(dashboard.organization).to eq(organization)
      expect(dashboard.created_by).to eq(user)
      expect(dashboard.config).to eq(expected_persisted_config)
    end

    context 'when organizationId is not provided' do
      let(:variables) do
        {
          name: "Quarterly Sales Fallback",
          description: "Revenue performance KPIs",
          config: valid_config
        }
      end

      it 'creates a dashboard using the current organization from context' do
        stub_current_organization(organization)

        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        expect(mutation_response['errors']).to be_empty
        expect(Analytics::CustomDashboards::Dashboard.last.organization).to eq(organization)
      end
    end

    context 'when neither organizationId nor any fallback is available' do
      let(:variables) do
        {
          name: "Quarterly Sales",
          description: "Revenue performance KPIs",
          config: valid_config
        }
      end

      before do
        allow_next_instance_of(Mutations::Analytics::CustomDashboards::Create) do |instance|
          allow(instance).to receive(:resolve_current_organization).and_return(nil)
        end
      end

      it 'returns a resource not available error' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect_graphql_errors_to_include(/Organization not found/i)
      end
    end

    context 'when dashboard with same name already exists in the same organization and namespace' do
      before do
        create(:dashboard, organization: organization, name: 'Quarterly Sales', namespace: nil)
      end

      it 'does not create a duplicate dashboard' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect(mutation_response['errors']).to be_present
        expect(mutation_response['dashboard']).to be_nil
      end
    end

    context 'when dashboard with same name exists in a different namespace' do
      let_it_be(:namespace) { create(:namespace) }

      before do
        create(:dashboard, organization: organization, name: 'Quarterly Sales', namespace: namespace)
        variables[:namespaceId] = GitlabSchema.id_from_object(create(:namespace)).to_s
      end

      it 'creates the dashboard successfully' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        expect(mutation_response['errors']).to be_empty
      end
    end

    context 'when config is missing required fields' do
      let(:variables) { super().merge(config: { title: "No panels dashboard" }) }

      it 'returns a GraphQL argument error' do
        post_graphql_mutation(mutation, current_user: user)

        expect_graphql_errors_to_include(/was provided invalid value/i)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(custom_dashboard_storage: false)
      end

      it 'returns an authorization error' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.not_to change { Analytics::CustomDashboards::Dashboard.count }

        expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
      end
    end

    context 'when namespace is provided' do
      let_it_be(:namespace) { create(:namespace) }

      before do
        variables[:namespaceId] = GitlabSchema.id_from_object(namespace).to_s
      end

      it 'creates a dashboard scoped to the namespace' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        dashboard = Analytics::CustomDashboards::Dashboard.last

        expect(mutation_response['errors']).to be_empty
        expect(dashboard.namespace).to eq(namespace)
        expect(dashboard.organization).to eq(organization)
      end
    end

    context 'when namespace_id is invalid' do
      before do
        variables[:namespaceId] = "gid://gitlab/Namespace/#{non_existing_record_id}"
      end

      it 'creates dashboard without namespace association' do
        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        dashboard = Analytics::CustomDashboards::Dashboard.last

        expect(mutation_response['errors']).to be_empty
        expect(dashboard.namespace).to be_nil
        expect(dashboard.organization).to eq(organization)
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

      let(:variables) do
        {
          organizationId: GitlabSchema.id_from_object(organization).to_s,
          name: "Inline Visualization",
          config: {
            title: "Inline Visualization Dashboard",
            panels: [
              {
                title: "GLQL Panel",
                visualizationConfig: visualization_config,
                gridAttributes: { width: 4, height: 2 }
              }
            ]
          }
        }
      end

      let(:expected_persisted_config) do
        {
          'title' => 'Inline Visualization Dashboard',
          'version' => '2',
          'panels' => [
            {
              'title' => 'GLQL Panel',
              'visualization' => {
                'version' => 1,
                'type' => 'LineChart',
                'options' => { 'xAxis' => { 'name' => 'Time', 'type' => 'time' } },
                'data' => { 'type' => 'glql', 'query' => { 'glql' => 'type = Issue' } }
              },
              'gridAttributes' => { 'width' => 4, 'height' => 2 }
            }
          ]
        }
      end

      it 'persists the JSON visualization config object' do
        user.update!(organization: organization)

        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        expect(mutation_response['errors']).to be_empty
        expect(Analytics::CustomDashboards::Dashboard.last.config).to eq(expected_persisted_config)
      end
    end

    context 'when validating panel visualizations' do
      let(:variables) do
        {
          organizationId: GitlabSchema.id_from_object(organization).to_s,
          name: "Visualization Validation",
          config: { title: "Visualization Validation Dashboard", panels: panels }
        }
      end

      it_behaves_like 'a custom dashboard mutation validating panel visualizations'
    end

    context 'when config has deeply nested keys' do
      let(:variables) do
        {
          organizationId: GitlabSchema.id_from_object(organization).to_s,
          name: "Deep Nesting Test",
          config: {
            title: "Deep Nesting Dashboard",
            panels: [
              {
                title: "Pipeline Panel",
                visualization: "line_chart",
                grid_attributes: { width: 4, height: 2 },
                query_overrides: {
                  filters: {
                    include_metrics: ["deployment_frequency"],
                    exclude_metrics: ["lead_time"]
                  },
                  namespace: "my-group"
                }
              }
            ]
          }
        }
      end

      let(:expected_persisted_config) do
        {
          'title' => 'Deep Nesting Dashboard',
          'version' => '2',
          'panels' => [
            {
              'title' => 'Pipeline Panel',
              'visualization' => 'line_chart',
              'gridAttributes' => { 'width' => 4, 'height' => 2 },
              'queryOverrides' => {
                'filters' => {
                  'includeMetrics' => ['deployment_frequency'],
                  'excludeMetrics' => ['lead_time']
                },
                'namespace' => 'my-group'
              }
            }
          ]
        }
      end

      it 'persists camelCase keys at every nesting level' do
        user.update!(organization: organization)

        expect do
          post_graphql_mutation(mutation, current_user: user)
        end.to change { Analytics::CustomDashboards::Dashboard.count }.by(1)

        expect(mutation_response['errors']).to be_empty
        expect(Analytics::CustomDashboards::Dashboard.last.config).to eq(expected_persisted_config)
      end
    end
  end

  context 'when user is organization member but not owner' do
    let_it_be(:regular_member) { create(:user) }

    before_all do
      create(:organization_user, organization: organization, user: regular_member)
    end

    it 'returns an authorization error' do
      expect do
        post_graphql_mutation(mutation, current_user: regular_member)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end

  context 'when user is not organization member' do
    let_it_be(:unauthorized_user) { create(:user) }

    it 'returns an authorization error' do
      expect do
        post_graphql_mutation(mutation, current_user: unauthorized_user)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end
end

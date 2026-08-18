# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a custom dashboard', :without_current_organization, feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:namespace) { create(:group, organization: organization) }

  let_it_be_with_reload(:dashboard) do
    create(
      :dashboard,
      organization: organization,
      namespace: namespace,
      created_by: user,
      name: 'Dashboard to Delete'
    )
  end

  let(:variables) do
    {
      id: dashboard.to_global_id.to_s
    }
  end

  let(:mutation) do
    graphql_mutation(
      :delete_custom_dashboard,
      variables,
      <<~QL
        dashboard {
          id
          name
        }
        errors
      QL
    )
  end

  let(:mutation_response) { graphql_mutation_response(:delete_custom_dashboard) }

  before do
    stub_feature_flags(custom_dashboard_storage: true)
  end

  context 'with granular token authorization' do
    before do
      create(:organization_user, organization: organization, user: user)
      user.update!(organization: organization)
      create(:group_member, :developer, group: namespace, user: user)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_custom_dashboard do
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:delete_custom_dashboard, variables, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when user can delete dashboard' do
    before_all do
      create(:organization_user, organization: organization, user: user)
      user.update!(organization: organization)
      create(:group_member, :developer, group: namespace, user: user)
    end

    it 'deletes the dashboard' do
      expect do
        post_graphql_mutation(mutation, current_user: user)
      end.to change { Analytics::CustomDashboards::Dashboard.count }.by(-1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['dashboard']).to include(
        'id' => dashboard.to_global_id.to_s,
        'name' => 'Dashboard to Delete'
      )

      expect(Analytics::CustomDashboards::Dashboard.find_by(id: dashboard.id)).to be_nil
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
  end

  context 'when user is dashboard creator but only has reporter access' do
    let_it_be(:creator) { create(:user, organization: organization) }
    let_it_be_with_reload(:dashboard_by_creator) do
      create(
        :dashboard,
        organization: organization,
        namespace: namespace,
        created_by: creator,
        name: 'Creator Dashboard'
      )
    end

    before_all do
      create(:group_member, :reporter, group: namespace, user: creator)
    end

    it 'allows the creator to delete their dashboard' do
      delete_mutation = graphql_mutation(
        :delete_custom_dashboard,
        { id: dashboard_by_creator.to_global_id.to_s },
        'dashboard { name } errors'
      )

      expect do
        post_graphql_mutation(delete_mutation, current_user: creator)
      end.to change { Analytics::CustomDashboards::Dashboard.count }.by(-1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['dashboard']['name']).to eq('Creator Dashboard')
    end
  end

  context 'when user is organization member but lacks namespace access' do
    let_it_be_with_reload(:unauthorized_user) { create(:user) }

    before_all do
      create(:organization_user, organization: organization, user: unauthorized_user)
      unauthorized_user.update!(organization: organization)
    end

    it 'returns an authorization error' do
      expect do
        post_graphql_mutation(mutation, current_user: unauthorized_user)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end

  context 'when user is not organization member' do
    let_it_be_with_reload(:unauthorized_user) { create(:user) }

    it 'returns an authorization error' do
      expect do
        post_graphql_mutation(mutation, current_user: unauthorized_user)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end

  context 'when dashboard does not exist' do
    let(:variables) do
      {
        id: "gid://gitlab/Analytics::CustomDashboards::Dashboard/#{non_existing_record_id}"
      }
    end

    it 'returns an error' do
      expect do
        post_graphql_mutation(mutation, current_user: user)
      end.not_to change { Analytics::CustomDashboards::Dashboard.count }

      expect_graphql_errors_to_include(/does not exist or you don't have permission/i)
    end
  end
end

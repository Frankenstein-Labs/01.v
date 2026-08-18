# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query LDAP admin links', feature_category: :permissions do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }

  let_it_be(:admin_member_role) { create(:member_role, :admin, name: 'Admin role') }
  let_it_be(:ldap_admin_link) { create(:ldap_admin_role_link, :skip_validate, member_role: admin_member_role) }

  let(:arguments) { {} }
  let(:current_user) { admin }

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        provider {
          id
          label
        }
        filter
        cn
        adminMemberRole {
          name
        }
        syncStatus
        syncStartedAt
        syncEndedAt
        lastSuccessfulSyncAt
        syncError
      }
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('ldap_admin_role_links', arguments, fields)
  end

  subject(:ldap_admin_role_links) { graphql_data['ldapAdminRoleLinks'] }

  context 'when custom roles licensed feature is available' do
    let_it_be(:ldap_server_config) do
      Gitlab::Configs.build_options(provider_name: ldap_admin_link.provider, label: 'LDAP Provider')
    end

    before do
      allow(::Gitlab::Auth::Ldap::Config).to receive_messages(enabled?: true, available_servers: [ldap_server_config])

      stub_licensed_features(custom_roles: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :read_ldap_admin_role_link do
      let(:user) { admin }
      let(:boundary_object) { :instance }
      let(:query) { graphql_query_for('ldap_admin_role_links', arguments, 'nodes { id cn filter }') }
      let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    end

    context 'when querying ldap admin role links' do
      before do
        post_graphql(query, current_user: current_user)
      end

      it_behaves_like 'a working graphql query'

      it 'returns all ldap admin links' do
        expect(ldap_admin_role_links['nodes']).to eq([{
          'id' => ldap_admin_link.to_global_id.to_s,
          'provider' => { 'id' => ldap_server_config.provider_name, 'label' => ldap_server_config.label },
          'filter' => nil,
          'cn' => 'group1',
          'adminMemberRole' => { 'name' => 'Admin role' },
          'syncStatus' => 'NEVER_SYNCED',
          'syncStartedAt' => nil,
          'syncEndedAt' => nil,
          'lastSuccessfulSyncAt' => nil,
          'syncError' => nil
        }])
      end
    end
  end

  context 'when custom roles licensed feature is unavailable' do
    before do
      stub_licensed_features(custom_roles: false)

      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is not admin' do
    let(:current_user) { create(:user) }

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end
end

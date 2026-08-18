# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'synchronizing LDAP admin roles', feature_category: :permissions do
  include GraphqlHelpers

  let(:fields) do
    <<~FIELDS
      success
      errors
    FIELDS
  end

  let(:mutation) { graphql_mutation(:admin_roles_ldap_sync, {}, fields) }

  subject(:sync_ldap) { graphql_mutation_response(:admin_roles_ldap_sync) }

  it_behaves_like 'authorizing granular token permissions for GraphQL', :create_ldap_admin_role_link do
    let(:user) { create(:admin) }
    let(:boundary_object) { :instance }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  context 'when current user can admin member roles' do
    let_it_be(:current_user) { create(:admin) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'enqueues the LDAP admin role worker without provider', :aggregate_failures do
      expect(Authz::LdapAdminRoleWorker).to receive(:perform_async)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(sync_ldap['success']).to be(true)
      expect(sync_ldap['errors']).to be_empty
    end
  end

  context 'when current user cannot manage LDAP admin links' do
    let_it_be(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroying an LDAP admin role link', feature_category: :permissions do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:ldap_admin_role_link) { create(:ldap_admin_role_link, :skip_validate, organization_id: organization.id) }

  let(:input) { { id: GitlabSchema.id_from_object(ldap_admin_role_link).to_s } }
  let(:mutation) { graphql_mutation(:ldap_admin_role_link_destroy, input) }

  subject(:mutation_result) { graphql_mutation_response(:ldap_admin_role_link_destroy) }

  shared_examples 'returns error' do |error|
    specify do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_result['errors']).to eq([error])
    end
  end

  context 'when custom roles feature is unavailable' do
    before do
      stub_licensed_features(custom_roles: false)
    end

    it_behaves_like 'returns error', 'custom_roles licensed feature must be available'
  end

  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_ldap_admin_role_link do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:ldap_admin_role_link_destroy, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'returns a success response', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to be_nil
      expect(mutation_result['errors']).to be_empty
      expect(
        graphql_data_at(:ldap_admin_role_link_destroy, :ldap_admin_role_link)
      ).to match(
        a_graphql_entity_for(
          ldap_admin_role_link,
          :cn, :filter,
          provider: { 'id' => ldap_admin_role_link.provider, 'label' => nil }
        )
      )
    end

    it 'destroys the target LDAP admin role link' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { Authz::LdapAdminRoleLink.find_by_id(ldap_admin_role_link.id) }.to(nil)
    end
  end

  context 'when current user is not an admin' do
    let_it_be(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when id argument does not match an existing LDAP admin role link record' do
    let(:input) { { id: "gid://gitlab/Authz::LdapAdminRoleLink/#{non_existing_record_iid}" } }

    it_behaves_like 'a mutation that returns a top-level access error'
  end
end

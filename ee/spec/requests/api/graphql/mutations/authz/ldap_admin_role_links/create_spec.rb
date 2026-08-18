# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'creating LDAP admin role link', feature_category: :permissions do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }

  let_it_be(:admin_member_role) { create(:member_role, :admin, name: 'Admin role') }

  let(:input) do
    {
      adminMemberRoleId: admin_member_role.to_global_id.to_s,
      provider: "ldap",
      cn: "cn"
    }
  end

  let(:fields) do
    <<~FIELDS
      errors
      ldapAdminRoleLink {
        provider {
          id
        }
        cn
        filter
        adminMemberRole {
          name
        }
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:ldap_admin_role_link_create, input, fields) }

  before do
    allow(::Gitlab::Auth::Ldap::Config).to receive_messages(providers: ['ldap'])
  end

  subject(:create_admin_link) { graphql_mutation_response(:ldap_admin_role_link_create) }

  context 'without the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: false)
    end

    it 'returns error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(create_admin_link['errors']).to eq([
        'custom_roles licensed feature must be available'
      ])
    end
  end

  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_ldap_admin_role_link do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:ldap_admin_role_link_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'returns success', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to be_nil

      expect(create_admin_link['errors']).to be_empty

      expect(create_admin_link['ldapAdminRoleLink']).to eq({
        'provider' => { 'id' => 'ldap' },
        'cn' => 'cn',
        'filter' => nil,
        'adminMemberRole' => { 'name' => 'Admin role' }
      })
    end

    it 'creates the member role', :aggregate_failures do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { Authz::LdapAdminRoleLink.count }.by(1)
    end

    context 'when member role provided is not an admin role' do
      let_it_be(:member_role) { create(:member_role, name: 'Standard role') }

      let(:input) do
        {
          adminMemberRoleId: member_role.to_global_id.to_s,
          provider: "ldap",
          cn: "cn"
        }
      end

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(create_admin_link['errors']).to eq([
          'Only admin custom roles can be assigned'
        ])
      end
    end

    context 'when member role id provided does not exist' do
      let(:input) do
        {
          adminMemberRoleId: "gid://gitlab/MemberRole/#{non_existing_record_iid}",
          provider: "ldap",
          cn: "cn"
        }
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when current user is not an admin' do
      let_it_be(:current_user) { create(:user) }

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when both cn and filter are provided' do
      let(:input) do
        {
          adminMemberRoleId: admin_member_role.to_global_id.to_s,
          provider: "ldap",
          cn: "cn",
          filter: "filter"
        }
      end

      it 'returns error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect_graphql_errors_to_include("One and only one of [cn, filter] arguments is required.")
      end
    end
  end
end

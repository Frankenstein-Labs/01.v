# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'updating admin member role', :enable_admin_mode, feature_category: :permissions do
  include GraphqlHelpers

  let_it_be(:member_role) { create(:member_role, :read_admin_users) }
  let_it_be_with_reload(:current_user) { create(:admin) }

  let(:name) { 'new name' }
  let(:description) { 'new description' }
  let(:permissions) { %w[READ_ADMIN_MONITORING READ_ADMIN_CICD] }

  let(:input) do
    { 'id' => member_role.to_global_id.to_s, 'name' => name, 'description' => description,
      'permissions' => permissions }
  end

  let(:fields) do
    <<~FIELDS
      errors
      memberRole {
        id
        name
        description
        enabledPermissions {
          nodes {
            value
          }
        }
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:member_role_admin_update, input, fields) }

  subject(:update_admin_member_role) { graphql_mutation_response(:member_role_admin_update) }

  context 'without the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_admin_member_role do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) do
        graphql_mutation(:member_role_admin_update,
          { 'id' => member_role.to_global_id.to_s, 'name' => 'new name', 'permissions' => permissions },
          'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    shared_examples 'updating custom role' do
      it 'returns success' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_errors).to be_nil

        expect(update_admin_member_role['memberRole']).to include('name' => 'new name')

        expect(update_admin_member_role['memberRole']).to include('description' => 'new description')

        expect(update_admin_member_role['memberRole']['enabledPermissions']['nodes'].flat_map(&:values))
          .to match_array(permissions)
      end

      it 'updates the member role' do
        post_graphql_mutation(mutation, current_user: current_user)

        member_role.reload

        expect(member_role.name).to eq('new name')
        expect(member_role.description).to eq('new description')
        expect(member_role.read_admin_monitoring).to be(true)
        expect(member_role.read_admin_cicd).to be(true)
        expect(member_role.read_admin_users).to be_nil
      end
    end

    context 'when on SaaS' do
      it_behaves_like 'updating custom role'
    end

    context 'when on self-managed' do
      it_behaves_like 'updating custom role'

      context 'when member role is not an admin role' do
        let(:member_role) { create(:member_role, :guest, :read_code, :instance) }

        it_behaves_like  'a mutation that returns top-level errors',
          errors: ['This mutation can only be used to update admin member roles']
      end

      context 'when current user is not an admin' do
        before do
          current_user.update!(admin: false)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'with missing arguments' do
        let(:input) { { 'id' => member_role.to_global_id.to_s } }

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ['The list of member_role attributes is empty']
      end
    end
  end
end

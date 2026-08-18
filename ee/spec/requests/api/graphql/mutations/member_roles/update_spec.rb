# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'updating member role', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:member_role) { create(:member_role, :read_code, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  let(:name) { 'new name' }
  let(:description) { 'new description' }
  let(:permissions) { %w[READ_VULNERABILITY ADMIN_VULNERABILITY] }

  let(:input) { { 'name' => name, 'description' => description, 'permissions' => permissions } }
  let(:mutation) { graphql_mutation(:memberRoleUpdate, input.merge('id' => member_role.to_global_id.to_s), fields) }
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

  subject(:update_member_role) { graphql_mutation_response(:member_role_update) }

  context 'without the custom roles feature', :saas do
    before do
      stub_licensed_features(custom_roles: false)
    end

    context 'with owner role' do
      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  context 'with the custom roles feature on self-managed', :enable_admin_mode do
    let_it_be(:instance_member_role) { create(:member_role, :instance) }
    let_it_be(:instance_admin) { create(:admin) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_member_role do
      let(:user) { instance_admin }
      let(:boundary_object) { :instance }
      let(:mutation) do
        graphql_mutation(:memberRoleUpdate, input.merge('id' => instance_member_role.to_global_id.to_s), 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'with the custom roles feature', :saas do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'with maintainer role' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'with owner role' do
      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_member_role do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:mutation) do
          graphql_mutation(:memberRoleUpdate, input.merge('id' => member_role.to_global_id.to_s), 'errors')
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'with valid arguments' do
        it 'returns success' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors).to be_nil

          expect(update_member_role['memberRole']).to include('name' => 'new name')

          expect(update_member_role['memberRole']).to include('description' => 'new description')

          expect(update_member_role['memberRole']['enabledPermissions']['nodes'].flat_map(&:values))
            .to match_array(permissions)
        end

        it 'updates the member role' do
          post_graphql_mutation(mutation, current_user: current_user)

          member_role.reload

          expect(member_role.name).to eq('new name')
          expect(member_role.description).to eq('new description')
          expect(member_role.read_vulnerability).to be(true)
          expect(member_role.admin_vulnerability).to be(true)
          expect(member_role.read_code).to be_nil
        end
      end

      context 'with invalid arguments' do
        let(:name) { nil }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(update_member_role['errors'].first).to include("Name can't be blank")
          expect(update_member_role['memberRole']).not_to be_nil
        end
      end

      context 'with missing arguments' do
        let(:input) { {} }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors).not_to be_empty
          expect(graphql_errors.first['message'])
            .to include("The list of member_role attributes is empty")
        end
      end
    end
  end
end

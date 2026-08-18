# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'deleting member role', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:member_role) { create(:member_role, :instance) }
  let_it_be_with_reload(:current_user) { create(:user) }

  let(:input) { { id: member_role.to_global_id.to_s } }

  let(:fields) do
    <<~FIELDS
      errors
      memberRole {
        id
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:member_role_delete, input, fields) }

  subject(:delete_member_role) { graphql_mutation_response(:member_role_delete) }

  context 'without the custom roles feature', :enable_admin_mode do
    before do
      stub_licensed_features(custom_roles: false)
    end

    context 'with owner role' do
      before_all do
        current_user.update!(admin: true)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end

  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when unauthorized' do
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'with a group-level member role', :saas do
      let_it_be(:member_role) { create(:member_role, namespace: group) }
      let_it_be(:group_owner) { create(:user) }

      before_all do
        group.add_owner(group_owner)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_member_role do
        let(:user) { group_owner }
        let(:boundary_object) { group }
        let(:mutation) { graphql_mutation(:member_role_delete, input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'with admin', :enable_admin_mode do
      before_all do
        current_user.update!(admin: true)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_member_role do
        let(:user) { current_user }
        let(:boundary_object) { :instance }
        let(:mutation) { graphql_mutation(:member_role_delete, input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'with valid arguments' do
        it 'returns success' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(delete_member_role).to be_present
          expect(delete_member_role['errors']).to be_empty
          expect(delete_member_role['memberRole']['id']).to eq(member_role.to_global_id.to_s)
          expect(graphql_errors).to be_nil
        end

        it 'deletes the member role' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { MemberRole.count }.by(-1)
        end
      end

      context 'with invalid arguments' do
        let(:input) { { id: 'gid://gitlab/MemberRole/-1' } }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'with missing arguments' do
        let(:input) { {} }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include(/was provided invalid value for id/)
        end
      end

      context 'when member role is an admin role' do
        let_it_be(:member_role) { create(:member_role, :read_admin_users) }
        let_it_be(:current_user) { create(:admin) }

        it_behaves_like  'a mutation that returns top-level errors',
          errors: ['This mutation can only be used to delete standard member roles']
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'deleting admin member role', :enable_admin_mode, feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:member_role) { create(:member_role, :read_admin_users) }
  let_it_be_with_refind(:current_user) { create(:admin) }

  let(:input) { { id: member_role.to_global_id.to_s } }

  let(:fields) do
    <<~FIELDS
      errors
      memberRole {
        id
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:member_role_admin_delete, input, fields) }

  subject(:delete_admin_member_role) { graphql_mutation_response(:member_role_admin_delete) }

  shared_examples 'a mutation that deletes a member role' do
    it 'returns success' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(delete_admin_member_role).to be_present
      expect(delete_admin_member_role['errors']).to be_empty
      expect(delete_admin_member_role['memberRole']['id']).to eq(member_role.to_global_id.to_s)
      expect(graphql_errors).to be_nil
    end

    it 'deletes the member role' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { MemberRole.count }.by(-1)
    end
  end

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

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_admin_member_role do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:member_role_admin_delete, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it_behaves_like 'a mutation that deletes a member role'
    end

    context 'when on self-managed' do
      it_behaves_like 'a mutation that deletes a member role'

      context 'when current user is not an admin' do
        before do
          current_user.update!(admin: false)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
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

      context 'when member role is not an admin role' do
        let(:member_role) { create(:member_role, :guest, :read_code, :instance) }

        it_behaves_like  'a mutation that returns top-level errors',
          errors: ['This mutation is restricted to deleting admin roles only']
      end

      context 'when member role is already assigned to a user' do
        let_it_be(:user_member_role) { create(:user_member_role, member_role: member_role) }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(delete_admin_member_role['errors']).to eq([
            'Admin role is assigned to one or more users. Remove role from all users, then delete role.'
          ])
        end
      end
    end
  end
end

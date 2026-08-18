# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Assigning a user to a member role', feature_category: :permissions do
  include GraphqlHelpers

  let_it_be_with_reload(:current_user) { create(:admin) }

  let_it_be(:user) { create(:user) }
  let_it_be(:member_role) { create(:member_role, :admin) }
  let_it_be(:regular_member_role) { create(:member_role) }

  let(:member_role_param) { member_role }

  let(:user_global_id) { GitlabSchema.id_from_object(user).to_s }
  let(:member_role_global_id) { GitlabSchema.id_from_object(member_role_param).to_s }

  let(:input) do
    {
      user_id: user_global_id,
      member_role_id: member_role_global_id
    }
  end

  let(:fields) do
    <<~FIELDS
      errors
      userMemberRole {
        id
        user {
          id
        }
        memberRole {
          id
        }
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:member_role_to_user_assign, input, fields) }

  subject(:assign_member_role) { graphql_mutation_response(:member_role_to_user_assign) }

  def mutation_response
    graphql_mutation_response('memberRoleToUserAssign')
  end

  before do
    stub_licensed_features(custom_roles: true)
  end

  shared_examples 'custom role assignment' do
    it 'returns correct response', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: current_user)

      response_object = mutation_response['userMemberRole']

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(response_object['user']['id']).to eq(user_global_id)
      expect(response_object['memberRole']['id']).to eq(member_role_global_id)
    end

    it 'creates a new user member role' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Users::UserMemberRole.count }.by(1)
    end
  end

  context 'when current user is not an admin', :enable_admin_mode do
    before do
      current_user.update!(admin: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error',
      errors: ["The resource that you are attempting to access does not exist or " \
        "you don't have permission to perform this action"]
  end

  context 'when current user is an admin', :enable_admin_mode do
    context 'when on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it_behaves_like 'custom role assignment'
    end

    context 'with granular token authorization' do
      let_it_be(:assignee) { create(:user) }

      it_behaves_like 'authorizing granular token permissions for GraphQL', :assign_member_role do
        let(:user) { current_user }
        let(:boundary_object) { :instance }
        let(:mutation) do
          graphql_mutation(
            :member_role_to_user_assign,
            { user_id: GitlabSchema.id_from_object(assignee).to_s, member_role_id: member_role_global_id },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'when on self-managed' do
      context 'with valid member_role_id' do
        it_behaves_like 'custom role assignment'
      end

      context 'when the provided custom role is not an admin role' do
        let(:member_role_param) { regular_member_role }

        it 'returns error in the response', :aggregate_failures do
          post_graphql_mutation(mutation, current_user: current_user)

          response_object = mutation_response['userMemberRole']

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors'])
            .to eq(['Only admin custom roles can be assigned directly to a user.'])
          expect(response_object).to be_nil
        end
      end

      context 'with invalid user_id' do
        let(:user_global_id) { "gid://gitlab/User/#{non_existing_record_id}" }

        it_behaves_like 'a mutation that returns a top-level access error',
          errors: ["The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"]
      end

      context 'with invalid member_role_id' do
        let(:member_role_global_id) { "gid://gitlab/MemberRole/#{non_existing_record_id}" }

        it_behaves_like 'a mutation that returns a top-level access error',
          errors: ["The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"]
      end

      context 'with member_role_id nil' do
        let(:member_role_global_id) { nil }

        context 'when a user does not have any admin member role assigned' do
          it 'returns an error message in response', :aggregate_failures do
            post_graphql_mutation(mutation, current_user: current_user)

            response_object = mutation_response['userMemberRole']

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to be_empty

            expect(response_object).to be_nil
          end

          it 'does not delete the user member role' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .not_to change { ::Users::UserMemberRole.count }
          end
        end

        context 'when a user has an admin member role assigned' do
          let_it_be(:user_member_role) { create(:user_member_role, member_role: member_role, user: user) }

          it 'returns correct response', :aggregate_failures do
            post_graphql_mutation(mutation, current_user: current_user)

            response_object = mutation_response['userMemberRole']

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to be_empty

            expect(response_object).to be_nil
          end

          it 'deletes the user member role' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { ::Users::UserMemberRole.count }.by(-1)
          end
        end
      end
    end

    context 'without custom roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error',
        errors: ["The resource that you are attempting to access does not exist or " \
          "you don't have permission to perform this action"]
    end
  end
end

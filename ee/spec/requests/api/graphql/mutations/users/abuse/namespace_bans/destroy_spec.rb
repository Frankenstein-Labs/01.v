# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Removing a namespace ban', feature_category: :user_profile do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, owners: user) }
  let_it_be(:namespace_ban) { create(:namespace_ban, namespace: namespace) }

  let(:mutation) do
    variables = {
      id: GitlabSchema.id_from_object(namespace_ban).to_s
    }
    graphql_mutation(:namespace_ban_destroy, variables) do
      <<~QL
         clientMutationId
         errors
         namespaceBan {
           id
           user {
            id
           }
           namespace {
            id
           }
         }
      QL
    end
  end

  def mutation_response
    graphql_mutation_response(:namespace_ban_destroy)
  end

  it 'removes the ban' do
    post_graphql_mutation(mutation, current_user: user)

    namespace_ban_response = mutation_response['namespaceBan']

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['errors']).to be_empty
    expect(namespace_ban_response['id']).to eq(GitlabSchema.id_from_object(namespace_ban).to_s)
    expect(namespace_ban_response['user']['id']).to eq(GitlabSchema.id_from_object(namespace_ban.user).to_s)
    expect(namespace_ban_response['namespace']['id']).to eq(GitlabSchema.id_from_object(namespace).to_s)

    expect { namespace_ban.reload }.to raise_error ActiveRecord::RecordNotFound
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_namespace_ban do
    let(:boundary_object) { namespace }
    let(:mutation) do
      graphql_mutation(
        :namespace_ban_destroy,
        { id: GitlabSchema.id_from_object(namespace_ban).to_s },
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  context 'when resource is not accessible to the user' do
    before_all do
      namespace.add_maintainer(user)
    end

    it 'returns an error message' do
      post_graphql_mutation(mutation, current_user: user)

      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist or you don't "\
                                       'have permission to perform this action')
    end
  end
end

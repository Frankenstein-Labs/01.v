# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Unarchive a custom field', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }

  let(:custom_field) { create(:custom_field, :archived, namespace: group) }

  let(:mutation) { graphql_mutation(:custom_field_unarchive, id: custom_field.to_global_id.to_s) }
  let(:mutation_response) { graphql_mutation_response(:custom_field_unarchive) }

  before do
    stub_licensed_features(custom_fields: true)
  end

  it 'unarchive the custom field' do
    post_graphql_mutation(mutation, current_user: maintainer)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    expect(mutation_response['customField']).to match(
      a_hash_including(
        'id' => custom_field.to_global_id.to_s,
        'active' => true
      )
    )
  end

  context 'when field is already active' do
    let(:custom_field) { create(:custom_field, namespace: group) }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: maintainer)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to include(
        Issuables::CustomFields::UnarchiveService::AlreadyActiveError.message
      )
    end
  end

  context 'when user does not have access' do
    it 'returns an error' do
      guest = create(:user, guest_of: group)

      post_graphql_mutation(mutation, current_user: guest)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end
end

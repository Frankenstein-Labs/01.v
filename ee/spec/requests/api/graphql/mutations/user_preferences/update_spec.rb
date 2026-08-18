# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::UserPreferences::Update, feature_category: :user_profile do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:orbit_mutation_query) do
    <<~GQL
      mutation($input: UserPreferencesUpdateInput!) {
        userPreferencesUpdate(input: $input) {
          userPreferences { orbitSettings }
          errors
        }
      }
    GQL
  end

  def post_orbit_mutation(orbit_settings_value, user: current_user)
    post_graphql(
      orbit_mutation_query,
      current_user: user,
      variables: { input: { orbitSettings: orbit_settings_value } }.to_json
    )
  end

  describe 'orbit_settings validation', feature_category: :duo_agent_platform do
    context 'when orbit_settings has invalid schema' do
      it 'returns validation error' do
        post_orbit_mutation({ 'invalid_key' => 'value' })

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_data.dig('userPreferencesUpdate', 'errors'))
          .to include('Orbit settings must be a valid json schema')
        expect(graphql_data.dig('userPreferencesUpdate', 'userPreferences')).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.openbaoHealth', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:query) do
    <<~GRAPHQL
      query {
        openbaoHealth
      }
    GRAPHQL
  end

  context 'when user is not authenticated' do
    it 'returns an error' do
      post_graphql(query)

      expect(graphql_errors).to include(
        a_hash_including(
          'message' => 'The resource that you are attempting to access does not exist or ' \
            'you don\'t have permission to perform this action'
        )
      )
    end
  end

  context 'when user is authenticated' do
    before do
      sign_in(current_user)
    end

    context 'when OpenBao is available' do
      before do
        allow_next_instance_of(SecretsManagement::SecretsManagerClient) do |instance|
          allow(instance).to receive(:server_available?).and_return(true)
        end
      end

      it 'returns true' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['openbaoHealth']).to be true
      end
    end

    context 'when OpenBao is not available' do
      before do
        allow_next_instance_of(SecretsManagement::SecretsManagerClient) do |instance|
          allow(instance).to receive(:server_available?).and_return(false)
        end
      end

      it 'returns false' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['openbaoHealth']).to be false
      end
    end
  end
end

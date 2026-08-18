# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'user', feature_category: :user_profile do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  describe 'duoStatus field' do
    let(:query) do
      graphql_query_for(
        'user',
        { username: user.username.upcase },
        <<~QUERY
          username
          duoStatus {
            disabled
            disabledReason
          }
        QUERY
      )
    end

    context 'with a human user' do
      let(:user) { current_user }

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data.dig('user', 'username')).to eq(user.username)
        expect(graphql_data.dig('user', 'duoStatus')).to be_nil
      end
    end

    context 'with a regular service account user' do
      let(:user) { create(:user, :service_account, composite_identity_enforced: false) }

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data.dig('user', 'username')).to eq(user.username)
        expect(graphql_data.dig('user', 'duoStatus')).to be_nil
      end
    end

    context 'with a composite identity user' do
      let(:user) { create(:user, :service_account, composite_identity_enforced: true) }

      before do
        allow_next_instance_of(
          ::Ai::UsageQuotaService,
          user: current_user
        ) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.error(reason: :usage_quota_exceeded, message: 'No credits available')
          )
        end
      end

      it 'returns the Duo status' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data.dig('user', 'username')).to eq(user.username)
        expect(graphql_data.dig('user', 'duoStatus')).to match(
          'disabled' => true,
          'disabledReason' => 'Unavailable - no credits'
        )
      end
    end
  end
end

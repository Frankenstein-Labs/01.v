# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query', :saas, feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:target_namespace) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:subscription_history) { create(:gitlab_subscription_history, namespace: target_namespace) }

  describe '.namespace' do
    subject(:namespace_query) { post_graphql(query, current_user: current_user) }

    let(:current_user) { user }
    let(:query_fields) { all_graphql_fields_for('Namespace') }
    let(:query_result) { graphql_data['namespace'] }
    let(:query) do
      graphql_query_for(:namespace, { 'fullPath' => target_namespace.full_path }, query_fields)
    end

    before do
      namespace_query
    end

    describe 'subscription_history' do
      let(:query_fields) do
        <<-GQL
        subscriptionHistory {
          nodes {
            createdAt
            startDate
            endDate
            seats
            seatsInUse
            maxSeatsUsed
            changeType
          }
        }
        GQL
      end

      it 'does not return any data if user is not an owner' do
        expect(query_result["subscriptionHistory"]["nodes"].first).to be_nil
      end

      context 'when user is a namespace owner' do
        before_all do
          target_namespace.add_owner(user)
        end

        it 'fetches the expected subscription_history data' do
          expect(query_result["subscriptionHistory"]["nodes"].first).to eq({
            'createdAt' => subscription_history.created_at.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'startDate' => subscription_history.start_date,
            'endDate' => subscription_history.end_date,
            'seats' => subscription_history.seats,
            'seatsInUse' => subscription_history.seats_in_use,
            'maxSeatsUsed' => subscription_history.max_seats_used,
            'changeType' => subscription_history.change_type
          })
        end
      end
    end

    describe 'plan field' do
      context 'when user has admin ability' do
        before_all do
          target_namespace.add_owner(user)
        end

        it 'returns plan field' do
          expect(query_result['plan']).to include({
            'isPaid' => true,
            'name' => 'premium',
            'title' => 'Premium'
          })
        end
      end

      context 'when user does not have admin ability' do
        before_all do
          target_namespace.add_developer(user)
        end

        it 'returns plan field as nil' do
          expect(query_result['plan']).to be_nil
        end
      end
    end
  end
end

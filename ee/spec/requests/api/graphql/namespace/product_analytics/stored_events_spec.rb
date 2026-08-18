# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a limit of stored events a namespace is permitted',
  feature_category: :product_analytics do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

  let(:path) { %i[namespace product_analytics_stored_events_limit] }

  let!(:query) do
    graphql_query_for(
      :namespace, { full_path: namespace.full_path }, :product_analytics_stored_events_limit
    )
  end

  before do
    stub_feature_flags(product_analytics_billing_override: false)
  end

  context 'when product_analytics_billing flag is disabled' do
    before do
      stub_feature_flags(product_analytics_billing: false)
    end

    it 'returns null' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(*path)).to be_nil
    end
  end

  context 'when product_analytics_billing flag is enabled' do
    context 'when current user is a namespace owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      context 'when no add-on has been purchased' do
        it 'returns zero' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(*path)).to eq(0)
        end
      end

      context 'when an add-on has been purchased' do
        before do
          create(
            :gitlab_subscription_add_on_purchase,
            :product_analytics,
            namespace: namespace,
            add_on: add_on,
            quantity: 5
          )
        end

        it 'returns the correct limit' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(*path)).to eq(5_000_000)
        end
      end
    end

    context 'when current user is a namespace maintainer' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      context 'when no add-on has been purchased' do
        it 'returns zero' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(*path)).to eq(0)
        end
      end

      context 'when an add-on has been purchased' do
        before do
          create(
            :gitlab_subscription_add_on_purchase,
            :product_analytics,
            namespace: namespace,
            add_on: add_on,
            quantity: 5
          )
        end

        it 'returns the correct limit' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(*path)).to eq(5_000_000)
        end
      end
    end

    context 'when current user is a namespace developer' do
      before_all do
        namespace.add_developer(current_user)
      end

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).to be_nil
      end
    end

    context 'when current user is a namespace guest' do
      before_all do
        namespace.add_guest(current_user)
      end

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).to be_nil
      end
    end

    context 'when current user does not belong to namespace' do
      let_it_be(:current_user) { create(:user) }

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).to be_nil
      end
    end
  end
end

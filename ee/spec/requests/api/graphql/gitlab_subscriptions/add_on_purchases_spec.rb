# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.addOnPurchases', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let(:fields) { 'id purchasedQuantity assignedQuantity name' }
  let(:expected_response) do
    [
      {
        'id' => "gid://gitlab/GitlabSubscriptions::AddOnPurchase/#{add_on_purchase_1.id}",
        'purchasedQuantity' => 1,
        'assignedQuantity' => 0,
        'name' => 'CODE_SUGGESTIONS'
      },
      {
        'id' => "gid://gitlab/GitlabSubscriptions::AddOnPurchase/#{add_on_purchase_2.id}",
        'purchasedQuantity' => 1,
        'assignedQuantity' => 0,
        'name' => 'DUO_ENTERPRISE'
      }
    ]
  end

  shared_examples 'avoids N+1 queries' do
    let(:send_query) { post_graphql(query, current_user: current_user) }

    it 'avoids N+1 queries' do
      control_count = ActiveRecord::QueryRecorder.new { send_query }

      create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace_id: namespace_id)

      expect { send_query }.not_to exceed_query_limit(control_count)
    end
  end

  shared_examples 'an empty response' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['addOnPurchases']).to be_empty
    end

    include_examples 'avoids N+1 queries'
  end

  shared_examples 'a successful response' do
    it 'returns expected response' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data['addOnPurchases']).to match_array(expected_response)
    end

    include_examples 'avoids N+1 queries'
  end

  context 'when namespace_id is not provided as argument' do
    let(:namespace_id) { nil }
    let(:query) { graphql_query_for(:addOnPurchases, {}, fields) }

    context 'when active purchases exist' do
      let!(:add_on_purchase_1) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :active, namespace_id: namespace_id)
      end

      let!(:add_on_purchase_2) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, namespace_id: namespace_id)
      end

      it_behaves_like 'a successful response'
    end

    context 'when active purchases do not exist' do
      before do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired, namespace_id: namespace_id)
      end

      it_behaves_like 'an empty response'
    end

    context 'when current_user is not an admin' do
      let(:current_user) { create(:user) }

      it_behaves_like 'an empty response'
    end
  end

  context 'when namespace_id is provided as an argument' do
    let_it_be(:group) { create(:group) }
    let_it_be(:owner) { create(:user) }
    let(:namespace_id) { group.id }
    let(:query) do
      graphql_query_for(
        :addOnPurchases, { namespace_id: global_id_of(group) },
        fields
      )
    end

    before_all do
      group.add_owner(owner)
    end

    context 'when active purchases exist' do
      let!(:add_on_purchase_1) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :active, namespace_id: namespace_id)
      end

      let!(:add_on_purchase_2) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, namespace_id: namespace_id)
      end

      it_behaves_like 'a successful response'
    end

    context 'when active purchases do not exist' do
      before do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired, namespace_id: namespace_id)
      end

      it_behaves_like 'an empty response'
    end

    context 'when current_user is not the owner of associated namespace' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_owner) { create(:user) }

      let(:current_user) { other_owner }

      before_all do
        other_group.add_owner(other_owner)
      end

      it_behaves_like 'an empty response'
    end
  end
end

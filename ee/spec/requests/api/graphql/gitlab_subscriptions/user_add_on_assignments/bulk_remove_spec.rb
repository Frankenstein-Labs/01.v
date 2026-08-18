# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UserAddOnAssignmentBulkRemove', feature_category: :seat_cost_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:assigned_user) { create(:user) }
  let_it_be(:assigned_user_2) { create(:user) }
  let(:user_id) { global_id_of(assigned_user) }
  let(:user2_id) { global_id_of(assigned_user_2) }

  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
  let(:add_on_purchase_id) { global_id_of(add_on_purchase) }

  let(:mutation) { graphql_mutation(:user_add_on_assignment_bulk_remove, input, requested_fields) }
  let(:mutation_response) { graphql_mutation_response(:user_add_on_assignment_bulk_remove) }
  let(:requested_fields) do
    <<-GQL
    errors
    addOnPurchase {
      id
      name
      purchasedQuantity
      assignedQuantity
    }
    users {
      edges {
        node {
          id
          name
          username
        }
      }
    }
    GQL
  end

  let(:input) do
    {
      user_ids: [user_id, user2_id],
      add_on_purchase_id: add_on_purchase_id
    }
  end

  shared_examples 'empty response' do
    it 'returns nil' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response).to be_nil
    end
  end

  shared_examples 'validates the query' do
    context 'when current_user is not owner or admin' do
      let_it_be(:namespace) { create(:group) }

      let(:current_user) { namespace.add_developer(create(:user)).user }

      it_behaves_like 'empty response'
    end

    context 'when add_on_purchase_id does not exist' do
      let(:add_on_purchase_id) do
        global_id_of(id: non_existing_record_id, model_name: '::GitlabSubscriptions::AddOnPurchase')
      end

      it_behaves_like 'empty response'
    end

    context 'when ad_on_purchase has expired' do
      before do
        add_on_purchase.update!(expires_on: 1.day.ago)
      end

      it_behaves_like 'empty response'
    end

    context 'when exceeding user unassignment limit' do
      let(:unassignment_limit) do
        Mutations::GitlabSubscriptions::UserAddOnAssignments::BulkRemove::MAX_USER_UNASSIGNMENT_LIMIT
      end

      let(:input) do
        {
          user_ids: (1..(unassignment_limit + 1)).map { |i| global_id_of(id: i, model_name: 'User') },
          add_on_purchase_id: add_on_purchase_id
        }
      end

      it_behaves_like 'empty response'
    end
  end

  context 'on Gitlab.com' do
    let_it_be(:namespace) { create(:group) }
    let_it_be_with_reload(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, quantity: 10, namespace: namespace, add_on: add_on)
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    before_all do
      namespace.add_owner(current_user)
      namespace.add_developer(assigned_user)
      namespace.add_developer(assigned_user_2)
    end

    it_behaves_like 'validates the query'

    context 'when an invalid user id is included' do
      let(:user_id) { global_id_of(create(:user)) }

      it 'returns expected errors' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response["errors"]).to include('NO_ASSIGNMENTS_FOUND')
        expect(mutation_response["addOnPurchase"]).to be_nil
        expect(mutation_response["users"]).to be_nil
      end
    end

    context 'with successful users unassignment' do
      let(:updated_add_on_purchase) do
        {
          "assignedQuantity" => 0,
          "id" => "gid://gitlab/GitlabSubscriptions::AddOnPurchase/#{add_on_purchase.id}",
          "purchasedQuantity" => 10,
          "name" => 'CODE_SUGGESTIONS'
        }
      end

      before_all do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: assigned_user)
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: assigned_user_2)
      end

      it 'unassigns users successfully' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response["errors"]).to eq([])
        expect(mutation_response["addOnPurchase"]).to eq(updated_add_on_purchase)
        expect(mutation_response["users"]["edges"]).to include(
          { 'node' => { 'id' => "gid://gitlab/User/#{assigned_user.id}", 'name' => assigned_user.name,
                        'username' => assigned_user.username } },
          { 'node' => { 'id' => "gid://gitlab/User/#{assigned_user_2.id}", 'name' => assigned_user_2.name,
                        'username' => assigned_user_2.username } }
        )
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_add_on_assignment do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) { graphql_mutation(:user_add_on_assignment_bulk_remove, input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end
  end

  context 'on self-managed instances', :enable_admin_mode do
    let(:current_user) { create(:admin) }
    let_it_be_with_reload(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :self_managed, quantity: 10, add_on: add_on)
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    before_all do
      create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: assigned_user)
      create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: assigned_user_2)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_add_on_assignment do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:user_add_on_assignment_bulk_remove, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end

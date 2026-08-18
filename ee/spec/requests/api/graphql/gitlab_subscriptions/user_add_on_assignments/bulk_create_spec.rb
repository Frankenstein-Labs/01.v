# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UserAddOnAssignmentBulkCreate', feature_category: :seat_cost_management do
  include GraphqlHelpers
  shared_examples 'empty response' do
    it 'returns nil' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response).to be_nil
    end
  end

  shared_examples 'error response' do |error_message|
    it 'returns expected errors' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response["errors"]).to include(error_message)
      expect(mutation_response["addOnPurchase"]).to be_nil
      expect(mutation_response["users"]).to be_nil
    end
  end

  shared_examples 'success response' do
    it 'returns expected response' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response["errors"]).to eq([])
      expect(mutation_response["addOnPurchase"]).to eq(updated_add_on_purchase)
      expect(mutation_response["users"]["edges"]).to include(
        { 'node' => { 'id' => "gid://gitlab/User/#{assignee_user.id}", 'name' => assignee_user.name,
                      'username' => assignee_user.username } },
        { 'node' => { 'id' => "gid://gitlab/User/#{assignee_user_2.id}", 'name' => assignee_user_2.name,
                      'username' => assignee_user_2.username } }
      )
    end
  end

  shared_examples 'partial success response' do
    it 'returns expected response' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response["errors"]).to eq([])
      expect(mutation_response["addOnPurchase"]).to eq(updated_add_on_purchase.merge("assignedQuantity" => 1))
      expect(mutation_response["users"]["edges"]).to include(
        { 'node' => { 'id' => "gid://gitlab/User/#{assignee_user_2.id}", 'name' => assignee_user_2.name,
                      'username' => assignee_user_2.username } }
      )
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

    context 'when there are no seats available' do
      before do
        add_on_purchase.assigned_users.create!(user: create(:user))
      end

      it_behaves_like 'error response', 'NOT_ENOUGH_SEATS'
    end

    context 'when exceeding user assignment limit' do
      let(:assignment_limit) do
        Mutations::GitlabSubscriptions::UserAddOnAssignments::BulkCreate::MAX_USER_ASSIGNMENT_LIMIT
      end

      let(:input) do
        {
          user_ids: (1..(assignment_limit + 1)).map { |i| global_id_of(id: i, model_name: 'User') },
          add_on_purchase_id: add_on_purchase_id
        }
      end

      it 'returns nil and does not change quantity' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { add_on_purchase.quantity }

        expect(mutation_response).to be_nil
      end
    end
  end

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

  let(:mutation) { graphql_mutation(:user_add_on_assignment_bulk_create, input, requested_fields) }
  let(:mutation_response) { graphql_mutation_response(:user_add_on_assignment_bulk_create) }
  let(:updated_add_on_purchase) do
    {
      "assignedQuantity" => 2,
      "id" => "gid://gitlab/GitlabSubscriptions::AddOnPurchase/#{add_on_purchase.id}",
      "purchasedQuantity" => 10,
      "name" => 'CODE_SUGGESTIONS'
    }
  end

  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:assignee_user) { create(:user) }
  let_it_be(:assignee_user_2) { create(:user) }

  let(:user_id) { global_id_of(assignee_user) }
  let(:user2_id) { global_id_of(assignee_user_2) }
  let(:add_on_purchase_id) { global_id_of(add_on_purchase) }

  let(:input) do
    {
      user_ids: [user_id, user2_id],
      add_on_purchase_id: add_on_purchase_id
    }
  end

  context 'on Gitlab.com/Saas' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    let_it_be(:current_user) { create(:user) }
    let_it_be(:namespace) { create(:group) }
    let_it_be_with_reload(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on)
    end

    before_all do
      namespace.add_owner(current_user)
      namespace.add_developer(assignee_user)
      namespace.add_developer(assignee_user_2)
    end

    it_behaves_like 'validates the query'

    context 'with enough seats' do
      before do
        add_on_purchase.update!(quantity: 10)
      end

      it_behaves_like 'success response'

      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_add_on_assignment do
        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) { graphql_mutation(:user_add_on_assignment_bulk_create, input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'when a user does not belong to the namespace' do
        let(:user_id) { global_id_of(create(:user)) }

        it_behaves_like 'partial success response'
      end

      context 'when all users does not belong to the namespace' do
        let(:user_id) { global_id_of(create(:user)) }
        let(:user2_id) { global_id_of(create(:user)) }

        it_behaves_like 'error response', 'INVALID_USER_ID_PRESENT'
      end
    end

    context 'when a user is already assigned' do
      let_it_be(:assignee_user_3) { create(:user) }
      let(:user3_id) { global_id_of(assignee_user_3) }
      let(:input) do
        {
          user_ids: [user_id, user2_id, user3_id],
          add_on_purchase_id: add_on_purchase_id
        }
      end

      let(:updated_add_on_purchase) do
        {
          "assignedQuantity" => 3,
          "id" => "gid://gitlab/GitlabSubscriptions::AddOnPurchase/#{add_on_purchase.id}",
          "purchasedQuantity" => 3,
          "name" => 'CODE_SUGGESTIONS'
        }
      end

      before_all do
        add_on_purchase.update!(quantity: 3)
        namespace.add_developer(assignee_user_3)
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: assignee_user_3)
      end

      context 'with excluding the assigned user when checking seats available' do
        include_examples 'success response'
      end
    end
  end

  context 'on self-managed instances', :enable_admin_mode do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
      add_on_purchase.update!(quantity: 10)
    end

    let(:current_user) { create(:admin) }
    let_it_be_with_reload(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_add_on_assignment do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:user_add_on_assignment_bulk_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end

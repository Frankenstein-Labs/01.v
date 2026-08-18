# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UserAddOnAssignmentRemove', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:current_user, freeze: false) { create(:user) }
  let_it_be(:namespace, freeze: false) { create(:group) }
  let_it_be(:namespace_1, freeze: false) { create(:group) }
  let_it_be(:namespace_2, freeze: false) { create(:group) }
  let_it_be(:add_on_purchase, freeze: false) do
    create(:gitlab_subscription_add_on_purchase, namespace: namespace)
  end

  let_it_be(:remove_user, freeze: false) { create(:user) }

  let(:user_id) { global_id_of(remove_user) }
  let(:add_on_purchase_id) { global_id_of(add_on_purchase) }

  let(:input) do
    {
      user_id: user_id,
      add_on_purchase_id: add_on_purchase_id
    }
  end

  let(:queried_purchase_ids) { prepare_variables([add_on_purchase_id]) }

  let(:requested_fields) do
    <<-GQL
    errors
    addOnPurchase {
      id
      name
      purchasedQuantity
      assignedQuantity
    }
    user {
      name
      username

       addOnAssignments(addOnPurchaseIds: #{queried_purchase_ids}) {
        nodes {
          addOnPurchase {
            id
            name
          }
        }
      }
    }
    GQL
  end

  let(:namespace_path) { namespace.path }
  let(:mutation) { graphql_mutation(:user_add_on_assignment_remove, input, requested_fields) }
  let(:mutation_response) { graphql_mutation_response(:user_add_on_assignment_remove) }
  let(:expected_response) do
    {
      "assignedQuantity" => 0,
      "id" => "gid://gitlab/GitlabSubscriptions::AddOnPurchase/#{add_on_purchase.id}",
      "purchasedQuantity" => 1,
      "name" => 'CODE_SUGGESTIONS'
    }
  end

  shared_examples 'efficient mutation request' do
    let(:additional_purchase_1) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on_purchase.add_on, namespace: namespace_1)
    end

    let(:additional_purchase_2) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on_purchase.add_on, namespace: namespace_2)
    end

    let(:queried_purchase_ids) do
      prepare_variables([
        add_on_purchase_id,
        global_id_of(additional_purchase_1),
        global_id_of(additional_purchase_2)
      ])
    end

    before do
      additional_purchase_1.namespace.add_owner(current_user)
      additional_purchase_2.namespace.add_owner(current_user)

      if add_on_purchase.namespace
        additional_purchase_1.namespace.update!(organization: add_on_purchase.namespace.organization)
        additional_purchase_2.namespace.update!(organization: add_on_purchase.namespace.organization)
      end
    end

    it "avoids N+1 database queries", :request_store do
      create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: additional_purchase_1, user: remove_user)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_data_at(:user_add_on_assignment_remove, :user, :add_on_assignments, :nodes).count).to eq(1)

      # recreate the destroyed assignment
      create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: remove_user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql_mutation(mutation, current_user: current_user)
      end

      # recreate the destroyed assignment
      create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: remove_user)
      # create an additional assignment
      create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: additional_purchase_2, user: remove_user)

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to issue_same_number_of_queries_as(control)

      expect(graphql_data_at(:user_add_on_assignment_remove, :user, :add_on_assignments, :nodes).count).to eq(2)
    end
  end

  before_all do
    namespace.add_owner(current_user)
    add_on_purchase.assigned_users.create!(user: remove_user)
  end

  shared_examples 'empty response' do
    it 'returns nil' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { add_on_purchase.assigned_users.count }

      expect(mutation_response).to be_nil
    end
  end

  shared_examples 'success response' do
    it 'returns expected response' do
      allow(Gitlab::AppLogger).to receive(:info)

      expect(Gitlab::AppLogger).to receive(:info).with(
        message: 'User AddOn assignment removed',
        username: remove_user.username.to_s,
        add_on: add_on_purchase.add_on.name,
        namespace: namespace_path
      )

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { add_on_purchase.assigned_users.where(user: remove_user).count }.by(-1)

      expect(mutation_response['errors']).to eq([])
      expect(mutation_response['addOnPurchase']).to eq(expected_response)
      expect(mutation_response["user"]).to include(
        'name' => remove_user.name,
        'username' => remove_user.username,
        'addOnAssignments' => { 'nodes' => [] }
      )
    end

    it 'expires the cache key for that user', :use_clean_rails_redis_caching do
      cache_key = remove_user.duo_pro_cache_key_formatted
      Rails.cache.write(cache_key, true, expires_in: 1.hour)

      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { Rails.cache.read(cache_key) }.from(true).to(nil)
    end
  end

  it_behaves_like 'success response'

  it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_add_on_assignment do
    let(:user) { current_user }
    let(:boundary_object) { namespace }
    let(:mutation) { graphql_mutation(:user_add_on_assignment_remove, input, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  context 'when current_user is admin' do
    let(:current_user) { create(:admin) }

    it_behaves_like 'success response'
  end

  context 'when current_user is not owner or admin' do
    let(:current_user) { namespace.add_developer(create(:user)).user }

    it_behaves_like 'empty response'
  end

  context 'when the user does not have existing assignment' do
    let(:user_id) { global_id_of(create(:user)) }

    it_behaves_like 'empty response'
  end

  context 'when add_on_purchase_id does not exists' do
    let(:add_on_purchase_id) do
      global_id_of(id: non_existing_record_id, model_name: '::GitlabSubscriptions::AddOnPurchase')
    end

    it_behaves_like 'empty response'
  end

  context 'when add_on_purchase has expired' do
    before do
      add_on_purchase.update!(expires_on: 1.day.ago)
    end

    it_behaves_like 'empty response'
  end

  context 'when user_id does not exists' do
    let(:user_id) { global_id_of(id: non_existing_record_id, model_name: '::User') }

    it_behaves_like 'empty response'
  end

  context 'when the namespace is nil' do
    before do
      add_on_purchase.update!(namespace_id: nil)
    end

    after do
      add_on_purchase.update!(namespace_id: namespace.id)
    end

    context 'when current_user is admin' do
      let(:current_user) { create(:admin) }
      let(:namespace_path) { nil }

      it_behaves_like 'success response'
      context 'when there are multiple add-on assignments for the user' do
        it_behaves_like 'efficient mutation request'
      end

      context 'with a granular token on the instance boundary', :enable_admin_mode do
        it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_add_on_assignment do
          let(:user) { current_user }
          let(:boundary_object) { :instance }
          let(:mutation) { graphql_mutation(:user_add_on_assignment_remove, input, 'errors') }
          let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
        end
      end
    end

    context 'when current_user is not admin' do
      it_behaves_like 'empty response'
    end
  end

  context 'when there are multiple add-on assignments for the user', :saas do
    it_behaves_like 'efficient mutation request'
  end
end

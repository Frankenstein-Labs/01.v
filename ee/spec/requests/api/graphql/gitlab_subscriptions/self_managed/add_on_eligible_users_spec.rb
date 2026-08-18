# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.selfManagedAddOnEligibleUsers', feature_category: :seat_cost_management do
  include GraphqlHelpers
  let_it_be(:code_suggestions) { create(:gitlab_subscription_add_on) }

  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: code_suggestions)
  end

  let(:query_add_on_purchase_ids) { [global_id_of(add_on_purchase)] }

  let(:query_fields) do
    query_graphql_field(:nodes, {}, [
      'id',
      query_graphql_field(:add_on_assignments, { add_on_purchase_ids: query_add_on_purchase_ids }, [
        query_graphql_field(:nodes, {}, [
          query_graphql_field(:add_on_purchase, {}, %w[id name])
        ])
      ])
    ])
  end

  let(:add_on_params) { { addOnType: :CODE_SUGGESTIONS, addOnPurchaseIds: query_add_on_purchase_ids } }

  let(:query) do
    graphql_query_for(
      :selfManagedAddOnEligibleUsers,
      add_on_params,
      query_fields
    )
  end

  shared_examples 'not authorized' do
    it 'returns not authorized' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data).to eq({ "selfManagedAddOnEligibleUsers" => nil })
      expect(graphql_errors).to include(a_hash_including(
        'message' => "The resource that you are attempting to access does not exist " \
                     "or you don't have permission to perform this action"
      ))
    end
  end

  describe 'authorization' do
    context 'on a self-managed instance' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'with owner access' do
        let_it_be(:current_user) { create(:user) }

        let_it_be(:group) { create(:group) }
        let_it_be(:owner) { create(:user) }

        before_all do
          group.add_owner(current_user)
        end

        include_examples 'not authorized'
      end
    end

    context 'with an admin on SaaS/GitLab.com' do
      let_it_be(:current_user) { create(:admin) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      include_examples 'not authorized'
    end
  end

  context 'when the current user is authorised to query users' do
    let_it_be(:current_user) { create(:admin) }

    let_it_be(:guest_user) { create(:user, name: 'Guest Group User') }
    let_it_be(:active_user) { create(:user, name: 'Active Group User') }
    let_it_be(:active_user_2) { create(:user, name: 'GitlabX') }

    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    before_all do
      create(:gitlab_subscription_user_add_on_assignment, user: current_user, add_on_purchase: add_on_purchase)
      create(:gitlab_subscription_user_add_on_assignment, user: guest_user, add_on_purchase: add_on_purchase)
      create(:gitlab_subscription_user_add_on_assignment, user: active_user, add_on_purchase: add_on_purchase)
    end

    describe 'granular PAT authorization' do
      let(:query) do
        graphql_query_for(:selfManagedAddOnEligibleUsers, add_on_params, 'nodes { id }')
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :read_user do
        let(:user) { current_user }
        let(:boundary_object) { :user }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
      end
    end

    context 'when there are search args' do
      let(:query) do
        graphql_query_for(
          :selfManagedAddOnEligibleUsers,
          { addOnType: :CODE_SUGGESTIONS, addOnPurchaseIds: query_add_on_purchase_ids, search: 'Group User' },
          query_fields
        )
      end

      it 'returns the add on eligible users and their assignments, filtered by search term' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:self_managed_add_on_eligible_users, :nodes))
          .to match_array([
            {
              'id' => global_id_of(active_user).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            },
            {
              'id' => global_id_of(guest_user).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          ])
      end

      it 'returns empty records if search term does not match any users' do
        query_without_results = graphql_query_for(
          :selfManagedAddOnEligibleUsers,
          { addOnType: :CODE_SUGGESTIONS, addOnPurchaseIds: query_add_on_purchase_ids, search: 'Nonexistent User' },
          query_fields
        )

        post_graphql(query_without_results, current_user: current_user)

        expect(graphql_data_at(:self_managed_add_on_eligible_users, :nodes)).to be_empty
      end

      context 'with pagination' do
        let(:end_cursor) { graphql_data_at(:self_managed_add_on_eligible_users, :page_info, :end_cursor) }

        let(:first_page_query) do
          graphql_query_for(
            :selfManagedAddOnEligibleUsers,
            { addOnType: :CODE_SUGGESTIONS, addOnPurchaseIds: query_add_on_purchase_ids, search: 'Group User',
              first: 1 },
            "pageInfo { endCursor } #{query_fields}"
          )
        end

        let(:second_page_query) do
          graphql_query_for(
            :selfManagedAddOnEligibleUsers,
            { addOnType: :CODE_SUGGESTIONS, addOnPurchaseIds: query_add_on_purchase_ids, search: 'Group User',
              after: end_cursor, first: 1 },
            query_fields
          )
        end

        it 'returns the correct order of records when paginating' do
          post_graphql(first_page_query, current_user: current_user)
          first_page_nodes = graphql_data_at(:self_managed_add_on_eligible_users, :nodes)

          expect(first_page_nodes.count).to eq(1)
          expect(first_page_nodes).to contain_exactly(
            {
              'id' => global_id_of(active_user).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          )

          post_graphql(second_page_query, current_user: current_user)
          second_page_nodes = graphql_data_at(:self_managed_add_on_eligible_users, :nodes)

          expect(second_page_nodes.count).to eq(1)
          expect(second_page_nodes).to contain_exactly(
            {
              'id' => global_id_of(guest_user).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          )
        end
      end
    end

    context 'when there are no search args' do
      let_it_be(:bot) { create(:user, :bot) }
      let_it_be(:ghost) { create(:user, :ghost) }
      let_it_be(:blocked_user) { create(:user, :blocked) }
      let_it_be(:banned_user) { create(:user, :banned) }
      let_it_be(:pending_approval_user) { create(:user, :blocked_pending_approval) }

      it 'returns all the add on eligible users and their assignments' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:self_managed_add_on_eligible_users, :nodes)).to match_array([
          {
            'id' => global_id_of(current_user).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(guest_user).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(active_user).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(active_user_2).to_s,
            'addOnAssignments' => { 'nodes' => [] }
          }
        ])
      end
    end

    context 'when there are multiple add-on eligible users' do
      it 'avoids N+1 database queries', :request_store do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:self_managed_add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(3)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        additional_user = create(:user)
        create(:gitlab_subscription_user_add_on_assignment, user: additional_user, add_on_purchase: add_on_purchase)

        expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
        expect(graphql_data_at(:self_managed_add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(4)
      end
    end

    context 'when there are filter options' do
      let(:query) do
        graphql_query_for(
          :selfManagedAddOnEligibleUsers,
          { addOnType: :CODE_SUGGESTIONS, addOnPurchaseIds: query_add_on_purchase_ids, filterByAssignedSeat: 'true' },
          query_fields
        )
      end

      it 'returns the add on eligible users and their assignments, filtered by assigned seat' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:self_managed_add_on_eligible_users, :nodes))
          .to match_array([
            {
              'id' => global_id_of(active_user).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            },
            {
              'id' => global_id_of(guest_user).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            },
            {
              'id' => global_id_of(current_user).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          ])
      end
    end
  end

  def expected_add_on_purchase_data(expected_add_on_purchase)
    {
      'addOnPurchase' => { 'id' => global_id_of(expected_add_on_purchase).to_s, 'name' => 'CODE_SUGGESTIONS' }
    }
  end
end

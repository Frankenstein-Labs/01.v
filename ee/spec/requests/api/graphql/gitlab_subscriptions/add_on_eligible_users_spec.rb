# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.namespace.addOnEligibleUsers', feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:current_user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:group_1, freeze: false) { create(:group) }
  let_it_be(:gitlab_duo_pro, freeze: false) { create(:gitlab_subscription_add_on, :duo_pro) }

  let_it_be(:add_on_purchase, freeze: false) do
    create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro, namespace: group)
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

  let(:add_on_params) { { add_on_type: :CODE_SUGGESTIONS, add_on_purchase_ids: query_add_on_purchase_ids } }

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  context 'when the user is not eligible to admin add-on purchases on the namespace' do
    let(:query) do
      graphql_query_for(
        :namespace, { full_path: add_on_purchase.namespace.full_path },
        query_graphql_field(:addOnEligibleUsers, add_on_params, query_fields)
      )
    end

    before do
      add_on_purchase.namespace.add_developer(current_user)
    end

    it 'returns no eligible users' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at['namespace']).to eq('addOnEligibleUsers' => nil)
      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist or you don't " \
                                       "have permission to perform this action")
    end
  end

  context 'when the requested namespace is not a root one' do
    let(:subgroup) { create(:group, parent: create(:group)) }

    let(:query) do
      graphql_query_for(
        :namespace, { full_path: subgroup.full_path },
        query_graphql_field(:addOnEligibleUsers, add_on_params, query_fields)
      )
    end

    before do
      subgroup.add_owner(current_user)
    end

    it 'returns an error message and no eligible users' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at['namespace']).to eq('addOnEligibleUsers' => nil)
      expect_graphql_errors_to_include('Add on eligible users can only be queried on a root namespace')
    end
  end

  context 'when the current user is authorised to view the requested purchase ID' do
    let_it_be(:guest, freeze: false) { create(:user, name: 'Guest Group User') }
    let_it_be(:developer, freeze: false) { create(:user, name: 'Developer Group User') }

    before_all do
      add_on_purchase.namespace.add_owner(current_user)
      add_on_purchase.namespace.add_guest(guest)
      add_on_purchase.namespace.add_developer(developer)

      create(:gitlab_subscription_user_add_on_assignment, user: current_user, add_on_purchase: add_on_purchase)
      create(:gitlab_subscription_user_add_on_assignment, user: guest, add_on_purchase: add_on_purchase)
      create(:gitlab_subscription_user_add_on_assignment, user: developer, add_on_purchase: add_on_purchase)
    end

    context 'when there are search args' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(
            :addOnEligibleUsers,
            { add_on_type: :CODE_SUGGESTIONS, search: 'Group User', add_on_purchase_ids: query_add_on_purchase_ids },
            query_fields
          )
        )
      end

      it 'returns the add on eligible users and their assignments, filtered by search term, ordered by ID' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes))
          .to eq([
            {
              'id' => global_id_of(developer).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            },
            {
              'id' => global_id_of(guest).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          ])
      end

      context 'with pagination' do
        let(:end_cursor) { graphql_data_at(:namespace, :add_on_eligible_users, :page_info, :end_cursor) }

        let(:first_page_query) do
          graphql_query_for(
            :namespace, { full_path: add_on_purchase.namespace.full_path },
            query_graphql_field(
              :addOnEligibleUsers,
              { add_on_type: :CODE_SUGGESTIONS, add_on_purchase_ids: query_add_on_purchase_ids, search: 'Group User',
                first: 1 },
              "pageInfo { endCursor } #{query_fields}"
            )
          )
        end

        let(:second_page_query) do
          graphql_query_for(
            :namespace, { full_path: add_on_purchase.namespace.full_path },
            query_graphql_field(
              :addOnEligibleUsers,
              { add_on_type: :CODE_SUGGESTIONS, add_on_purchase_ids: query_add_on_purchase_ids, search: 'Group User',
                after: end_cursor, first: 1 },
              query_fields
            )
          )
        end

        it 'returns the correct order of records when paginating' do
          post_graphql(first_page_query, current_user: current_user)
          first_page_nodes = graphql_data_at(:namespace, :add_on_eligible_users, :nodes)

          expect(first_page_nodes.count).to eq(1)
          expect(first_page_nodes).to contain_exactly(
            {
              'id' => global_id_of(developer).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          )

          post_graphql(second_page_query, current_user: current_user)
          second_page_nodes = graphql_data_at(:namespace, :add_on_eligible_users, :nodes)

          expect(second_page_nodes.count).to eq(1)
          expect(second_page_nodes).to contain_exactly(
            {
              'id' => global_id_of(guest).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            }
          )
        end
      end
    end

    context 'when there are no search args' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:addOnEligibleUsers, add_on_params, query_fields)
        )
      end

      it 'returns all the add on eligible users and their assignments' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes)).to match_array([
          {
            'id' => global_id_of(current_user).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(guest).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(developer).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          }
        ])
      end
    end

    context 'when the current user is only eligible to view a subset of assignments' do
      let(:add_on_purchase_1) { create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro) }
      let(:add_on_purchase_2) { create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro) }

      let(:query_add_on_purchase_ids) do
        [global_id_of(add_on_purchase), global_id_of(add_on_purchase_1), global_id_of(add_on_purchase_1)]
      end

      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:addOnEligibleUsers, add_on_params, query_fields)
        )
      end

      before do
        add_on_purchase_1.namespace.add_owner(current_user)
        add_on_purchase_2.namespace.add_guest(current_user) # guest users can't admin add-on purchases

        create(:gitlab_subscription_user_add_on_assignment, user: guest, add_on_purchase: add_on_purchase_1)
        create(:gitlab_subscription_user_add_on_assignment, user: developer, add_on_purchase: add_on_purchase_2)
      end

      it 'only returns the authorised one' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes)).to match_array([
          {
            'id' => global_id_of(current_user).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          },
          {
            'id' => global_id_of(guest).to_s,
            'addOnAssignments' => {
              'nodes' => match_array([
                expected_add_on_purchase_data(add_on_purchase),
                expected_add_on_purchase_data(add_on_purchase_1)
              ])
            }
          },
          {
            'id' => global_id_of(developer).to_s,
            'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
          }
        ])
      end
    end

    context 'when there are multiple add-on eligible users' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:add_on_eligible_users, add_on_params, query_fields)
        )
      end

      it "avoids N+1 database queries", :request_store do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(3)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        additional_user = create(:user)
        add_on_purchase.namespace.add_guest(additional_user)
        create(:gitlab_subscription_user_add_on_assignment, user: additional_user, add_on_purchase: add_on_purchase)

        expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(4)
      end
    end

    context 'when selecting for multiple add on purchases' do
      let(:other_add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro, namespace: group_1)
      end

      let(:query_add_on_purchase_ids) do
        [global_id_of(add_on_purchase), global_id_of(other_add_on_purchase)]
      end

      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(:add_on_eligible_users, add_on_params, query_fields)
        )
      end

      before do
        other_add_on_purchase.namespace.add_owner(current_user)
        other_add_on_purchase.namespace.update!(organization: add_on_purchase.namespace.organization)
      end

      it "avoids N+1 database queries", :request_store do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(3)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create(:gitlab_subscription_user_add_on_assignment, user: current_user, add_on_purchase: other_add_on_purchase)

        expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes, :add_on_assignments, :nodes).count).to eq(4)
      end
    end

    context 'when there are filter args' do
      let(:ineligible_user) { create(:user, name: 'Ineligible User') }

      let(:query) do
        graphql_query_for(
          :namespace, { full_path: add_on_purchase.namespace.full_path },
          query_graphql_field(
            :addOnEligibleUsers,
            { add_on_type: :CODE_SUGGESTIONS, add_on_purchase_ids: query_add_on_purchase_ids,
              filterByAssignedSeat: 'true' },
            query_fields
          )
        )
      end

      it 'returns the add on eligible users and their assignments, filtered by assigned seat' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :add_on_eligible_users, :nodes))
          .to eq([
            {
              'id' => global_id_of(developer).to_s,
              'addOnAssignments' => { 'nodes' => [expected_add_on_purchase_data(add_on_purchase)] }
            },
            {
              'id' => global_id_of(guest).to_s,
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

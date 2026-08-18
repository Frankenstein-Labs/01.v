# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Rolled up weight updates on work item changes', :aggregate_failures, :sidekiq_inline, feature_category: :team_planning do
  include GraphqlHelpers
  include WorkhorseHelpers

  # Ensure support bot user is created so it doesn't get created within a transaction
  let_it_be_with_reload(:support_bot) { create(:support_bot) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be_with_reload(:user) { create(:user, developer_of: project) }
  let_it_be_with_reload(:parent_work_item) { create(:work_item, :issue, project: project) }
  let_it_be_with_reload(:child_task_1) { create(:work_item, :task, project: project, weight: 3) }
  let_it_be_with_reload(:child_task_2) { create(:work_item, :task, project: project, weight: 2) }
  let_it_be_with_reload(:child_task_3) { create(:work_item, :task, project: project, weight: 5) }

  let_it_be_with_reload(:parent_link_1) do
    create(:parent_link, work_item: child_task_1, work_item_parent: parent_work_item)
  end

  let_it_be_with_reload(:parent_link_2) do
    create(:parent_link, work_item: child_task_2, work_item_parent: parent_work_item)
  end

  let_it_be_with_reload(:parent_link_3) do
    create(:parent_link, work_item: child_task_3, work_item_parent: parent_work_item)
  end

  let(:current_user) { user }

  let(:mutation) { graphql_mutation(:workItemUpdate, input) }

  let(:mutation_response) { graphql_mutation_response(:workItemUpdate) }

  before_all do
    # Initialize parent weights
    WorkItems::Weights::UpdateWeightsService.new([parent_work_item]).execute
  end

  shared_examples 'updates rolled up weights correctly' do
    it 'updates weights correctly' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response&.dig('errors') || []).to be_empty

      # Verify the work item state changed
      expect(work_item.reload.state).to eq(expected_state)

      # Verify parent weights are updated correctly
      parent_weights = parent_work_item.reload.weights_source
      expect(parent_weights&.rolled_up_weight).to eq(expected_total_weight)
      expect(parent_weights&.rolled_up_completed_weight).to eq(expected_completed_weight)
    end
  end

  describe 'closing a work item' do
    let(:work_item) { child_task_1 }
    let(:input) { { id: work_item.to_gid.to_s, stateEvent: 'CLOSE' } }
    let(:expected_event_class) { WorkItems::WorkItemClosedEvent }
    let(:expected_state) { 'closed' }
    let(:expected_total_weight) { 10 } # 3 + 2 + 5
    let(:expected_completed_weight) { 3 } # Only child_task_1 is closed

    before do
      # Ensure all tasks start as open
      [child_task_1, child_task_2, child_task_3].each { |task| task.update!(state: :opened) }
    end

    include_examples 'updates rolled up weights correctly'

    context 'when closing multiple tasks sequentially' do
      it 'updates completed weight incrementally' do
        # Close first task
        post_graphql_mutation(
          graphql_mutation(:workItemUpdate, { id: child_task_1.to_gid.to_s, stateEvent: 'CLOSE' }),
          current_user: current_user
        )

        parent_weights = parent_work_item.reload.weights_source
        expect(parent_weights&.rolled_up_completed_weight).to eq(3)

        # Close second task
        post_graphql_mutation(
          graphql_mutation(:workItemUpdate, { id: child_task_2.to_gid.to_s, stateEvent: 'CLOSE' }),
          current_user: current_user
        )

        parent_weights = parent_work_item.reload.weights_source
        expect(parent_weights&.rolled_up_completed_weight).to eq(5) # 3 + 2

        # Close third task
        post_graphql_mutation(
          graphql_mutation(:workItemUpdate, { id: child_task_3.to_gid.to_s, stateEvent: 'CLOSE' }),
          current_user: current_user
        )

        parent_weights = parent_work_item.reload.weights_source
        expect(parent_weights&.rolled_up_completed_weight).to eq(10) # 3 + 2 + 5
      end
    end
  end

  describe 'reopening a work item' do
    let(:work_item) { child_task_1 }
    let(:input) { { id: work_item.to_gid.to_s, stateEvent: 'REOPEN' } }
    let(:expected_event_class) { WorkItems::WorkItemReopenedEvent }
    let(:expected_state) { 'opened' }
    let(:expected_total_weight) { 10 } # 3 + 2 + 5
    let(:expected_completed_weight) { 7 } # child_task_2 (2) + child_task_3 (5)

    before do
      # Close all tasks first
      [child_task_1, child_task_2, child_task_3].each { |task| task.update!(state: :closed) }
      WorkItems::Weights::UpdateWeightsService.new([parent_work_item]).execute
    end

    include_examples 'updates rolled up weights correctly'

    context 'when reopening all tasks' do
      it 'resets completed weight to 0' do
        # Clean up any existing weights_source records from previous tests
        WorkItems::WeightsSource.where(work_item_id: [child_task_1.id, child_task_2.id,
          child_task_3.id, parent_work_item.id]).delete_all

        # Start with all tasks closed - ensure they are actually closed
        [child_task_1, child_task_2, child_task_3].each do |task|
          task.reload
          task.update!(state: :closed)
        end
        WorkItems::WeightsSource.upsert_rolled_up_weights_for(parent_work_item)
        parent_weights = parent_work_item.reload.weights_source
        expect(parent_weights&.rolled_up_completed_weight).to eq(10)

        # Reopen all tasks and update weights
        [child_task_1, child_task_2, child_task_3].each do |task|
          post_graphql_mutation(
            graphql_mutation(:workItemUpdate, { id: task.to_gid.to_s, stateEvent: 'REOPEN' }),
            current_user: current_user
          )
        end
        parent_weights = parent_work_item.reload.weights_source
        expect(parent_weights&.rolled_up_weight).to eq(10)
        expect(parent_weights&.rolled_up_completed_weight).to eq(0)
      end
    end
  end

  describe 'mixed state changes' do
    before do
      # Start with all tasks open
      [child_task_1, child_task_2, child_task_3].each { |task| task.update!(state: :opened) }
      WorkItems::Weights::UpdateWeightsService.new([parent_work_item]).execute
    end

    it 'handles complex state change scenarios' do
      parent_weights = parent_work_item.reload.weights_source
      expect(parent_weights&.rolled_up_completed_weight).to eq(0)

      # Close task 1 (weight: 3)
      post_graphql_mutation(
        graphql_mutation(:workItemUpdate, { id: child_task_1.to_gid.to_s, stateEvent: 'CLOSE' }),
        current_user: current_user
      )
      parent_weights = parent_work_item.reload.weights_source
      expect(parent_weights&.rolled_up_completed_weight).to eq(3)

      # Close task 3 (weight: 5)
      post_graphql_mutation(
        graphql_mutation(:workItemUpdate, { id: child_task_3.to_gid.to_s, stateEvent: 'CLOSE' }),
        current_user: current_user
      )
      parent_weights = parent_work_item.reload.weights_source
      expect(parent_weights&.rolled_up_completed_weight).to eq(8) # 3 + 5

      # Reopen task 1 (weight: 3)
      post_graphql_mutation(
        graphql_mutation(:workItemUpdate, { id: child_task_1.to_gid.to_s, stateEvent: 'REOPEN' }),
        current_user: current_user
      )
      parent_weights = parent_work_item.reload.weights_source
      expect(parent_weights&.rolled_up_completed_weight).to eq(5) # Only task 3

      # Close task 2 (weight: 2)
      post_graphql_mutation(
        graphql_mutation(:workItemUpdate, { id: child_task_2.to_gid.to_s, stateEvent: 'CLOSE' }),
        current_user: current_user
      )
      parent_weights = parent_work_item.reload.weights_source
      expect(parent_weights&.rolled_up_completed_weight).to eq(7) # task 2 (2) + task 3 (5)
    end
  end

  describe 'adding a child work item' do
    let_it_be_with_reload(:child_task_4) { create(:work_item, :task, project: project, weight: 99) }

    it 'updates the rolled up weight of the parent' do
      expect do
        post_graphql_mutation(
          graphql_mutation(:workItemUpdate, {
            id: parent_work_item.to_gid.to_s, hierarchy_widget: { children_ids: [child_task_4.to_gid.to_s] }
          }),
          current_user: current_user
        )
      end.to change { parent_work_item.weights_source.reload.rolled_up_weight }.by(99)
    end
  end

  describe 'deleting a child work item' do
    it 'updates the rolled up weight of the parent' do
      expect do
        post_graphql_mutation(
          graphql_mutation(:workItemDelete, { id: child_task_3.to_gid.to_s }),
          current_user: create(:user, :admin)
        )
      end.to change { parent_work_item.weights_source.reload.rolled_up_weight }.by(-5)
    end
  end

  describe 'reordering work items in the hierarchy tree' do
    let_it_be_with_reload(:root_work_item) { create(:work_item, :epic, namespace: group) }
    let_it_be_with_reload(:new_parent_work_item) { create(:work_item, :issue, project: project) }

    before_all do
      create(:parent_link, work_item: parent_work_item, work_item_parent: root_work_item)
      create(:parent_link, work_item: new_parent_work_item, work_item_parent: root_work_item)
    end

    it 'updates the rolled up weight of both old and new parents' do
      expect(parent_work_item.reload.weights_source.rolled_up_weight).to eq(10)
      expect(new_parent_work_item.reload.weights_source).to be_nil

      post_graphql_mutation(
        graphql_mutation(:workItemsHierarchyReorder, {
          id: child_task_3.to_gid.to_s, parent_id: new_parent_work_item.to_gid.to_s
        }),
        current_user: current_user
      )

      expect(parent_work_item.reload.weights_source.rolled_up_weight).to eq(5)
      expect(new_parent_work_item.reload.weights_source.rolled_up_weight).to eq(5)
    end
  end

  describe 'error handling' do
    context 'when user lacks permissions' do
      let(:unauthorized_user) { create(:user) }

      it 'does not update weights when mutation fails' do
        initial_completed_weight = parent_work_item.reload.weights_source&.rolled_up_completed_weight || 0

        post_graphql_mutation(
          graphql_mutation(:workItemUpdate, { id: child_task_1.to_gid.to_s, stateEvent: 'CLOSE' }),
          current_user: unauthorized_user
        )

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to include(hash_including('message' => /you don't have permission/i))

        # Verify weights haven't changed
        final_completed_weight = parent_work_item.reload.weights_source&.rolled_up_completed_weight || 0
        expect(final_completed_weight).to eq(initial_completed_weight)
      end
    end

    context 'when work item does not exist' do
      it 'returns appropriate error' do
        post_graphql_mutation(
          graphql_mutation(:workItemUpdate, { id: "gid://gitlab/WorkItem/999999", stateEvent: 'CLOSE' }),
          current_user: current_user
        )

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to include(hash_including('message' => /you don't have permission/))
      end
    end
  end
end

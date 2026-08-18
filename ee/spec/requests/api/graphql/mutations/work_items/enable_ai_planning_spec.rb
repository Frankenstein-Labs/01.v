# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Enabling AI planning on a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:reporter) { create(:user, reporter_of: [project, group]) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project) }

  let(:current_user) { reporter }
  let(:mutation_params) { { id: work_item.to_global_id.to_s } }
  let(:mutation) { graphql_mutation(:work_item_enable_ai_planning, mutation_params, mutation_fields) }
  let(:mutation_response) { graphql_mutation_response(:work_item_enable_ai_planning) }
  let(:mutation_fields) do
    <<~FIELDS
      workItem {
        widgets {
          ... on WorkItemWidgetAgentPlan {
            aiPlanningEnabled
          }
        }
        features {
          agentPlan {
            aiPlanningEnabled
          }
        }
      }
      errors
    FIELDS
  end

  before do
    stub_licensed_features(ai_workflows: true)
  end

  context 'when workplan feature flag is disabled' do
    before do
      stub_feature_flags(workplan: false)
    end

    it 'returns a resource not available error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist")
    end
  end

  context 'when user does not have permission to update the work item' do
    let(:current_user) { guest }

    it 'returns a resource not available error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist")
    end
  end

  context 'when user has permission to update the work item' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_work_item do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(:work_item_enable_ai_planning, mutation_params, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'sets ai_planning_enabled to true on a new agent plan' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { work_item.reload.agent_plan&.ai_planning_enabled }.from(nil).to(true)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(agent_plan_widget_response).to include('aiPlanningEnabled' => true)
      expect(mutation_response.dig('workItem', 'features', 'agentPlan', 'aiPlanningEnabled')).to be true
    end

    context 'when an agent plan already exists with ai_planning_enabled false' do
      let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, ai_planning_enabled: false) }

      it 'sets ai_planning_enabled to true on the existing agent plan' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { agent_plan.reload.ai_planning_enabled }.from(false).to(true)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
      end
    end

    context 'when an agent plan already exists with ai_planning_enabled true' do
      let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, ai_planning_enabled: true) }

      it 'is idempotent and returns success' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { agent_plan.reload.ai_planning_enabled }

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty

        expect(agent_plan_widget_response).to include('aiPlanningEnabled' => true)
        expect(mutation_response.dig('workItem', 'features', 'agentPlan', 'aiPlanningEnabled')).to be true
      end
    end

    context 'when a concurrent request creates the agent plan first' do
      before do
        first_save = true

        allow_next_instance_of(::WorkItems::AgentPlan) do |plan|
          allow(plan).to receive(:save).and_wrap_original do |original|
            next original.call unless first_save

            first_save = false
            create(:work_item_agent_plan, work_item: work_item)

            raise ActiveRecord::RecordNotUnique, 'duplicate key value violates unique constraint'
          end
        end
      end

      it 'retries and enables AI planning on the existing agent plan' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { work_item.reload.agent_plan&.ai_planning_enabled }.from(nil).to(true)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty
      end
    end

    context 'when the agent plan cannot be saved' do
      let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item) }

      before do
        allow_next_found_instance_of(::WorkItems::AgentPlan) do |plan|
          allow(plan).to receive(:save) do
            plan.errors.add(:base, 'Something went wrong')
            false
          end
        end
      end

      it 'returns the errors and does not enable AI planning' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { agent_plan.reload.ai_planning_enabled }

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('Something went wrong')
      end
    end

    context 'when the work item does not have the agent plan widget' do
      before do
        stub_licensed_features(ai_workflows: false)
      end

      it 'returns a resource not available error' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { ::WorkItems::AgentPlan.count }

        expect_graphql_errors_to_include("The resource that you are attempting to access does not exist")
      end
    end
  end

  context 'with group level work item' do
    let_it_be(:group_work_item) { create(:work_item, :group_level, namespace: group) }
    let(:mutation_params) { { id: group_work_item.to_global_id.to_s } }

    before do
      stub_licensed_features(epics: true, ai_workflows: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_work_item do
      let(:user) { current_user }
      let(:boundary_object) { group }
      let(:mutation) do
        graphql_mutation(:work_item_enable_ai_planning, mutation_params, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  def agent_plan_widget_response
    mutation_response.dig('workItem', 'widgets').find { |widget| widget.key?('aiPlanningEnabled') }
  end
end

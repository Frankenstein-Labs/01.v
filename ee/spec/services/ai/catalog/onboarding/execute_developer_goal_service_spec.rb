# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Onboarding::ExecuteDeveloperGoalService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:workflow) { instance_double(Ai::DuoWorkflows::Workflow, id: 42) }
  let(:execute_result) { ServiceResponse.success(payload: { workflow: workflow, workload_id: 1 }) }
  let(:consumer) { instance_double(Ai::Catalog::ItemConsumer, active_service_account: nil, item: nil) }
  let(:catalog_item) { instance_double(Ai::Catalog::Item, consumers: consumer_scope) }
  let(:consumer_scope) { double('consumer_scope') } # rubocop:disable RSpec/VerifiedDoubles -- AR named scopes are not instance methods on ActiveRecord::Relation
  let(:foundational_flow) { instance_double(Ai::Catalog::FoundationalFlow, catalog_item: catalog_item) }

  before do
    allow(Ai::Catalog::FoundationalFlow).to receive(:[]).with('developer/v1').and_return(foundational_flow)
    allow(consumer_scope).to receive(:for_projects).with(project).and_return(consumer_scope)
    allow(consumer_scope).to receive(:first).and_return(consumer)

    allow_next_instance_of(Ai::Catalog::Flows::ExecuteService) do |svc|
      allow(svc).to receive(:execute).and_return(execute_result)
    end
  end

  subject(:service) do
    described_class.new(project: project, current_user: user, params: { event_type: :init_project_context })
  end

  describe '#execute' do
    it 'calls ExecuteService with the rendered goal and project-level consumer' do
      rendered_goal = Ai::Catalog::GoalTemplates::Developer.resolve(
        event_type: :init_project_context,
        resource: project,
        user_input: nil,
        params: { triggered_by_username: user.username }
      )

      expect(Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
        project: project,
        current_user: user,
        params: hash_including(
          item_consumer: consumer,
          user_prompt: rendered_goal,
          event_type: 'web',
          execute_workflow: true,
          service_account: nil
        )
      ).and_call_original

      service.execute
    end

    it 'returns the result from ExecuteService' do
      expect(service.execute).to eq(execute_result)
    end

    context 'when no project-level consumer exists' do
      before do
        allow(consumer_scope).to receive(:first).and_return(nil)
      end

      it 'passes nil as the item_consumer with no group fallback' do
        expect(Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: user,
          params: hash_including(item_consumer: nil, service_account: nil)
        ).and_call_original

        service.execute
      end
    end

    context 'with a different event_type' do
      subject(:service) do
        described_class.new(project: project, current_user: user, params: { event_type: :mention })
      end

      it 'resolves the goal for the given event_type' do
        rendered_goal = Ai::Catalog::GoalTemplates::Developer.resolve(
          event_type: :mention,
          resource: project,
          user_input: nil,
          params: { triggered_by_username: user.username }
        )

        expect(Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: user,
          params: hash_including(user_prompt: rendered_goal)
        ).and_call_original

        service.execute
      end
    end
  end
end

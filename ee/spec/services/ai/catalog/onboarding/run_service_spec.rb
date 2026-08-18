# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Onboarding::RunService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:event_type) { 'init_project_context' }
  let(:params) { { event_type: event_type } }
  let(:service) { described_class.new(project: project, current_user: user, params: params) }
  let(:goal_service) { Ai::Catalog::Onboarding::ExecuteDeveloperGoalService }

  before do
    stub_feature_flags(duo_agent_onboarding: true)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :duo_workflow, project).and_return(true)
  end

  def stub_goal_service(result = nil)
    result ||= ServiceResponse.success(payload: { workflow: build_stubbed(:duo_workflows_workflow, id: 77) })

    allow(goal_service).to receive(:new).and_return(instance_double(goal_service, execute: result))
  end

  describe '#execute' do
    context 'when the user lacks duo_workflow access' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :duo_workflow, project).and_return(false)
      end

      it 'returns an error and does not start a workflow', :aggregate_failures do
        expect(goal_service).not_to receive(:new)
        expect(service.execute).to be_error
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(duo_agent_onboarding: false)
      end

      it 'returns an error' do
        expect(service.execute).to be_error
      end
    end

    context 'when the initializer key is unknown' do
      let(:event_type) { 'nope' }

      it 'returns an error' do
        expect(service.execute).to be_error
      end
    end

    context 'when the initializer is not applicable' do
      let(:event_type) { 'improve_ci' }

      it 'returns an error and does not start a workflow', :aggregate_failures do
        expect(goal_service).not_to receive(:new)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('Initializer is not applicable.')
      end
    end

    context 'when an applicable initializer is run' do
      before do
        stub_goal_service
      end

      it 'starts the workflow and returns its id', :aggregate_failures do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:workflow_id]).to eq(77)
      end

      it 'invokes ExecuteDeveloperGoalService with the initializer event_type' do
        service.execute

        expect(goal_service).to have_received(:new).with(
          project: project, current_user: user, params: { event_type: :init_project_context }
        )
      end
    end

    context 'when starting the workflow fails' do
      before do
        stub_goal_service(ServiceResponse.error(message: 'boom'))
      end

      it 'returns the error', :aggregate_failures do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('boom')
      end
    end

    context 'when a workflow is already active for the initializer' do
      before do
        allow_next_instance_of(Ai::Catalog::Onboarding::WorkflowTracker) do |tracker|
          allow(tracker).to receive(:active_workflow).with('init_project_context')
            .and_return(build_stubbed(:duo_workflows_workflow))
        end
      end

      it 'returns an error and does not start a new workflow', :aggregate_failures do
        expect(goal_service).not_to receive(:new)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('An initializer run is already in progress.')
      end
    end
  end
end

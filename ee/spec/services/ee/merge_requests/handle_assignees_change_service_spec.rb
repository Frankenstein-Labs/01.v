# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::HandleAssigneesChangeService, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, author: user, source_project: project) }

  let(:old_assignees) { [] }
  let(:options) { {} }

  let(:service) { described_class.new(project: project, current_user: user) }

  describe '#execute' do
    def execute
      service.execute(merge_request, old_assignees, options)
    end

    it 'schedules for analytics metric update' do
      expect(Analytics::CodeReviewMetricsWorker)
        .to receive(:perform_async).with('Analytics::RefreshReassignData', merge_request.id)

      execute
    end

    context 'when code_review_analytics is not available' do
      before do
        stub_licensed_features(code_review_analytics: false)
      end

      it 'does not schedule for analytics metric update' do
        expect(Analytics::CodeReviewMetricsWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'when AI flow triggers are available' do
      let_it_be(:service_account) { create(:service_account, username: 'flow-trigger-1') }
      let_it_be(:flow_trigger) { create(:ai_flow_trigger, project: project, event_types: [1], user: service_account) }

      it 'runs the service' do
        allow(user).to receive(:can?).with(:trigger_ai_flow, project).and_return(true)

        merge_request.assignees = [service_account]

        run_service = instance_double(::Ai::FlowTriggers::RunService)

        expect(run_service).to receive(:execute).with(
          { input: merge_request.iid.to_s, event: :assign, triggered_by_username: user.username }
        )
        expect(::Ai::FlowTriggers::RunService).to receive(:new)
          .with(project: project, current_user: user, resource: merge_request, flow_trigger: flow_trigger)
          .and_return(run_service)

        execute
      end
    end
  end
end

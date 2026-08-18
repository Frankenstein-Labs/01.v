# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::AgentPlanType, feature_category: :team_planning do
  include GraphqlHelpers

  let(:fields) do
    %i[type content content_html readiness_score ai_planning_enabled]
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetAgentPlan') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  describe 'field call count limits' do
    it 'limits content field call count to 1' do
      expect(described_class.fields['content'].extensions).to include(a_kind_of(::Gitlab::Graphql::Limit::FieldCallCount))
    end

    it 'limits contentHtml field call count to 1' do
      expect(described_class.fields['contentHtml'].extensions).to include(a_kind_of(::Gitlab::Graphql::Limit::FieldCallCount))
    end
  end

  describe '#readiness_score' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:work_item) { create(:work_item, project: project) }
    let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, readiness_score: 80) }

    let(:widget) { ::WorkItems::Widgets::AgentPlan.new(work_item) }

    subject(:readiness_score) { resolve_field(:readiness_score, widget) }

    context 'when workplan_score feature flag is enabled' do
      before do
        stub_feature_flags(workplan_score: group)
      end

      it 'returns the readiness_score' do
        expect(readiness_score).to eq(80)
      end

      context 'when readiness_score is nil' do
        let_it_be(:work_item) { create(:work_item, project: project) }
        let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, readiness_score: nil) }

        it 'returns nil' do
          expect(readiness_score).to be_nil
        end
      end
    end

    context 'when workplan_score feature flag is disabled' do
      before do
        stub_feature_flags(workplan_score: false)
      end

      it 'returns nil' do
        expect(readiness_score).to be_nil
      end
    end
  end

  describe '.track_agent_plan_read' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, reporters: user) }
    let_it_be_with_reload(:work_item) { create(:work_item, project: project, author: user) }

    let(:widget) { ::WorkItems::Widgets::AgentPlan.new(work_item) }
    let(:tracking_service) { instance_double(::Gitlab::WorkItems::Instrumentation::TrackingService) }

    before do
      allow(::Gitlab::WorkItems::Instrumentation::TrackingService)
        .to receive_messages(new: tracking_service, current_source: 'ai_workflows')
      allow(tracking_service).to receive(:execute)
    end

    context 'when the agent plan has content' do
      before do
        create(:work_item_agent_plan, work_item: work_item, content: 'Some plan')
        work_item.reload
      end

      it 'fires a read event with the source dimension', :aggregate_failures do
        described_class.track_agent_plan_read(widget, user)

        expect(::Gitlab::WorkItems::Instrumentation::TrackingService).to have_received(:new).with(
          work_item: work_item,
          current_user: user,
          event: ::Gitlab::WorkItems::Instrumentation::EventActions::AGENT_PLAN_READ,
          extra_properties: { source: 'ai_workflows' }
        )
        expect(tracking_service).to have_received(:execute)
      end

      it 'fires only once per work item within a request', :request_store, :aggregate_failures do
        described_class.track_agent_plan_read(widget, user)
        described_class.track_agent_plan_read(widget, user)

        expect(::Gitlab::WorkItems::Instrumentation::TrackingService).to have_received(:new).once
        expect(tracking_service).to have_received(:execute).once
      end

      it 'fires again when SafeRequestStore is inactive (no request boundary)' do
        described_class.track_agent_plan_read(widget, user)
        described_class.track_agent_plan_read(widget, user)

        expect(::Gitlab::WorkItems::Instrumentation::TrackingService).to have_received(:new).twice
      end

      context 'when there is no authenticated user' do
        before do
          described_class.track_agent_plan_read(widget, nil)
        end

        it 'does not fire a read event' do
          expect(::Gitlab::WorkItems::Instrumentation::TrackingService).not_to have_received(:new)
        end
      end
    end

    context 'when the agent plan has no content' do
      before do
        described_class.track_agent_plan_read(widget, user)
      end

      it 'does not fire a read event' do
        expect(::Gitlab::WorkItems::Instrumentation::TrackingService).not_to have_received(:new)
      end
    end

    context 'when the widget is nil' do
      before do
        described_class.track_agent_plan_read(nil, user)
      end

      it 'does not fire a read event' do
        expect(::Gitlab::WorkItems::Instrumentation::TrackingService).not_to have_received(:new)
      end
    end
  end
end

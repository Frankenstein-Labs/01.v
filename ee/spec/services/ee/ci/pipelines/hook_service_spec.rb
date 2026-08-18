# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Pipelines::HookService, feature_category: :continuous_integration do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:pipeline) { create(:ci_empty_pipeline, :created, project: project, user: user) }

  subject(:service) { described_class.new(pipeline) }

  describe '#execute' do
    let(:hook_data) { {} }
    let(:pipeline_source) { :push }

    before do
      allow(Gitlab::DataBuilder::Pipeline).to receive(:build).with(pipeline).and_return(hook_data)
      allow(pipeline).to receive(:source).and_return(pipeline_source)
    end

    it 'executes flow triggers' do
      expect_next_instance_of(
        Ai::FlowTriggers::EventTriggerService,
        project: project,
        current_user: user,
        event: described_class::HOOK_NAME,
        data: hook_data
      ) do |service|
        expect(service).to receive(:execute)
      end

      service.execute
    end

    ::Enums::Ci::Pipeline.gitlab_controlled_sources.each_key do |source|
      context "when pipeline is triggered by #{source}" do
        let(:pipeline_source) { source }

        it 'does not trigger AI Flows' do
          expect(Ai::FlowTriggers::EventTriggerService).not_to receive(:new)

          service.execute
        end
      end
    end

    context 'when project has active hooks' do
      let!(:hook) { create(:project_hook, project: project, pipeline_events: true) }

      it 'calls both parent execute and the flow trigger service' do
        expect(pipeline.project).to receive(:execute_hooks).with(hook_data, described_class::HOOK_NAME)
        expect_next_instance_of(
          Ai::FlowTriggers::EventTriggerService,
          project: project,
          current_user: user,
          event: described_class::HOOK_NAME,
          data: hook_data
        ) do |service|
          expect(service).to receive(:execute)
        end

        service.execute
      end
    end
  end
end

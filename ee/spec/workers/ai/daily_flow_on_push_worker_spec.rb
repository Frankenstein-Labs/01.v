# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DailyFlowOnPushWorker, feature_category: :duo_agent_platform do
  include ExclusiveLeaseHelpers

  subject(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:pusher) { create(:user) }

    let(:project_id) { project.id }
    let(:pusher_id) { pusher.id }
    let(:lease_key) { "sdlc_context_agent:#{project.id}" }

    subject(:perform) { worker.perform(project_id, pusher_id) }

    before do
      create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: group)
      stub_exclusive_lease(lease_key, timeout: 24.hours)
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'returns early without enqueuing anything' do
        expect(::Gitlab::ExclusiveLease).not_to receive(:new)

        perform
      end
    end

    context 'when pusher does not exist' do
      let(:pusher_id) { non_existing_record_id }

      it 'returns early without enqueuing anything' do
        expect(::Gitlab::ExclusiveLease).not_to receive(:new)

        perform
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(sdlc_context_agent_trigger: false)
      end

      it 'returns early without acquiring a lease' do
        expect(::Gitlab::ExclusiveLease).not_to receive(:new)

        perform
      end
    end

    context 'when duo_vulnerability_context_analysis_enabled is false' do
      before do
        project.project_setting.update!(duo_vulnerability_context_analysis_enabled: false)
      end

      it 'does not trigger the flow' do
        expect(Ai::FlowTriggers::RunService).not_to receive(:new)
        worker.perform(project.id, pusher.id)
      end
    end

    context 'when the pusher is not a human user' do
      before do
        allow(User).to receive(:find_by_id).with(pusher_id).and_return(pusher)
        allow(pusher).to receive(:human?).and_return(false)
      end

      it 'returns early without acquiring a lease' do
        expect(::Gitlab::ExclusiveLease).not_to receive(:new)

        perform
      end
    end

    context 'when no EnabledFoundationalFlow exists for the project ancestor namespaces' do
      before do
        ::Ai::Catalog::EnabledFoundationalFlow.delete_all
      end

      it 'returns early without acquiring a lease' do
        expect(::Gitlab::ExclusiveLease).not_to receive(:new)

        perform
      end
    end

    context 'when the exclusive lease is already held (debounce)' do
      before do
        stub_exclusive_lease_taken(lease_key, timeout: 24.hours)
      end

      it 'returns early without dispatching the flow' do
        expect { perform }.not_to raise_error
      end
    end

    context 'when the lease is acquired and a consumer exists' do
      let_it_be(:consumer) { create(:ai_catalog_item_consumer, :parent_item_consumer, group: group) }

      let(:run_service) { instance_double(Ai::FlowTriggers::RunService) }

      before do
        project.project_setting.update!(duo_vulnerability_context_analysis_enabled: true)
        allow(Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
        allow(run_service).to receive(:execute)
      end

      it 'instantiates RunService with the correct arguments' do
        perform

        expect(Ai::FlowTriggers::RunService).to have_received(:new).with(
          project: project,
          current_user: pusher,
          flow_trigger: an_instance_of(Ai::FlowTrigger),
          resource: nil
        )
      end

      it 'calls execute with input and event' do
        perform

        expect(run_service).to have_received(:execute).with(input: '', event: :commit_to_default_branch)
      end
    end

    context 'when the lease is acquired but no consumer exists' do
      before do
        project.project_setting.update!(duo_vulnerability_context_analysis_enabled: true)
      end

      it 'logs a warning and does not call RunService' do
        expect(Ai::FlowTriggers::RunService).not_to receive(:new)
        expect(Sidekiq.logger).to receive(:warn).with(
          hash_including(
            'message' => 'No item consumer found for project root ancestor, skipping.',
            'project_id' => project.id
          )
        )

        perform
      end
    end
  end
end

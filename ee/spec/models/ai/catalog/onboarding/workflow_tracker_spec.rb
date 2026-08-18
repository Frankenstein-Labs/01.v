# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Onboarding::WorkflowTracker, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }

  let(:tracker) { described_class.new(project) }
  let(:cache_key) { ['duo_agent_onboarding', 'improve_ci', project.id] }

  before do
    allow(Rails.cache).to receive(:read).and_call_original
  end

  describe '#track' do
    it 'writes the workflow id to the cache with a 7-day TTL' do
      workflow = build_stubbed(:duo_workflows_workflow, id: 99)

      expect(Rails.cache).to receive(:write).with(cache_key, 99, expires_in: 7.days)

      tracker.track('improve_ci', workflow)
    end
  end

  describe '#workflow_for' do
    context 'when nothing is tracked' do
      it 'returns nil' do
        expect(tracker.workflow_for('improve_ci')).to be_nil
      end
    end

    context 'when a workflow is tracked' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }

      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(workflow.id)
      end

      it 'returns the tracked workflow' do
        expect(tracker.workflow_for('improve_ci')).to eq(workflow)
      end
    end

    context 'when the cached workflow no longer exists' do
      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(non_existing_record_id)
      end

      it 'prunes the stale cache entry and returns nil', :aggregate_failures do
        expect(Rails.cache).to receive(:delete).with(cache_key)
        expect(tracker.workflow_for('improve_ci')).to be_nil
      end
    end
  end

  describe '#active_workflow' do
    before do
      allow(Rails.cache).to receive(:read).with(cache_key).and_return(workflow.id)
    end

    context 'when the tracked workflow is active' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, :running, project: project) }

      it 'returns the workflow' do
        expect(tracker.active_workflow('improve_ci')).to eq(workflow)
      end
    end

    context 'when the tracked workflow is no longer active' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, :failed, project: project) }

      it 'returns nil' do
        expect(tracker.active_workflow('improve_ci')).to be_nil
      end
    end
  end
end

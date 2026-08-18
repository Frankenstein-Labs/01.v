# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::SyncSessionArtifactWorker, feature_category: :duo_agent_platform do
  describe '#perform' do
    let_it_be(:workflow) { create(:duo_workflows_workflow) }

    subject(:perform) { described_class.new.perform(workflow_id) }

    context 'when workflow exists' do
      let(:workflow_id) { workflow.id }

      it 'syncs the session artifact' do
        expect(Ai::DuoWorkflows::SessionArtifact).to receive(:sync_from_workflow!).with(workflow)

        perform
      end
    end

    context 'when workflow does not exist' do
      let(:workflow_id) { non_existing_record_id }

      it 'does not sync' do
        expect(Ai::DuoWorkflows::SessionArtifact).not_to receive(:sync_from_workflow!)

        perform
      end
    end
  end
end

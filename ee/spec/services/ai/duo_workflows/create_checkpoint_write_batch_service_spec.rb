# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateCheckpointWriteBatchService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let(:workflow) { create(:duo_workflows_workflow, **container_params) }
    let(:container_params) { { project: project } }
    let(:task) { 'id2' }

    let(:params) do
      {
        thread_ts: 'checkpoint_id',
        checkpoint_writes: [
          { task: 'id1', idx: 0, channel: 'channel', write_type: 'type', data: 'data' },
          { task: task, idx: 0, channel: 'channel', write_type: 'type', data: 'data' }
        ]
      }
    end

    subject(:execute) do
      described_class.new(workflow: workflow, params: params).execute
    end

    it 'stores checkpoint writes' do
      expect { execute }.to change { Ai::DuoWorkflows::CheckpointWrite.count }.by(2)
      expect(execute).to be_success
      expect(Ai::DuoWorkflows::CheckpointWrite.distinct.pluck('project_id')).to eq([project.id])
    end

    context 'when namespace-level workflow' do
      let(:container_params) { { namespace: group } }

      it 'stores checkpoint writes' do
        expect { execute }.to change { Ai::DuoWorkflows::CheckpointWrite.count }.by(2)
        expect(execute).to be_success
        expect(Ai::DuoWorkflows::CheckpointWrite.distinct.pluck('namespace_id')).to eq([group.id])
      end
    end

    context 'with invalid params' do
      let(:task) { '' }

      it "doesn't store any writes" do
        expect { execute }.not_to change { Ai::DuoWorkflows::CheckpointWrite.count }
        expect(execute).to be_error.and have_attributes(message: "Validation failed: Task can't be blank")
      end
    end
  end
end

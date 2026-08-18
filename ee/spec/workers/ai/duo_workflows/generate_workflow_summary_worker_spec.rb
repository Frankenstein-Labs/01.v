# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::GenerateWorkflowSummaryWorker, feature_category: :duo_agent_platform do
  describe '#perform' do
    let_it_be(:project) { create(:project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
    let(:summary_service) { instance_double(Ai::DuoWorkflows::SummarizeWorkflowService) }

    subject(:perform) { described_class.new.perform(workflow.id) }

    context 'when workflow is not found' do
      it 'does not call SummarizeWorkflowService' do
        expect(Ai::DuoWorkflows::SummarizeWorkflowService).not_to receive(:new)

        described_class.new.perform(non_existing_record_id)
      end
    end

    context 'when the service returns a summary' do
      before do
        allow(Ai::DuoWorkflows::SummarizeWorkflowService).to receive(:new)
          .with(workflow: workflow)
          .and_return(summary_service)
        allow(summary_service).to receive(:execute).and_return('Workflow finished: created a merge request.')
      end

      it 'updates the workflow summary' do
        perform

        expect(workflow.reload.summary).to eq('Workflow finished: created a merge request.')
      end
    end

    context 'when the service returns a summary longer than 1024 characters' do
      let(:long_summary) { 'a' * 2000 }

      before do
        allow(Ai::DuoWorkflows::SummarizeWorkflowService).to receive(:new)
          .with(workflow: workflow)
          .and_return(summary_service)
        allow(summary_service).to receive(:execute).and_return(long_summary)
      end

      it 'truncates the summary to 1024 characters' do
        perform

        expect(workflow.reload.summary.length).to be <= 1024
      end
    end

    context 'when the service returns nil' do
      before do
        allow(Ai::DuoWorkflows::SummarizeWorkflowService).to receive(:new)
          .with(workflow: workflow)
          .and_return(summary_service)
        allow(summary_service).to receive(:execute).and_return(nil)
      end

      it 'does not update the workflow summary' do
        expect { perform }.not_to change { workflow.reload.summary }
      end
    end
  end
end

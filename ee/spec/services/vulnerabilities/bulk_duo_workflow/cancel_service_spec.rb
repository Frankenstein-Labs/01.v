# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflow::CancelService,
  :clean_gitlab_redis_shared_state,
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let(:workflow) { :sast_fp_detection }

  let(:stages) do
    [
      { name: 'critical', order: 0 },
      { name: 'high', order: 1 }
    ]
  end

  let!(:execution) do
    Vulnerabilities::BulkDuoWorkflow::ExecutionState.create!(
      project_id: project.id,
      workflow: workflow,
      stages: stages
    )
  end

  subject(:response) do
    described_class.new(
      project: project,
      workflow: workflow,
      current_user: current_user
    ).execute
  end

  before do
    allow(Ability).to receive(:allowed?)
                        .with(current_user, :execute_vulnerability_duo_workflow, project).and_return(true)

    execution.start!
    execution.append_to_stage!(stage: :critical, item_ids: [1, 2])
  end

  describe '#execute' do
    it 'cancels the execution', :aggregate_failures do
      expect(response).to be_success

      cancelled = response.payload[:execution]

      expect(response.message).to eq('Execution cancelled')
      expect(cancelled.status).to eq(:cancelled)
      expect(cancelled.snapshot[:cancel_requested]).to be(true)
      expect(cancelled.snapshot[:ended_at]).to be_present
    end

    context 'when cancellation does not succeed' do
      before do
        allow(Vulnerabilities::BulkDuoWorkflow::ExecutionState)
          .to receive(:current)
                .with(project_id: project.id, workflow: workflow)
                .and_return(execution)
      end

      it 'returns an error when the execution is already in a terminal state', :aggregate_failures do
        allow(execution).to receive(:cancel!).and_return(:completed)

        expect(response).to be_error
        expect(response.message).to eq('Execution already in terminal state')
        expect(response.reason).to eq(Vulnerabilities::BulkDuoWorkflow::BaseService::ERROR_REASONS[:terminal_state])
      end

      it 'returns an error when cancellation fails', :aggregate_failures do
        allow(execution).to receive(:cancel!).and_return(:unexpected)

        expect(response).to be_error
        expect(response.message).to eq('Unable to cancel execution')
        expect(response.reason).to eq(Vulnerabilities::BulkDuoWorkflow::BaseService::ERROR_REASONS[:cancel_failed])
      end
    end

    it_behaves_like 'returns not_found when there is no active execution'
  end
end

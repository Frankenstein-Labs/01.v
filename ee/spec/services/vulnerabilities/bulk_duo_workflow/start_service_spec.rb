# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflow::StartService,
  :clean_gitlab_redis_shared_state,
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let(:workflow) { 'sast_fp_detection/v1' }

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

  let(:relation) { double }

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

    execution.append_to_stage!(stage: :critical, item_ids: [1, 2, 3])
  end

  shared_examples 'starts execution and triggers workflow' do
    before do
      allow(worker).to receive(:perform_async)
    end

    it 'starts the execution and triggers the workflow', :aggregate_failures do
      expect(response).to be_success

      expect(response.message).to eq('Execution started')
      expect(response.payload[:execution].status).to eq(:running)
      expect(response.payload[:execution].snapshot[:started_at]).to be_present
      expect(response.payload[:execution].snapshot[:processing_ids]).to match_array(%w[1 2 3])
      expect(response.payload[:item_ids]).to match_array(%w[1 2 3])

      resolved_ids.each do |id|
        expect(worker).to have_received(:perform_async).with(id, execution.execution_id)
      end
    end
  end

  describe '#execute' do
    context 'with SAST FP detection workflow' do
      let(:workflow) { 'sast_fp_detection/v1' }
      let(:worker) { ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker }
      let(:resolved_ids) { [10, 20, 30] }

      before do
        allow(::Vulnerabilities::Finding).to receive(:by_uuid).with(%w[1 2 3]).and_return(relation)
        allow(relation).to receive(:pluck_vulnerability_ids).and_return(resolved_ids)
      end

      it_behaves_like 'starts execution and triggers workflow'

      it 'resolves vulnerability ids' do
        response

        expect(::Vulnerabilities::Finding).to have_received(:by_uuid).with(%w[1 2 3])
      end
    end

    context 'with Secret Detection FP workflow' do
      let(:workflow) { 'secrets_fp_detection/v1' }
      let(:worker) { ::Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker }
      let(:resolved_ids) { [10, 20, 30] }

      before do
        allow(::Vulnerabilities::Finding).to receive(:by_uuid).with(%w[1 2 3]).and_return(relation)
        allow(relation).to receive(:pluck_vulnerability_ids).and_return(resolved_ids)
      end

      it_behaves_like 'starts execution and triggers workflow'

      it 'resolves vulnerability ids' do
        response

        expect(::Vulnerabilities::Finding).to have_received(:by_uuid).with(%w[1 2 3])
      end
    end

    context 'with SAST resolution workflow' do
      let(:workflow) { 'resolve_sast_vulnerability/v1' }
      let(:worker) { ::Vulnerabilities::TriggerResolutionWorkflowWorker }
      let(:resolved_ids) { [100, 200, 300] }

      before do
        allow(::Vulnerabilities::Finding).to receive(:by_uuid).with(%w[1 2 3]).and_return(relation)
        allow(relation).to receive(:select).with(:id).and_return(relation)

        allow(::Vulnerabilities::Flag).to receive(:by_finding_id).with(relation).and_return(relation)
        allow(relation).to receive(:false_positive).and_return(relation)
        allow(relation).to receive(:pluck_with_limit).with(3, :id).and_return(resolved_ids)
      end

      it_behaves_like 'starts execution and triggers workflow'

      it 'resolves false positive flag ids' do
        response

        expect(::Vulnerabilities::Finding).to have_received(:by_uuid).with(%w[1 2 3])

        expect(relation).to have_received(:select).with(:id)

        expect(::Vulnerabilities::Flag).to have_received(:by_finding_id).with(relation)
        expect(relation).to have_received(:false_positive)
        expect(relation).to have_received(:pluck_with_limit).with(3, :id)
      end
    end

    context 'when start does not succeed' do
      before do
        allow(Vulnerabilities::BulkDuoWorkflow::ExecutionState)
          .to receive(:current)
                .with(project_id: project.id, workflow: workflow)
                .and_return(execution)
      end

      context 'when the execution is already running' do
        before do
          allow(execution).to receive(:start!)
                                .and_return(Vulnerabilities::BulkDuoWorkflow::ExecutionState::STATUS_ALREADY_RUNNING)
        end

        it 'returns an already started error' do
          expect(response).to be_error
          expect(response.message).to eq('Execution already started')
          expect(response.reason).to eq(Vulnerabilities::BulkDuoWorkflow::BaseService::ERROR_REASONS[:already_started])
        end
      end

      context 'when the execution is in an invalid state' do
        before do
          allow(execution).to receive(:start!)
                                .and_return(Vulnerabilities::BulkDuoWorkflow::ExecutionState::RESULT_INVALID)
        end

        it 'returns an invalid state error' do
          expect(response).to be_error
          expect(response.message).to eq('Execution cannot be started')
          expect(response.reason).to eq(Vulnerabilities::BulkDuoWorkflow::BaseService::ERROR_REASONS[:invalid_state])
        end
      end

      context 'when starting the execution fails' do
        before do
          allow(execution).to receive(:start!).and_return(:unexpected)
        end

        it 'returns a start failed error' do
          expect(response).to be_error
          expect(response.message).to eq('Unable to start execution')
          expect(response.reason).to eq(Vulnerabilities::BulkDuoWorkflow::BaseService::ERROR_REASONS[:start_failed])
        end
      end
    end

    it_behaves_like 'returns not_found when there is no active execution'
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker, feature_category: :static_application_security_testing do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be_with_reload(:vulnerability) { create(:vulnerability, :with_finding, project: project, author: user) }

  let(:worker) { described_class.new }
  let(:vulnerability_id) { vulnerability.id }
  let(:workflow_definition) { 'sast_fp_detection/v1' }

  describe '#perform' do
    let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project, environment: :web) }
    let(:execute_service) { instance_double(::Ai::Catalog::Flows::ExecuteService) }
    let(:service_result) { ServiceResponse.success(payload: { workflow: workflow, workload_id: 456 }) }
    let_it_be(:consumer) { create(:ai_catalog_item_consumer, project: project) }
    let_it_be(:service_account) { build_stubbed(:user, :service_account) }

    before do
      project.project_setting.update!(duo_sast_fp_detection_enabled: true)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :duo_workflow, anything).and_return(true)
      allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
        instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [consumer])
      )
      allow(worker).to receive(:find_service_account).and_return(service_account)
      allow(::Ai::Catalog::Flows::ExecuteService).to receive(:new).and_return(execute_service)
      allow(execute_service).to receive(:execute).and_return(service_result)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [vulnerability_id] }
    end

    context 'when vulnerability exist' do
      it 'finds the consumer with the vulnerability author as current_user' do
        expect(::Ai::Catalog::ItemConsumersFinder).to receive(:new).with(
          user,
          params: {
            project_id: project.id,
            item_type: Ai::Catalog::Item::FLOW_TYPE,
            foundational_flow_reference: workflow_definition
          }
        )

        worker.perform(vulnerability_id)
      end

      it 'creates and executes the flow service with the vulnerability author as current_user' do
        expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: user,
          params: {
            item_consumer: consumer,
            service_account: service_account,
            execute_workflow: true,
            event_type: 'sidekiq_worker',
            user_prompt: vulnerability_id.to_s
          }
        )

        worker.perform(vulnerability_id)
      end

      context 'when no eligible user is found' do
        before do
          allow(worker).to receive(:resolve_workflow_user).and_return(nil)
        end

        it 'logs error and returns early' do
          expect(Gitlab::AppLogger).to receive(:error).with(
            hash_including(message: match(/No eligible user found/))
          )
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

          worker.perform(vulnerability_id)
        end
      end

      context 'when consumer has parent item consumer with service account' do
        let(:group) { create(:group) }
        let(:project_with_group) { create(:project, group: group) }

        let(:vulnerability_with_group) do
          create(:vulnerability, :with_finding, project: project_with_group, author: user)
        end

        let(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
        let(:flow_item) { create(:ai_catalog_flow, :public) }
        let!(:parent_consumer) do
          create(:ai_catalog_item_consumer, group: group, item: flow_item, service_account: service_account)
        end

        let(:consumer) do
          Ai::Catalog::ItemConsumer.create!(
            project: project_with_group,
            item: flow_item,
            parent_item_consumer: parent_consumer
          )
        end

        before do
          project_with_group.project_setting.update!(duo_sast_fp_detection_enabled: true)
        end

        it 'uses service account from parent consumer' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project_with_group,
            current_user: user,
            params: {
              item_consumer: consumer,
              service_account: service_account,
              execute_workflow: true,
              event_type: 'sidekiq_worker',
              user_prompt: vulnerability_with_group.id.to_s
            }
          )

          worker.perform(vulnerability_with_group.id)
        end
      end

      context 'when consumer is group-level with service account' do
        let(:group) { create(:group) }
        let(:project_with_group) { create(:project, group: group) }
        let(:vulnerability_with_group) do
          create(:vulnerability, :with_finding, project: project_with_group, author: user)
        end

        let(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
        let(:flow_item) { create(:ai_catalog_flow, :public) }
        let(:consumer) do
          create(:ai_catalog_item_consumer, group: group, item: flow_item, service_account: service_account)
        end

        before do
          project_with_group.project_setting.update!(duo_sast_fp_detection_enabled: true)
        end

        it 'uses service account from consumer' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project_with_group,
            current_user: user,
            params: {
              item_consumer: consumer,
              service_account: service_account,
              execute_workflow: true,
              event_type: 'sidekiq_worker',
              user_prompt: vulnerability_with_group.id.to_s
            }
          )

          worker.perform(vulnerability_with_group.id)
        end
      end

      context 'when workflow service succeeds' do
        it 'creates a triggered workflow record with correct attributes' do
          expect { worker.perform(vulnerability_id) }
            .to change { ::Vulnerabilities::TriggeredWorkflow.count }.by(1)

          triggered_workflow = ::Vulnerabilities::TriggeredWorkflow.last
          expect(triggered_workflow.vulnerability_occurrence).to eq(vulnerability.finding)
          expect(triggered_workflow.workflow_id).to eq(workflow.id)
          expect(triggered_workflow.workflow_name).to eq('sast_fp_detection')
        end

        it 'tracks the internal event' do
          expect(worker).to receive(:track_internal_event).with(
            'trigger_sast_vulnerability_fp_detection_workflow',
            project: project,
            additional_properties: {
              label: 'automatic',
              value: vulnerability_id,
              property: vulnerability.severity
            }
          )

          worker.perform(vulnerability_id)
        end

        it 'does not log any errors' do
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_id)
        end

        context 'when creation of triggered workflow fails' do
          let_it_be(:other_project) { create(:project) }
          let(:other_workflow) do
            create(:duo_workflows_workflow, user: user, project: other_project, environment: :web)
          end

          let(:service_result) do
            ServiceResponse.success(payload: { workflow_id: other_workflow.id, workload_id: 456 })
          end

          it 'logs error message and sends to Sentry' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              an_instance_of(ActiveRecord::RecordInvalid),
              vulnerability_id: vulnerability.id,
              workflow_id: other_workflow.id
            )

            worker.perform(vulnerability_id)
          end
        end
      end

      context 'when consumer is not found' do
        before do
          allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
            instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [])
          )
        end

        it 'logs info and returns early without calling the execute service' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

          expect(Gitlab::AppLogger).to receive(:info).with(
            message: 'SAST false positive detection workflow not configured for project',
            vulnerability_id: vulnerability.id,
            project_id: project.id
          )

          worker.perform(vulnerability_id)
        end
      end

      context 'when service account is not found' do
        before do
          allow(worker).to receive(:find_service_account).and_return(nil)
        end

        it 'logs an error' do
          expect(Gitlab::AppLogger).to receive(:error).with(
            message: 'Service account not found for SAST false positive detection workflow, ' \
              'the service account may have been deleted',
            vulnerability_id: vulnerability.id,
            project_id: vulnerability.project_id,
            consumer_id: consumer.id,
            workflow_definition: 'sast_fp_detection/v1'
          )

          worker.perform(vulnerability_id)
        end

        it 'does not call ExecuteService' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

          worker.perform(vulnerability_id)
        end

        it 'does not create a triggered workflow record' do
          expect { worker.perform(vulnerability_id) }.not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
        end

        it 'does not track the internal event' do
          expect(worker).not_to receive(:track_internal_event)

          worker.perform(vulnerability_id)
        end
      end

      context 'when workflow service fails' do
        let(:service_result) do
          ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
        end

        it 'logs error message and raise StartWorkflowServiceError' do
          expect(Gitlab::AppLogger).to receive(:error).with(
            message: 'Failed to call SAST workflow service for vulnerability',
            vulnerability_id: vulnerability.id,
            project_id: project.id,
            error: 'Workflow creation failed',
            reason: :invalid_params
          )

          expect { worker.perform(vulnerability_id) }
            .to raise_error(Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError)
        end

        it 'does not create a triggered workflow record' do
          expect do
            expect { worker.perform(vulnerability.id) }.to raise_error(
              Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
            )
          end.not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
        end

        it 'does not track the event' do
          expect(worker).not_to receive(:track_internal_event)

          expect { worker.perform(vulnerability_id) }
            .to raise_error(Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError)
        end
      end
    end

    context 'when vulnerability does not exist' do
      let(:vulnerability_id) { non_existing_record_id }

      it 'returns early without calling the workflow service' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
        expect(Gitlab::AppLogger).not_to receive(:error)

        worker.perform(vulnerability_id)
      end
    end

    context 'when the project has SAST false positive detection disabled' do
      before do
        project.project_setting.update!(duo_sast_fp_detection_enabled: false)
      end

      it 'logs and returns early without calling the workflow service' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'Vulnerability not eligible for SAST false positive detection workflow',
          vulnerability_id: vulnerability.id,
          project_id: project.id
        )

        expect { worker.perform(vulnerability_id) }
          .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
      end
    end

    context 'when the vulnerability is not a SAST report type' do
      before do
        vulnerability.update!(report_type: :dependency_scanning)
      end

      it 'returns early without calling the workflow service' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        expect { worker.perform(vulnerability_id) }
          .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
      end
    end

    context 'when the vulnerability severity is below high' do
      before do
        vulnerability.update!(severity: :low)
      end

      it 'still dispatches, leaving the severity floor to the caller' do
        expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new)

        worker.perform(vulnerability_id)
      end
    end

    context 'when workflow service raises an exception' do
      let(:error) { StandardError.new('Service error') }

      before do
        allow(execute_service).to receive(:execute).and_raise(error)
      end

      it 'logs and raises the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_and_raise_exception).with(
          error,
          vulnerability_id: vulnerability_id
        )

        worker.perform(vulnerability_id)
      end
    end

    context 'with workflow tracking' do
      subject(:perform) { worker.perform(item_id, execution_id) }

      it_behaves_like 'a workflow trackable worker', next_item_id: -> { vulnerability.id } do
        let(:item_id) { vulnerability.id }
        let(:finding) { vulnerability.finding }
      end
    end
  end
end

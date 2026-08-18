# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggerResolutionWorkflowWorker, feature_category: :static_application_security_testing do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project, author: user) }
  let_it_be(:finding) { create(:vulnerabilities_finding, project: project, vulnerability: vulnerability) }
  let_it_be(:triggered_fp_workflow) do
    create(:vulnerability_triggered_workflow, vulnerability_occurrence: finding,
      workflow: create(:duo_workflows_workflow, project: project, user: user))
  end

  let_it_be_with_reload(:vulnerability_flag) do
    create(:vulnerabilities_flag, finding: finding, confidence_score: 0.5,
      status: :failed, origin: Vulnerabilities::Flag::AI_SAST_FP_DETECTION_ORIGIN)
  end

  let(:worker) { described_class.new }
  let(:vulnerability_flag_id) { vulnerability_flag.id }
  let(:workflow_definition) { 'resolve_sast_vulnerability/v1' }

  describe '#perform' do
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:execute_service) { instance_double(::Ai::Catalog::Flows::ExecuteService) }
    let(:service_result) { ServiceResponse.success(payload: { workflow: workflow, workload_id: 456 }) }
    let_it_be(:consumer) { create(:ai_catalog_item_consumer, project: project) }
    let_it_be(:service_account) { build_stubbed(:user, :service_account) }

    before do
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
      let(:job_args) { [vulnerability_flag_id] }
    end

    context 'when vulnerability flag exists' do
      context 'when confidence score is below threshold' do
        before do
          vulnerability_flag.update!(confidence_score: 0.5)
        end

        context 'when duo_sast_vr_workflow_enabled is enabled' do
          before do
            project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
          end

          context 'when duo_sast_vr_workflow_enabled is disabled' do
            before do
              project.project_setting.update!(duo_sast_vr_workflow_enabled: false)
            end

            it 'returns early without calling the workflow service' do
              expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
              expect(Gitlab::AppLogger).not_to receive(:error)

              worker.perform(vulnerability_flag_id)
            end
          end

          it 'finds the consumer with the vulnerability author as current_user' do
            expect(::Ai::Catalog::ItemConsumersFinder).to receive(:new).with(
              user,
              params: {
                project_id: project.id,
                item_type: Ai::Catalog::Item::FLOW_TYPE,
                foundational_flow_reference: workflow_definition
              }
            )

            worker.perform(vulnerability_flag_id)
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
                user_prompt: vulnerability.id.to_s
              }
            )

            worker.perform(vulnerability_flag_id)
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

              worker.perform(vulnerability_flag_id)
            end
          end

          context 'when consumer has parent item consumer with service account' do
            let(:group) { create(:group) }
            let(:project_with_group) { create(:project, group: group) }

            let(:vulnerability_with_group) do
              create(:vulnerability, :with_finding, project: project_with_group, author: user)
            end

            let(:vulnerability_flag_with_group) do
              create(:vulnerabilities_flag, finding: vulnerability_with_group.finding, confidence_score: 0.5,
                status: :failed, origin: Vulnerabilities::Flag::AI_SAST_FP_DETECTION_ORIGIN)
            end

            let!(:triggered_fp_workflow_with_group) do
              create(:vulnerability_triggered_workflow, vulnerability_occurrence: vulnerability_with_group.finding,
                workflow: create(:duo_workflows_workflow, project: project_with_group, user: user))
            end

            let(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
            let_it_be(:flow_item) { create(:ai_catalog_flow, :public) }
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
              project_with_group.project_setting.update!(duo_sast_vr_workflow_enabled: true)
              allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
                instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [consumer])
              )
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

              worker.perform(vulnerability_flag_with_group.id)
            end
          end

          context 'when consumer is group-level with service account' do
            let(:group) { create(:group) }
            let(:project_with_group) { create(:project, group: group) }
            let(:vulnerability_with_group) do
              create(:vulnerability, :with_finding, project: project_with_group, author: user)
            end

            let(:vulnerability_flag_with_group) do
              create(:vulnerabilities_flag, finding: vulnerability_with_group.finding, confidence_score: 0.5,
                status: :failed, origin: Vulnerabilities::Flag::AI_SAST_FP_DETECTION_ORIGIN)
            end

            let!(:triggered_fp_workflow_with_group) do
              create(:vulnerability_triggered_workflow, vulnerability_occurrence: vulnerability_with_group.finding,
                workflow: create(:duo_workflows_workflow, project: project_with_group, user: user))
            end

            let(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
            let_it_be(:flow_item) { create(:ai_catalog_flow, :public) }
            let(:consumer) do
              create(:ai_catalog_item_consumer, group: group, item: flow_item, service_account: service_account)
            end

            before do
              project_with_group.project_setting.update!(duo_sast_vr_workflow_enabled: true)
              allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
                instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [consumer])
              )
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

              worker.perform(vulnerability_flag_with_group.id)
            end
          end

          context 'when workflow service succeeds' do
            it 'creates a triggered workflow record' do
              expect do
                worker.perform(vulnerability_flag_id)
              end.to change { Vulnerabilities::TriggeredWorkflow.count }.by(1)
            end

            it 'creates triggered workflow with correct attributes' do
              worker.perform(vulnerability_flag_id)

              triggered_workflow = Vulnerabilities::TriggeredWorkflow.last
              expect(triggered_workflow).to be_present
              expect(triggered_workflow.vulnerability_occurrence_id).to eq(finding.id)
              expect(triggered_workflow.workflow_id).to eq(workflow.id)
              expect(triggered_workflow.workflow_name).to eq("resolve_sast_vulnerability")
            end

            it 'tracks the internal event' do
              expect { worker.perform(vulnerability_flag_id) }
                .to trigger_internal_events('trigger_sast_vulnerability_resolution_workflow')
                      .with(project: project,
                        additional_properties: {
                          label: 'automatic',
                          value: vulnerability.id,
                          property: vulnerability.severity
                        }
                      )
                      .and increment_usage_metrics('counts.count_total_trigger_sast_vulnerability_resolution_workflow')
            end

            context 'when workflow is nil in response' do
              let(:service_result) { ServiceResponse.success(payload: { workflow: nil, workload_id: 456 }) }

              it 'does not create a triggered workflow record' do
                expect do
                  worker.perform(vulnerability_flag_id)
                end.not_to change { Vulnerabilities::TriggeredWorkflow.count }
              end

              it 'does not track the event' do
                expect { worker.perform(vulnerability_flag_id) }
                  .not_to trigger_internal_events('trigger_sast_vulnerability_resolution_workflow')
              end
            end

            context 'when creating triggered workflow record fails' do
              let(:error) { ActiveRecord::RecordInvalid.new }

              before do
                allow(Vulnerabilities::TriggeredWorkflow).to receive(:create!).and_raise(error)
              end

              it 'tracks the exception to error tracking' do
                expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                  error,
                  vulnerability_id: finding.vulnerability_id,
                  workflow_id: workflow.id
                )

                worker.perform(vulnerability_flag_id)
              end

              it 'does not raise the exception' do
                expect { worker.perform(vulnerability_flag_id) }.not_to raise_error
              end

              it 'does not track the event' do
                expect { worker.perform(vulnerability_flag_id) }
                  .not_to trigger_internal_events('trigger_sast_vulnerability_resolution_workflow')
              end
            end
          end

          context 'when no consumer is found' do
            before do
              allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
                instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [])
              )
            end

            it 'logs error message' do
              expect(Gitlab::AppLogger).to receive(:error).with(
                message: 'No consumer configured for vulnerability resolution workflow',
                finding_id: finding.id,
                project_id: finding.project_id,
                workflow_definition: 'resolve_sast_vulnerability/v1'
              )

              worker.perform(vulnerability_flag_id)
            end

            it 'returns early without calling trigger_workflow' do
              expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

              worker.perform(vulnerability_flag_id)
            end
          end

          context 'when service account is not found' do
            before do
              allow(worker).to receive(:find_service_account).and_return(nil)
            end

            it 'logs an error' do
              expect(Gitlab::AppLogger).to receive(:error).with(
                message: 'Service account not found for vulnerability resolution workflow, ' \
                  'the service account may have been deleted',
                vulnerability_id: vulnerability.id,
                project_id: vulnerability.project_id,
                consumer_id: consumer.id,
                workflow_definition: 'resolve_sast_vulnerability/v1'
              )

              worker.perform(vulnerability_flag_id)
            end

            it 'does not call ExecuteService' do
              expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

              worker.perform(vulnerability_flag_id)
            end

            it 'does not create a triggered workflow record' do
              expect { worker.perform(vulnerability_flag_id) }
                .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
            end

            it 'does not track the internal event' do
              expect(worker).not_to receive(:track_internal_event)

              worker.perform(vulnerability_flag_id)
            end
          end

          context 'when workflow service fails' do
            let(:service_result) do
              ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
            end

            it 'logs error message with failure details and raises exception' do
              expect(Gitlab::AppLogger).to receive(:error).with(
                message: 'Failed to create and start workflow for vulnerability resolution',
                vulnerability_flag_id: vulnerability_flag.id,
                finding_id: finding.id,
                error: 'Workflow creation failed',
                reason: :invalid_params
              )

              expect { worker.perform(vulnerability_flag_id) }.to raise_error(
                described_class::StartWorkflowServiceError,
                'Failed to start workflow for vulnerability resolution: Workflow creation failed'
              )
            end

            it 'does not create a triggered workflow record' do
              expect do
                worker.perform(vulnerability_flag_id)
              rescue StandardError
                described_class::StartWorkflowServiceError
              end.not_to change { Vulnerabilities::TriggeredWorkflow.count }
            end

            it 'does not track the event' do
              expect(worker).not_to receive(:track_internal_event)

              expect { worker.perform(vulnerability_flag_id) }.to raise_error(
                described_class::StartWorkflowServiceError
              )
            end
          end
        end
      end

      context 'when confidence score is at threshold' do
        before do
          project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
          vulnerability_flag.update!(confidence_score: 0.6)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_flag_id)
        end
      end

      context 'when confidence score is above threshold' do
        before do
          project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
          vulnerability_flag.update!(confidence_score: 0.8)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_flag_id)
        end
      end

      context 'when the flag is not eligible for the resolution workflow' do
        before do
          project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
          vulnerability_flag.update!(origin: 'post analyzer X')
        end

        it 'returns early without dispatching, even with the setting on and confidence below threshold' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

          expect { worker.perform(vulnerability_flag_id) }
            .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
        end
      end
    end

    context 'when vulnerability flag does not exist' do
      let(:vulnerability_flag_id) { non_existing_record_id }

      it 'returns early without calling the workflow service' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
        expect(Gitlab::AppLogger).not_to receive(:error)

        worker.perform(vulnerability_flag_id)
      end
    end

    context 'when trigger_workflow raises an exception' do
      let(:error) { StandardError.new('Service error') }

      before do
        vulnerability_flag.update!(confidence_score: 0.5)
        project.project_setting.update!(duo_sast_vr_workflow_enabled: true)
        allow(::Ai::Catalog::Flows::ExecuteService).to receive(:new).and_raise(error)
      end

      it 'logs and raises the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_and_raise_exception).with(
          error,
          vulnerability_flag_id: vulnerability_flag_id
        ).and_call_original

        expect { worker.perform(vulnerability_flag_id) }.to raise_error(error)
      end
    end

    context 'with workflow tracking' do
      subject(:perform) { worker.perform(item_id, execution_id) }

      it_behaves_like 'a workflow trackable worker', next_item_id: -> { vulnerability_flag.id } do
        let(:item_id) { vulnerability_flag.id }
        let(:finding) { vulnerability_flag.finding }
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker, feature_category: :vulnerability_management do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be_with_reload(:vulnerability) do
    create(:vulnerability, :with_finding, report_type: :secret_detection, project: project, author: user)
  end

  let(:worker) { described_class.new }
  let(:vulnerability_id) { vulnerability.id }
  let(:workflow_definition) { 'secrets_fp_detection/v1' }

  describe '#perform' do
    let(:workflow) { create(:duo_workflows_workflow, user: user, project: project, environment: :web) }
    let(:execute_service) { instance_double(::Ai::Catalog::Flows::ExecuteService) }
    let(:service_result) do
      ServiceResponse.success(payload: { workflow: workflow, workflow_id: workflow.id, workload_id: 456 })
    end

    let(:consumer) { create(:ai_catalog_item_consumer, project: project) }
    let_it_be(:service_account) { build_stubbed(:user, :service_account) }

    before do
      project.project_setting.update!(duo_secret_detection_fp_enabled: true)
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
      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(duo_secret_detection_false_positive: false)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_id)
        end
      end

      context 'when the project has secret detection false positive detection disabled' do
        before do
          project.project_setting.update!(duo_secret_detection_fp_enabled: false)
        end

        it 'logs and returns early without calling the workflow service' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
          expect(Gitlab::AppLogger).to receive(:info).with(
            message: 'Vulnerability not eligible for secret detection false positive detection workflow',
            vulnerability_id: vulnerability.id,
            project_id: project.id,
            workflow_definition: workflow_definition
          )

          expect { worker.perform(vulnerability_id) }
            .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
        end
      end

      context 'when the vulnerability is not a secret detection report type' do
        before do
          vulnerability.update!(report_type: :sast)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

          expect { worker.perform(vulnerability_id) }
            .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
        end
      end

      context 'when feature flag is enabled' do
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
              user_prompt: vulnerability_id.to_s,
              additional_context: []
            }
          )

          worker.perform(vulnerability_id)
        end

        context 'when the finding has a raw secret value' do
          let(:raw_secret) { 'sk_live_abc123' }
          let(:vulnerability) do
            create(:vulnerability, report_type: :secret_detection, project: project, author: user).tap do |v|
              create(:vulnerabilities_finding, :identifier,
                vulnerability: v,
                report_type: :secret_detection,
                project: project,
                raw_metadata: { 'raw_source_code_extract' => raw_secret }.to_json)
            end
          end

          it 'passes the raw secret via additional_context' do
            expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
              project: project,
              current_user: user,
              params: hash_including(
                additional_context: [{
                  category: 'secret_detection_context',
                  content: %({"secret_value":"#{raw_secret}"})
                }]
              )
            )

            worker.perform(vulnerability.id)
          end
        end

        context 'when the finding has no token value' do
          let(:vulnerability) do
            create(:vulnerability, report_type: :secret_detection, project: project, author: user).tap do |v|
              create(:vulnerabilities_finding, :identifier,
                vulnerability: v,
                report_type: :secret_detection,
                project: project,
                raw_metadata: {}.to_json)
            end
          end

          it 'sends an empty additional_context' do
            expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
              project: project,
              current_user: user,
              params: hash_including(additional_context: [])
            )

            worker.perform(vulnerability.id)
          end
        end

        context 'when the finding has a blank token value' do
          let(:vulnerability) do
            create(:vulnerability, report_type: :secret_detection, project: project, author: user).tap do |v|
              create(:vulnerabilities_finding, :identifier,
                vulnerability: v,
                report_type: :secret_detection,
                project: project,
                raw_metadata: { 'raw_source_code_extract' => '   ' }.to_json)
            end
          end

          it 'sends an empty additional_context' do
            expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
              project: project,
              current_user: user,
              params: hash_including(additional_context: [])
            )

            worker.perform(vulnerability.id)
          end
        end

        context 'when the finding secret is redacted' do
          let(:vulnerability) do
            create(:vulnerability, report_type: :secret_detection, project: project, author: user).tap do |v|
              create(:vulnerabilities_finding, :identifier,
                vulnerability: v,
                report_type: :secret_detection,
                project: project,
                raw_metadata: { 'raw_source_code_extract' => 'sk_live_secret123' }.to_json)
              create(:vulnerability_representation_information, vulnerability: v, removed_from_code: true)
            end
          end

          it 'sends an empty additional_context' do
            expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
              project: project,
              current_user: user,
              params: hash_including(additional_context: [])
            )

            worker.perform(vulnerability.id)
          end
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
          let_it_be(:group) { create(:group) }
          let_it_be(:project_with_group) { create(:project, group: group) }

          let(:vulnerability_with_group) do
            create(:vulnerability, :with_finding, report_type: :secret_detection, project: project_with_group,
              author: user)
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
            project_with_group.project_setting.update!(duo_secret_detection_fp_enabled: true)
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
                user_prompt: vulnerability_with_group.id.to_s,
                additional_context: []
              }
            )

            worker.perform(vulnerability_with_group.id)
          end
        end

        context 'when no consumer is found' do
          before do
            allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
              instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [])
            )
          end

          it 'logs info message' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              message: 'No consumer found for secret detection false positive detection workflow, ' \
                'setting is not enabled for this project',
              vulnerability_id: vulnerability.id,
              project_id: vulnerability.project_id,
              workflow_definition: 'secrets_fp_detection/v1'
            )

            worker.perform(vulnerability_id)
          end

          it 'returns early without calling the workflow service' do
            expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

            worker.perform(vulnerability_id)
          end
        end

        context 'when service account is not found' do
          before do
            allow(worker).to receive(:find_service_account).and_return(nil)
          end

          it 'logs an error' do
            expect(Gitlab::AppLogger).to receive(:error).with(
              message: 'Service account not found for secret detection false positive detection workflow, ' \
                'the service account may have been deleted',
              vulnerability_id: vulnerability.id,
              project_id: vulnerability.project_id,
              consumer_id: consumer.id,
              workflow_definition: 'secrets_fp_detection/v1'
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

        context 'when workflow service succeeds' do
          it 'creates a triggered workflow record with correct attributes' do
            expect { worker.perform(vulnerability_id) }
              .to change { ::Vulnerabilities::TriggeredWorkflow.count }.by(1)

            triggered_workflow = ::Vulnerabilities::TriggeredWorkflow.last
            expect(triggered_workflow.vulnerability_occurrence).to eq(vulnerability.finding)
            expect(triggered_workflow.workflow_id).to eq(workflow.id)
            expect(triggered_workflow.workflow_name).to eq('secrets_fp_detection')
          end

          it 'tracks the internal event' do
            expect { worker.perform(vulnerability_id) }
              .to trigger_internal_events(
                'trigger_secret_detection_vulnerability_fp_detection_workflow'
              ).with(
                project: project,
                additional_properties: {
                  label: 'automatic',
                  value: vulnerability_id,
                  property: vulnerability.severity
                }
              )
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

          context 'when vulnerability has no finding' do
            let_it_be(:vulnerability_without_finding) do
              create(:vulnerability, report_type: :secret_detection, project: project, author: user)
            end

            it 'attempts to create a triggered workflow but fails validation due to missing finding' do
              expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                an_instance_of(ActiveRecord::RecordInvalid),
                vulnerability_id: vulnerability_without_finding.id,
                workflow_id: workflow.id
              )

              expect { worker.perform(vulnerability_without_finding.id) }
                .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
            end
          end
        end

        context 'when workflow service fails' do
          let(:service_result) do
            ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
          end

          it 'logs error message and raise StartWorkflowServiceError' do
            expect(Gitlab::AppLogger).to receive(:error).with(
              message: 'Failed to call Secret Detection workflow service for vulnerability',
              vulnerability_id: vulnerability.id,
              project_id: project.id,
              error: 'Workflow creation failed',
              reason: :invalid_params
            )

            expect { worker.perform(vulnerability_id) }
              .to raise_error(
                Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
              )
          end

          it 'does not create a triggered workflow record' do
            expect do
              expect { worker.perform(vulnerability.id) }.to raise_error(
                Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
              )
            end.not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
          end

          it 'does not track the event' do
            expect { worker.perform(vulnerability_id) }
              .to raise_error(
                Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
              ).and not_trigger_internal_events(
                'trigger_secret_detection_vulnerability_fp_detection_workflow'
              )
          end
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

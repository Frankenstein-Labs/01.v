# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteService, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be_with_reload(:developer) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:flow_owner_project) { create(:project, group: group, developers: developer) }
  let_it_be_with_reload(:flow) { create(:ai_catalog_flow, :public, project: flow_owner_project) }
  let_it_be(:user_prompt) { nil }
  let_it_be_with_reload(:another_project) { create(:project, group: group) }
  let_it_be_with_reload(:item_enabled_project) { create(:project, :repository, group: group, developers: developer) }
  let_it_be_with_reload(:service_account) { create(:user, :service_account) }
  let_it_be_with_reload(:flow_version) do
    item_version = flow.latest_version
    item_version.update!(release_date: 1.hour.ago)
    item_version
  end

  let(:ai_catalog_item_consumer) do
    create(:ai_catalog_item_consumer, item: flow, project: item_enabled_project, pinned_version_prefix: nil)
  end

  let(:service_params) do
    {
      item_consumer: ai_catalog_item_consumer,
      event_type: 'manual',
      execute_workflow: true,
      user_prompt: user_prompt,
      service_account: service_account
    }
  end

  let(:expected_flow_config) do
    flow_version.definition.except('yaml_definition')
  end

  let(:current_user) { developer }
  let(:project) { ai_catalog_item_consumer.project }

  let(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      params: service_params
    )
  end

  before_all do
    item_enabled_project.add_member(service_account, Gitlab::Access::DEVELOPER)
  end

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returns error response' do |expected_message|
      it 'returns an error service response' do
        result = execute

        expect(result).to be_error
        expect(result.message).to match_array(expected_message)
      end
    end

    context 'when user lack permission' do
      let(:current_user) { create(:user).tap { |user| item_enabled_project.add_reporter(user) } }

      it_behaves_like 'returns error response', 'You have insufficient permissions'

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it_behaves_like 'returns error response', 'You have insufficient permissions'
      end

      context 'when the catalog item is not accessible to the project' do
        let(:project) { another_project }

        before do
          project.add_maintainer(current_user)
        end

        it_behaves_like 'returns error response', 'You have insufficient permissions'
      end
    end

    context 'when item_consumer is nil' do
      let(:service_params) { super().merge({ item_consumer: nil }) }

      it_behaves_like 'returns error response', 'Item consumer is required'
    end

    context 'when item_consumer is not associated with a flow' do
      before do
        allow(ai_catalog_item_consumer).to receive(:item).and_return(nil)
      end

      it_behaves_like 'returns error response', 'Item consumer must be associated with a flow'
    end

    context 'when item_consumer is associated with an agent instead of a flow' do
      before do
        ai_catalog_item_consumer.update!(item: create(:ai_catalog_agent))
      end

      it_behaves_like 'returns error response', 'Item must be a flow type'
    end

    context 'when flow version cannot be resolved from the pinned version' do
      before do
        ai_catalog_item_consumer.update!(pinned_version_prefix: '99.99.99')
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it_behaves_like 'returns error response', 'You have insufficient permissions'
    end

    context 'when flow version is in draft state' do
      before do
        allow(flow).to receive(:resolve_version).and_return(flow_version)
        allow(flow_version).to receive(:release_date).and_return(nil)
      end

      it_behaves_like 'returns error response', 'You have insufficient permissions'
    end

    context 'when event_type is nil' do
      let(:service_params) { super().merge({ event_type: nil }) }

      it_behaves_like 'returns error response', 'Trigger event type is required'
    end

    context 'when execute_workflow is false' do
      let(:service_params) { super().merge({ execute_workflow: false }) }

      it_behaves_like 'prevents CI pipeline creation for Duo Workflow' do
        subject { execute }
      end

      it 'does not call execute_workflow_service' do
        expect(::Ai::Catalog::ExecuteWorkflowService).not_to receive(:new)

        result = execute
        parsed_yaml = YAML.safe_load(result.payload[:flow_config], aliases: true)

        expect(result).to be_success
        expect(parsed_yaml).to eq(expected_flow_config)
      end

      it_behaves_like 'initializes Ai::Catalog::Logger but does not log to it' do
        subject { execute }
      end
    end

    context 'when flow is properly executed' do
      let(:oauth_token) do
        { oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: '***********') }
      end

      let(:workflow_service_token) do
        { token: 'workflow_token', expires_at: 1.hour.from_now }
      end

      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog_flows).and_return(true)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
        project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
        allow_next_instance_of(Ai::UsageQuotaService) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.success
          )
        end

        allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
          allow(service).to receive_messages(
            generate_oauth_token_with_composite_identity_support:
              ServiceResponse.success(payload: oauth_token),
            generate_workflow_token:
              ServiceResponse.success(payload: workflow_service_token)
          )
        end
      end

      it 'provides a success response containing workflow and flow details' do
        expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
          current_user,
          hash_including(
            json_config: be_a(Hash),
            container: project,
            goal: flow.description
          )
        ).and_call_original

        result = execute
        parsed_yaml = YAML.safe_load(result.payload[:flow_config], aliases: true)

        expect(result).to be_success
        expect(parsed_yaml).to eq(expected_flow_config)
        expect(result.payload[:workflow]).to eq(Ai::DuoWorkflows::Workflow.last)
        expect(result.payload[:workload_id]).to eq(Ci::Workloads::Workload.last.id)
      end

      it 'triggers trigger_ai_catalog_item', :clean_gitlab_redis_shared_state do
        stub_event_properties_builder

        expect { execute }
          .to trigger_internal_events('trigger_ai_catalog_item')
          .with(
            user: current_user,
            project: project,
            additional_properties: stubbed_event_properties.merge(
              label: flow.item_type,
              property: 'manual',
              value: flow.id
            )
          )
          .and increment_usage_metrics(
            'counts.count_total_trigger_ai_catalog_item_weekly',
            'counts.count_total_trigger_ai_catalog_item_monthly',
            'counts.count_total_trigger_ai_catalog_item'
          )
      end

      it 'logs to Ai::Catalog::Logger' do
        mock_logger = Ai::Catalog::Logger.build

        expect(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
        expect(mock_logger).to receive(:context).with(klass: described_class.name).and_call_original
        expect(mock_logger).to receive(:context).with(
          consumer: ai_catalog_item_consumer,
          item: ai_catalog_item_consumer.item,
          version: flow_version
        ).and_call_original
        expect(mock_logger).to receive(:info).with(message: 'Flow executed')

        execute
      end

      context 'when StageCheck :ai_catalog_flows is false' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog_flows).and_return(false)
        end

        it 'does not trigger the flow' do
          expect(execute).to be_error
        end
      end

      context 'when catalog item flow is triggered by a different event' do
        let(:service_params) do
          super().merge(event_type: 'mention')
        end

        it 'triggers trigger_ai_catalog_item with the event', :clean_gitlab_redis_shared_state do
          stub_event_properties_builder

          expect { execute }
            .to trigger_internal_events('trigger_ai_catalog_item')
            .with(
              user: current_user,
              project: project,
              additional_properties: stubbed_event_properties.merge(
                label: flow.item_type,
                property: 'mention',
                value: flow.id
              )
            )
            .and increment_usage_metrics(
              'counts.count_total_trigger_ai_catalog_item_weekly',
              'counts.count_total_trigger_ai_catalog_item_monthly',
              'counts.count_total_trigger_ai_catalog_item'
            )
        end
      end

      it_behaves_like 'creates CI pipeline for Duo Workflow execution' do
        subject { execute }
      end

      context 'when user is not member of the project that owns the flow while has permissions where item is enabled' do
        let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

        it_behaves_like 'creates CI pipeline for Duo Workflow execution' do
          subject { execute }
        end
      end

      context 'when workflow execution process fails' do
        let(:execute_workflow_service) { instance_double(::Ai::Catalog::ExecuteWorkflowService) }

        before do
          allow(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).and_return(execute_workflow_service)
          allow(execute_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.error(message: Array('Workflow execution failed')))
        end

        it_behaves_like 'returns error response', 'Workflow execution failed'
      end

      context 'when user_prompt is specified' do
        let(:service_params) { super().merge({ user_prompt: "test input" }) }

        it 'passes user_prompt as goal to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              json_config: be_a(Hash),
              container: project,
              goal: "test input"
            )
          ).and_call_original

          result = execute
          parsed_yaml = YAML.safe_load(result.payload[:flow_config], aliases: true)

          expect(result).to be_success
          expect(parsed_yaml).to eq(expected_flow_config)
        end
      end

      context 'when flow is a foundational flow' do
        let(:flow) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
        let(:resolved_flow_params) do
          {
            flow_config_id: 'fix_pipeline',
            flow_config_schema_version: 'v1',
            flow_version: '1.0.0'
          }
        end

        before do
          create(:ai_catalog_enabled_foundational_flow, :for_project,
            project: item_enabled_project,
            catalog_item: flow)
          flow.latest_version.update!(release_date: 1.hour.ago)
          allow(::Ai::DuoWorkflows::FoundationalFlowStartParamsResolver).to receive(:call)
            .and_return(resolved_flow_params)
        end

        it 'returns the foundational_flow_reference' do
          expect(service.send(:fetch_flow_definition)).to eq('fix_pipeline/v1')
        end

        it 'returns successful response' do
          result = execute

          expect(result).to be_success
        end

        it 'passes resolved flow_definition to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              flow_definition: "fix_pipeline/v1"
            )
          ).and_call_original

          execute
        end

        it 'calls resolver with correct args and passes results to ExecuteWorkflowService' do
          expect(::Ai::DuoWorkflows::FoundationalFlowStartParamsResolver).to receive(:call)
            .with('fix_pipeline/v1', ai_catalog_item_consumer.project, user: current_user)
            .and_return(resolved_flow_params)

          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              flow_config_id: 'fix_pipeline',
              flow_config_schema_version: 'v1',
              flow_version: '1.0.0'
            )
          ).and_call_original

          execute
        end

        it 'passes nil as title to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              title: nil
            )
          ).and_call_original

          execute
        end
      end

      context 'when flow is not a foundational flow' do
        before do
          allow(ai_catalog_item_consumer.item).to receive(:foundational_flow_reference).and_return(nil)
        end

        it 'returns full flow_config for regular flows' do
          result = execute
          expect(service.send(:foundational_flow?)).to be false

          parsed_yaml = YAML.safe_load(result.payload[:flow_config], aliases: true)
          expect(result).to be_success
          expect(parsed_yaml).to eq(expected_flow_config)
        end

        it 'does not pass flow_definition to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              flow_definition: nil,
              json_config: be_a(Hash)
            )
          ).and_call_original

          execute
        end

        it 'returns nil for fetch_flow_definition' do
          expect(service.send(:fetch_flow_definition)).to be_nil
        end

        it 'passes the flow name as title to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              title: flow.name
            )
          ).and_call_original

          execute
        end

        context 'when flow name exceeds title max length' do
          before do
            flow.update!(name: 'a' * (Ai::DuoWorkflows::Workflow::TITLE_MAX_LENGTH + 10))
          end

          it 'passes the full flow name without truncating' do
            expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
              current_user,
              hash_including(
                title: flow.name
              )
            ).and_call_original

            execute
          end
        end
      end

      context 'with source_branch and additional_context params' do
        let(:service_params) do
          super().merge({ source_branch: 'test-branch',
           additional_context: [{
             Category: "agent_user_environment",
             Content: "some content",
             Metadata: "{}"
           }] })
        end

        it 'calls ExecuteWorkflowService with source_branch and additional_context params' do
          expect(::Ai::Catalog::ExecuteWorkflowService)
            .to receive(:new).with(
              current_user,
              hash_including(source_branch: 'test-branch',
                additional_context: [{
                  Category: "agent_user_environment",
                  Content: "some content",
                  Metadata: "{}"
                }]
              )
            ).and_call_original

          execute
        end
      end

      context 'with merge_request_id param' do
        let(:service_params) { super().merge(merge_request_id: 123) }

        it 'passes merge_request_id to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(merge_request_id: 123)
          ).and_call_original

          execute
        end
      end

      context 'when resume_context is provided' do
        let(:existing_workflow) { instance_double(::Ai::DuoWorkflows::Workflow, id: 1) }
        let(:resume_context) do
          { existing_workflow: existing_workflow, human_approval: true, human_message: 'looks good' }
        end

        let(:service_params) { super().merge(resume_context: resume_context) }

        it 'passes resume_context to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(resume_context: resume_context)
          ).and_return(
            instance_double(
              ::Ai::Catalog::ExecuteWorkflowService,
              execute: ServiceResponse.success(payload: {
                workflow: existing_workflow, workload_id: 1, flow_config: '{}'
              })
            )
          )

          expect(execute).to be_success
        end
      end
    end
  end
end

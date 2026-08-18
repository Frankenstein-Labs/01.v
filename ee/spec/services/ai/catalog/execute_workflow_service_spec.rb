# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ExecuteWorkflowService, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be_with_reload(:organization) { create(:common_organization) }
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, organization: organization) }
  let_it_be_with_reload(:project) do
    create(:project, :repository, organization: organization, group: group, developers: user)
  end

  let_it_be_with_reload(:item) { create(:ai_catalog_item, project:) }
  let_it_be_with_reload(:item_enabled_project) { create(:project, :repository, developers: user) }
  let_it_be_with_reload(:service_account) { create(:user, :service_account) }
  let_it_be(:workflow_service_token, freeze: false) do
    { token: 'workflow_token', expires_at: 1.hour.from_now }
  end

  let(:oauth_token) do
    { oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: 'token-12345') }
  end

  let(:json_config) do
    {
      'version' => 'v1',
      'environment' => 'ambient',
      'components' => [],
      'routers' => [],
      'flow' => []
    }
  end

  let(:goal) { 'Write a Ruby program that prints "Hello, World!"' }
  let(:container) { project }
  let(:params) do
    {
      json_config: json_config,
      container: container,
      goal: goal,
      service_account: service_account
    }
  end

  let(:service) { described_class.new(user, params) }

  before_all do
    project.add_member(service_account, Gitlab::Access::DEVELOPER)
    item_enabled_project.add_member(service_account, Gitlab::Access::DEVELOPER)
  end

  before do
    enable_ai_catalog
    allow_next_instance_of(Ai::UsageQuotaService) do |instance|
      allow(instance).to receive(:execute).and_return(
        ServiceResponse.success
      )
    end
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)

    allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
      allow(service).to receive_messages(
        generate_oauth_token_with_composite_identity_support:
          ServiceResponse.success(payload: oauth_token),
        generate_workflow_token:
          ServiceResponse.success(payload: workflow_service_token)
      )
    end
  end

  shared_examples "returns error response" do |expected_message|
    it "returns an error service response" do
      response = service.execute

      expect(response).to be_error
      expect(response.message).to match_array(expected_message)
    end
  end

  shared_examples 'starts workflow execution' do
    it_behaves_like 'creates CI pipeline for Duo Workflow execution' do
      subject { service.execute }
    end

    it 'returns a success response' do
      response = service.execute

      expect(response).to be_success
      expect(response[:workflow]).to eq(Ai::DuoWorkflows::Workflow.last)
      expect(response[:workload_id]).to eq(Ci::Workloads::Workload.last.id)
      expect(response[:flow_config]).to eq(json_config.to_yaml)
    end
  end

  context 'when json_config is missing' do
    let(:json_config) { nil }

    context 'when flow_definition is provided' do
      let(:params) do
        {
          json_config: json_config,
          container: container,
          goal: goal,
          flow_definition: 'fix_pipeline/v1',
          service_account: service_account
        }
      end

      before do
        allow(user).to receive(:allowed_to_use?).and_return(true)
        allow(::Ai::Catalog::Item).to receive(:with_foundational_flow_reference).and_return([item])
      end

      it_behaves_like 'starts workflow execution'
    end

    context 'when flow_definition is not provided' do
      it_behaves_like 'returns error response', 'JSON config is required'
    end
  end

  context 'when current_user is missing' do
    let(:user) { nil }

    it_behaves_like 'returns error response', 'You have insufficient permissions'
  end

  context 'when container is missing' do
    let(:container) { nil }

    it_behaves_like 'returns error response', 'You have insufficient permissions'
  end

  context 'when goal is missing' do
    let(:goal) { nil }

    it_behaves_like 'returns error response', 'Goal is required'

    context 'when goal is empty string' do
      let(:goal) { '' }

      it_behaves_like 'returns error response', 'Goal is required'
    end
  end

  context 'with a container where the user is not a developer' do
    let(:user) { create(:user, reporter_of: project) }

    it_behaves_like 'returns error response', 'You have insufficient permissions'

    context 'when the container does not own the catalog item' do
      let(:project) { item_enabled_project }
      let(:user) { create(:user, reporter_of: item_enabled_project) }

      it_behaves_like 'returns error response', 'You have insufficient permissions'
    end
  end

  context 'when source_branch and additional_context are provided' do
    let(:params) { super().merge(source_branch: 'test-branch', additional_context: [{ key: 'val' }]) }
    let(:start_workflow_service) { instance_double(::Ai::DuoWorkflows::StartWorkflowService) }

    before do
      allow(user).to receive(:allowed_to_use?).and_return(true)
    end

    it_behaves_like 'starts workflow execution'

    it 'passes source_branch and additional_context to StartWorkflowService' do
      expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
        params = args[:params]

        expect(params[:source_branch]).to eq('test-branch')
        expect(params[:additional_context]).to eq([{ key: 'val' }])

        start_workflow_service
      end

      allow(start_workflow_service).to receive(:execute)
        .and_return(ServiceResponse.success(payload: { workload_id: 123 }))

      service.execute
    end

    it 'passes the root namespace to metadata for extended logging check' do
      expect(::Gitlab::DuoWorkflow::Client).to receive(:metadata)
        .with(user, namespace: project.root_ancestor, project: project)
        .and_call_original

      allow(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new)
        .and_return(instance_double(::Ai::DuoWorkflows::CreateWorkflowService,
          execute: ServiceResponse.success(payload: { workflow: instance_double(::Ai::DuoWorkflows::Workflow,
            id: 1) })))
      allow(start_workflow_service).to receive(:execute)
        .and_return(ServiceResponse.success(payload: { workload_id: 123 }))
      allow(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).and_return(start_workflow_service)

      service.execute
    end

    context 'when container is nil' do
      let(:container) { nil }

      it 'passes nil namespace and nil project in metadata' do
        expect(::Gitlab::DuoWorkflow::Client).to receive(:metadata)
          .with(user, namespace: nil, project: nil)
          .and_return({})

        allow(service).to receive_messages(
          validate: ServiceResponse.success,
          workflow_context_generation_service: instance_double(
            ::Ai::DuoWorkflows::WorkflowContextGenerationService,
            generate_oauth_token_with_composite_identity_support:
              ServiceResponse.success(payload: oauth_token),
            generate_workflow_token:
              ServiceResponse.success(payload: workflow_service_token),
            duo_agent_platform_feature_setting: nil)
        )
        allow(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new)
          .and_return(instance_double(::Ai::DuoWorkflows::CreateWorkflowService,
            execute: ServiceResponse.success(payload: { workflow: instance_double(::Ai::DuoWorkflows::Workflow,
              id: 1) })))
        allow(start_workflow_service).to receive(:execute)
          .and_return(ServiceResponse.success(payload: { workload_id: 123 }))
        allow(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).and_return(start_workflow_service)

        service.execute
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      before do
        allow(Ability).to receive(:allowed?)
          .with(user, :execute_ai_catalog_item, group).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
      end

      it 'passes nil as the project in metadata' do
        expect(::Gitlab::DuoWorkflow::Client).to receive(:metadata)
          .with(user, namespace: group, project: nil)
          .and_call_original

        allow(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new)
          .and_return(instance_double(::Ai::DuoWorkflows::CreateWorkflowService,
            execute: ServiceResponse.success(payload: { workflow: instance_double(::Ai::DuoWorkflows::Workflow,
              id: 1) })))
        allow(start_workflow_service).to receive(:execute)
          .and_return(ServiceResponse.success(payload: { workload_id: 123 }))
        allow(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).and_return(start_workflow_service)

        service.execute
      end
    end
  end

  context 'when validation passes' do
    let(:create_workflow_service) { instance_double(::Ai::DuoWorkflows::CreateWorkflowService) }
    let(:start_workflow_service) { instance_double(::Ai::DuoWorkflows::StartWorkflowService) }
    let(:oauth_service) { instance_double(::Ai::DuoWorkflows::CreateOauthAccessTokenService) }
    let(:workflow_client) { instance_double(::Ai::DuoWorkflow::DuoWorkflowService::Client) }

    before do
      allow(user).to receive(:allowed_to_use?).and_return(true)
    end

    shared_examples 'skips workflow execution' do
      it_behaves_like 'prevents CI pipeline creation for Duo Workflow' do
        subject { service.execute }
      end

      it 'returns an error response' do
        response = service.execute

        expect(response).to be_error
        expect(response[:workflow]).to be_nil
        expect(response[:workload_id]).to be_nil
      end
    end

    context 'when workflow creation fails' do
      before do
        allow(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).and_return(create_workflow_service)
        allow(create_workflow_service).to receive(:execute)
          .and_return(ServiceResponse.error(message: 'Workflow creation failed'))
      end

      it_behaves_like 'returns error response', 'Workflow creation failed'
    end

    context 'when workflow creation succeeds' do
      it_behaves_like 'starts workflow execution'

      context 'when item_version is provided' do
        let(:item_version) { create(:ai_catalog_flow_version) }
        let(:params) { super().merge(item_version: item_version) }

        it 'includes ai_catalog_item_version_id in CreateWorkflowService params' do
          expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new) do |args|
            expect(args[:params][:ai_catalog_item_version_id]).to eq(item_version.id)
          end.and_call_original

          service.execute
        end
      end

      context 'when title is provided' do
        let(:params) { super().merge(title: 'My Custom Flow') }

        it 'sets the workflow title to the provided value' do
          expect do
            service.execute
          end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

          workflow = Ai::DuoWorkflows::Workflow.order(:id).last
          expect(workflow.title).to eq('My Custom Flow')
        end

        context 'when title exceeds max length' do
          let(:long_title) { 'a' * (Ai::DuoWorkflows::Workflow::TITLE_MAX_LENGTH + 10) }
          let(:params) { super().merge(title: long_title) }

          it 'truncates the title to TITLE_MAX_LENGTH' do
            expect do
              service.execute
            end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

            workflow = Ai::DuoWorkflows::Workflow.order(:id).last
            expect(workflow.title.length).to eq(Ai::DuoWorkflows::Workflow::TITLE_MAX_LENGTH)
          end
        end
      end

      it 'creates a Ai::DuoWorkflows::Workflow correctly' do
        expect do
          service.execute
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        workflow_session = Ai::DuoWorkflows::Workflow.last

        expect(workflow_session).to have_attributes(
          goal: goal,
          environment: 'web',
          workflow_definition: 'ai_catalog_agent',
          agent_privileges: described_class::AGENT_PRIVILEGES,
          pre_approved_agent_privileges: described_class::AGENT_PRIVILEGES
        )
      end

      it 'passes all necessary parameters to StartWorkflowService' do
        workflow = nil
        expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
          workflow = args[:workflow]
          params = args[:params]

          expect(params[:goal]).to eq(goal)
          expect(params[:flow_config]).to eq(json_config)
          expect(params[:flow_config_schema_version]).to eq('v1')
          expect(params[:workflow_id]).to eq(workflow.id)
          expect(params[:workflow_oauth_token]).to be_present
          expect(params[:workflow_service_token]).to be_present
          expect(params[:duo_agent_platform_feature_setting]).to be_present

          start_workflow_service
        end
        allow(start_workflow_service).to receive(:execute)
          .and_return(ServiceResponse.success(payload: { workload_id: 123 }))

        service.execute
      end

      context 'when the container does not own the catalog item' do
        let(:project) { item_enabled_project }
        let(:user) { create(:user, developer_of: item_enabled_project) }

        it_behaves_like 'starts workflow execution'
      end

      context 'when service_account is passed' do
        let(:service_account) { create(:user, :service_account) }

        let(:params) { super().merge(service_account: service_account) }

        it 'creates the workflow with the service_account' do
          allow(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).and_return(start_workflow_service)
          allow(start_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workload_id: 123 }))

          response = service.execute

          expect(response).to be_success

          workflow = response.payload[:workflow]
          expect(workflow.service_account).to eq(service_account)
          expect(workflow.service_account_id).to eq(service_account.id)
        end

        it 'passes the service_account to the StartWorkflowService' do
          expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
            params = args[:params]

            expect(params[:service_account]).to eq(service_account)

            start_workflow_service
          end

          allow(start_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workload_id: 123 }))

          service.execute
        end

        it 'passes the service_account to CreateWorkflowService' do
          expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new) do |args|
            expect(args[:params][:service_account]).to eq(service_account)

            create_workflow_service
          end

          allow(create_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workflow: build(:duo_workflows_workflow) }))

          service.execute
        end
      end

      context 'when issue_id is passed' do
        let_it_be_with_reload(:issue) { create(:issue, project: project) }
        let(:params) { super().merge(issue_id: issue.iid) }

        it 'passes the issue_id to CreateWorkflowService' do
          expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new) do |args|
            expect(args[:params][:issue_id]).to eq(issue.iid)

            create_workflow_service
          end

          allow(create_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workflow: build(:duo_workflows_workflow) }))

          service.execute
        end

        context 'when issue_id is nil' do
          let(:params) { super().merge(issue_id: nil) }

          it 'does not pass issue_id to CreateWorkflowService' do
            expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new) do |args|
              expect(args[:params][:issue_id]).to be_nil

              create_workflow_service
            end

            allow(create_workflow_service).to receive(:execute)
              .and_return(ServiceResponse.success(payload: { workflow: build(:duo_workflows_workflow) }))

            service.execute
          end
        end
      end

      context 'when merge_request_id is passed' do
        let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
        let(:params) { super().merge(merge_request_id: merge_request.iid) }

        it 'passes the merge_request_id to CreateWorkflowService' do
          expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new) do |args|
            expect(args[:params][:merge_request_id]).to eq(merge_request.iid)

            create_workflow_service
          end

          allow(create_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workflow: build(:duo_workflows_workflow) }))

          service.execute
        end
      end

      context 'when messaging_callback_context is passed' do
        let(:callback_context) { { 'adapter' => 'slack', 'channel_id' => 'C123' } }
        let(:params) { super().merge(messaging_callback_context: callback_context) }

        it 'passes messaging_callback_context to CreateWorkflowService' do
          expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new) do |args|
            expect(args[:params][:messaging_callback_context]).to eq(callback_context)

            create_workflow_service
          end

          allow(create_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workflow: build(:duo_workflows_workflow) }))

          service.execute
        end
      end

      context 'when messaging_callback_context is not passed' do
        it 'does not include messaging_callback_context in CreateWorkflowService params' do
          expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new) do |args|
            expect(args[:params]).not_to have_key(:messaging_callback_context)

            create_workflow_service
          end

          allow(create_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workflow: build(:duo_workflows_workflow) }))

          service.execute
        end
      end

      context 'when oauth token creation fails' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
            allow(service).to receive(:generate_oauth_token_with_composite_identity_support)
              .and_return(ServiceResponse.error(message: 'OAuth token creation failed'))
          end
        end

        it_behaves_like 'returns error response', 'OAuth token creation failed'
      end

      context 'when workflow token creation fails' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
            allow(service).to receive_messages(
              generate_oauth_token_with_composite_identity_support:
                ServiceResponse.success(payload: oauth_token),
              generate_workflow_token:
                ServiceResponse.error(message: 'Workflow token creation failed')
            )
          end
        end

        it_behaves_like 'returns error response', 'Workflow token creation failed'
      end

      context 'when workflow start fails' do
        before do
          allow(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).and_return(start_workflow_service)
          allow(start_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'Workflow start failed'))
        end

        it_behaves_like 'returns error response', 'Workflow start failed'
      end

      context 'when duo_remote_flows_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_remote_flows_enabled: false)
        end

        it_behaves_like 'skips workflow execution'
      end

      context 'when ci pipeline could not be created' do
        let(:pipeline) do
          instance_double(Ci::Pipeline, created_successfully?: false, full_error_messages: 'some errors')
        end

        let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

        before do
          allow_next_instance_of(::Ci::CreatePipelineService) do |instance|
            allow(instance).to receive(:execute).and_return(service_response)
          end
        end

        it_behaves_like 'returns error response', 'Error in creating workload: some errors'
      end

      context 'when ai_catalog_restricted_to_group_hierarchy is enabled on the top-level group' do
        let!(:item) { create(:ai_catalog_flow, :public, project: item_project) }
        let!(:item_version) { create(:ai_catalog_flow_version, :released, item: item) }

        let(:params) { super().merge(item_version: item_version) }

        before_all do
          group.ai_settings.update!(ai_catalog_restricted_to_group_hierarchy: true)
        end

        context 'when item belongs to a project within the same top-level group' do
          let_it_be_with_reload(:item_project) { create(:project, group: group, developers: user) }

          it_behaves_like 'starts workflow execution'
        end

        context 'when item belongs to project outside the top-level group' do
          let_it_be_with_reload(:item_project) { create(:project, developers: user) }

          it_behaves_like 'skips workflow execution'
          it_behaves_like 'returns error response', 'You have insufficient permissions'

          context 'when item is foundational' do
            before do
              allow(item).to receive(:foundational?).and_return(true)
            end

            it_behaves_like 'starts workflow execution'
          end
        end
      end

      context 'when item is restricted' do
        let!(:item) { create(:ai_catalog_flow, :restricted, project: item_project) }
        let!(:item_version) { create(:ai_catalog_flow_version, :released, item: item) }

        let(:params) { super().merge(item_version: item_version) }

        before do
          group.ai_settings.update!(ai_catalog_restricted_to_group_hierarchy: false)
        end

        context 'when item belongs to a project within the same top-level group' do
          let_it_be(:item_project, freeze: false) { create(:project, group: group, developers: user) }

          it_behaves_like 'starts workflow execution'
        end

        context 'when item belongs to project outside the top-level group' do
          let_it_be(:item_project, freeze: false) { create(:project, developers: user) }

          it_behaves_like 'skips workflow execution'
          it_behaves_like 'returns error response', 'You have insufficient permissions'

          context 'when the feature flag is disabled' do
            before do
              stub_feature_flags(ai_catalog_internal_visibility: false)
            end

            it_behaves_like 'starts workflow execution'
          end
        end
      end
    end

    context 'when resume_context is provided' do
      let_it_be(:existing_workflow, freeze: false) do
        create(:duo_workflows_workflow, project: project, user: user, goal: 'existing goal')
      end

      let(:params) do
        {
          json_config: json_config,
          container: project,
          resume_context: {
            existing_workflow: existing_workflow,
            human_approval: true,
            human_message: 'approved'
          }
        }
      end

      before do
        allow(::Ai::DuoWorkflows::ResumeWorkflowService).to receive(:new).and_return(start_workflow_service)
        allow(start_workflow_service).to receive(:execute)
                                           .and_return(ServiceResponse.success(payload: { workload_id: 123 }))
      end

      it 'does not call CreateWorkflowService' do
        expect(::Ai::DuoWorkflows::CreateWorkflowService).not_to receive(:new)
        service.execute
      end

      it 'passes existing_workflow and resume params to ResumeWorkflowService' do
        expect(::Ai::DuoWorkflows::ResumeWorkflowService).to receive(:new) do |args|
          expect(args[:workflow]).to eq(existing_workflow)

          params = args[:params]
          expect(params[:goal]).to eq('existing goal')
          expect(params[:human_approval]).to be true
          expect(params[:human_message]).to eq('approved')

          start_workflow_service
        end

        service.execute
      end
    end
  end

  context 'when caller provides resolved flow params' do
    let(:start_workflow_service) { instance_double(::Ai::DuoWorkflows::StartWorkflowService) }
    let(:params) do
      {
        json_config: json_config,
        container: container,
        goal: goal,
        service_account: service_account,
        flow_definition: 'developer/v1',
        flow_config_id: 'developer',
        flow_config_schema_version: 'v1',
        flow_version: '2.0.0'
      }
    end

    before do
      allow(user).to receive(:allowed_to_use?).and_return(true)
      allow(start_workflow_service).to receive(:execute)
        .and_return(ServiceResponse.success(payload: { workload_id: 123 }))
    end

    it 'passes caller-provided flow params through to StartWorkflowService' do
      expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
        start_params = args[:params]

        expect(start_params[:flow_definition]).to eq('developer/v1')
        expect(start_params[:flow_config_id]).to eq('developer')
        expect(start_params[:flow_config_schema_version]).to eq('v1')
        expect(start_params[:flow_version]).to eq('2.0.0')

        start_workflow_service
      end

      service.execute
    end
  end

  context 'with trigger context params' do
    let(:start_workflow_service) { instance_double(::Ai::DuoWorkflows::StartWorkflowService) }
    let(:params) do
      {
        json_config: json_config,
        container: container,
        goal: goal,
        service_account: service_account,
        flow_definition: 'security_review/v1',
        event_type: 'mention',
        triggering_conversation: 'developer question'
      }
    end

    before do
      allow(user).to receive(:allowed_to_use?).and_return(true)
      allow(start_workflow_service).to receive(:execute)
        .and_return(ServiceResponse.success(payload: { workload_id: 123 }))
    end

    context 'when a foundational flow mention has a messaging callback binding' do
      let(:params) do
        super().merge(messaging_callback_context: { 'adapter' => 'gitlab_duo_note', 'note_id' => 1 })
      end

      before do
        allow(::Ai::Catalog::Item).to receive(:with_foundational_flow_reference).and_return([item])
      end

      it 'passes the trigger context to StartWorkflowService' do
        expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
          expect(args[:params][:event_type]).to eq('mention')
          expect(args[:params][:triggering_conversation]).to eq('developer question')

          start_workflow_service
        end

        service.execute
      end
    end

    context 'when a foundational flow mention has no messaging callback binding' do
      before do
        allow(::Ai::Catalog::Item).to receive(:with_foundational_flow_reference).and_return([item])
      end

      it 'withholds the trigger context so the flow takes its default route' do
        expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
          expect(args[:params]).not_to have_key(:event_type)
          expect(args[:params]).not_to have_key(:triggering_conversation)

          start_workflow_service
        end

        service.execute
      end
    end

    context 'when a non-foundational flow mention has no messaging callback binding' do
      it 'passes the trigger context to StartWorkflowService' do
        expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
          expect(args[:params][:event_type]).to eq('mention')
          expect(args[:params][:triggering_conversation]).to eq('developer question')

          start_workflow_service
        end

        service.execute
      end
    end

    context 'when a foundational flow is triggered by a non-mention event without a callback binding' do
      let(:params) { super().merge(event_type: 'assign_reviewer', triggering_conversation: nil) }

      before do
        allow(::Ai::Catalog::Item).to receive(:with_foundational_flow_reference).and_return([item])
      end

      it 'passes the event type to StartWorkflowService' do
        expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new) do |args|
          expect(args[:params][:event_type]).to eq('assign_reviewer')

          start_workflow_service
        end

        service.execute
      end
    end
  end
end

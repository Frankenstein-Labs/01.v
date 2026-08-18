# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateAndStartWorkflowService, feature_category: :duo_agent_platform do
  subject(:result) { service.execute }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:oauth_token) { create(:oauth_access_token, user: current_user, scopes: [:api]) }
  let_it_be(:group_level_service_account) do
    create(:user, :service_account) do |user|
      create(:user_detail, user: user, provisioned_by_group: group)
    end
  end

  let_it_be(:catalog_item) do
    create(:ai_catalog_item, :with_foundational_flow_reference, :public, :flow, project: project)
  end

  let_it_be(:group_catalog_item_consumer) do
    create(:ai_catalog_item_consumer, group: group, item: catalog_item, service_account: group_level_service_account)
  end

  let_it_be(:project_catalog_item_consumer) do
    create(
      :ai_catalog_item_consumer,
      project: project,
      item: catalog_item,
      service_account: nil,
      parent_item_consumer: group_catalog_item_consumer
    )
  end

  let_it_be(:project_enabled_flow) do
    create(:ai_catalog_enabled_foundational_flow, :for_project, project: project, catalog_item: catalog_item)
  end

  let(:resource) { instance_double(MergeRequest, id: 42) }
  let(:goal) { 'Custom goal' }
  let(:source_branch) { 'feature/add-workflow' }

  let(:workflow_definition) do
    ::Ai::Catalog::FoundationalFlow.new(
      display_name: catalog_item.foundational_flow_reference,
      foundational_flow_reference: catalog_item.foundational_flow_reference
    )
  end

  let(:service) do
    described_class.new(
      container: project,
      resource: resource,
      current_user: current_user,
      goal: goal,
      source_branch: source_branch,
      workflow_definition: workflow_definition
    )
  end

  let(:workflow_service_token_result) do
    ServiceResponse.success(
      payload: { token: 'foo' }
    )
  end

  let(:workflow_oauth_token_result) do
    ServiceResponse.success(
      payload: { oauth_access_token: oauth_token }
    )
  end

  let(:resolve_service_account_result) do
    ServiceResponse.success(
      payload: { service_account: group_level_service_account }
    )
  end

  shared_examples 'failure' do |reason, message|
    it 'does not create a workload to execute workflow', :aggregate_failures do
      expect(result).to be_error
      expect(result.message).to eq(message)
      expect(result.reason).to eq(reason)
    end
  end

  shared_examples 'success' do
    it 'creates the workflow and starts a workload to execute with the correct definition', :aggregate_failures do
      expect(result).to be_success

      workflow = result.payload[:workflow]
      workload_id = result.payload[:workload_id]

      expect(workflow).to be_a(Ai::DuoWorkflows::Workflow)

      expect(workload_id).not_to be_nil
      expect(workflow.workflows_workloads.first).to have_attributes(project_id: project.id, workload_id: workload_id)

      workload = Ci::Workloads::Workload.find_by(id: workload_id)
      expect(workload.branch_name).to start_with('refs/workloads/')
      expect(workload.pipeline.user).to eq(group_level_service_account)
    end
  end

  before do
    allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
      allow(service)
        .to receive_messages(
          generate_workflow_token: workflow_service_token_result,
          generate_oauth_token_with_composite_identity_support: workflow_oauth_token_result
        )
    end

    allow_next_instance_of(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService) do |service|
      allow(service).to receive(:execute).and_return(resolve_service_account_result)
    end

    allow_next_instance_of(Ai::UsageQuotaService) do |instance|
      allow(instance).to receive(:execute).and_return(
        ServiceResponse.success
      )
    end

    allow(::Ai::DuoWorkflow).to receive(:available?).and_return(true)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(current_user, :create_duo_workflow_for_ci, project).and_return(true)
    allow(Ability).to receive(:allowed?).with(current_user, :execute_duo_workflow_in_ci, anything).and_return(true)
    allow(Ability).to receive(:allowed?).with(current_user, :read_ai_catalog_item_consumer, anything).and_return(true)

    project.project_setting.update!(
      duo_foundational_flows_enabled: true,
      duo_features_enabled: true,
      duo_remote_flows_enabled: true
    )

    project.add_member(group_level_service_account, :developer)
  end

  context 'when workflow definition is not provided' do
    let(:workflow_definition) { nil }

    include_examples 'failure', :invalid_workflow_definition, 'Workflow definition cannot be blank'
  end

  context 'when source branch is not provided' do
    let(:source_branch) { nil }

    include_examples 'failure', :invalid_source_branch, 'Source branch cannot be blank'
  end

  context 'when workflow token could not be generated' do
    let(:workflow_service_token_result) do
      ServiceResponse.error(message: 'Could not create workflow token')
    end

    include_examples 'failure', :invalid_duo_workflow_token, 'Could not obtain Duo Workflow token'
  end

  context 'when oauth token could not be generated' do
    let(:workflow_oauth_token_result) do
      ServiceResponse.error(message: 'Could not create workflow token')
    end

    include_examples 'failure', :invalid_oauth_token, 'Could not obtain authentication token'
  end

  context 'when flow is not enabled in the catalog item consumers' do
    context 'when flow does not have a catalog item' do
      before do
        allow(workflow_definition).to receive(:foundational_flow_reference).and_return(nil)
      end

      include_examples 'failure', :flow_not_enabled, 'Workflow not enabled for this project/namespace'
    end

    context 'when foundational flows are disabled' do
      before do
        allow(project).to receive(:duo_foundational_flows_enabled).and_return(false)
      end

      include_examples 'failure', :flow_not_enabled, 'Workflow not enabled for this project/namespace'
    end

    context 'when the flow is disabled' do
      before do
        allow(project).to receive(:enabled_flow_catalog_item_ids).and_return([])
      end

      include_examples 'failure', :flow_not_enabled, 'Workflow not enabled for this project/namespace'
    end
  end

  context 'when service account could not be resolved' do
    let(:resolve_service_account_result) do
      ServiceResponse.error(message: 'Could not resolve service account')
    end

    include_examples 'failure', :invalid_service_account, 'Could not resolve the service account for this flow'
  end

  context 'when usage quota is exceeded' do
    before do
      allow_next_instance_of(Ai::UsageQuotaService) do |instance|
        allow(instance).to receive(:execute).and_return(
          ServiceResponse.error(message: "Usage quota exceeded", reason: :usage_quota_exceeded)
        )
      end
    end

    include_examples 'failure', :usage_quota_exceeded, 'Usage quota exceeded'
  end

  context 'when namespace is missing' do
    before do
      allow_next_instance_of(Ai::UsageQuotaService) do |instance|
        allow(instance).to receive(:execute).and_return(
          ServiceResponse.error(message: "Namespace is required", reason: :namespace_missing)
        )
      end
    end

    it 'returns an error with actionable namespace message', :aggregate_failures do
      expect(result).to be_error
      expect(result.message).to include(current_user.to_reference)
      expect(result.message).to include('default GitLab Duo namespace')
      expect(result.message).to include('preferences')
      expect(result.reason).to eq(:namespace_missing)
    end
  end

  context 'when workflow fails to start' do
    before do
      allow_next_instance_of(Ai::DuoWorkflows::StartWorkflowService) do |instance|
        allow(instance).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Random failure', reason: :random_reason)
        )
      end
    end

    include_examples 'failure', :random_reason, 'Random failure'
  end

  context 'when the workflow definition has an additional_context_resolver' do
    let(:workflow_definition) do
      ::Ai::Catalog::FoundationalFlow.new(
        display_name: catalog_item.foundational_flow_reference,
        foundational_flow_reference: catalog_item.foundational_flow_reference,
        additional_context_resolver: ->(resource:) { { "test" => { "foo" => resource } } }
      )
    end

    it 'resolves it with the given resource and forwards it to StartWorkflowService' do
      expect(Ai::DuoWorkflows::StartWorkflowService).to receive(:new)
        .with(workflow: anything, params: hash_including(
          additional_context: [
            { "Category" => "test", "Content" => ::Gitlab::Json.dump({ "foo" => resource }) }
          ]
        ))
        .and_call_original

      result
    end
  end

  context 'when the workflow definition has no additional_context_resolver' do
    it 'passes an empty array as additional_context' do
      expect(Ai::DuoWorkflows::StartWorkflowService).to receive(:new)
        .with(workflow: anything, params: hash_including(additional_context: []))
        .and_call_original

      result
    end
  end

  context 'with a configured foundational flow' do
    include_examples 'success'

    it 'creates the workflow with the resolved service_account' do
      expect(result).to be_success

      workflow = result.payload[:workflow]
      expect(workflow.service_account).to eq(group_level_service_account)
      expect(workflow.service_account_id).to eq(group_level_service_account.id)
    end

    it 'passes the root namespace to metadata for extended logging check' do
      expect(::Gitlab::DuoWorkflow::Client).to receive(:metadata)
        .with(current_user, namespace: project.root_ancestor, project: project)
        .and_call_original

      result
    end

    context 'when container is nil' do
      let(:service) do
        described_class.new(
          container: nil,
          resource: resource,
          current_user: current_user,
          goal: goal,
          source_branch: source_branch,
          workflow_definition: workflow_definition
        )
      end

      before do
        allow(service).to receive_messages(
          validation: ServiceResponse.success,
          workflow_context_generation_service: instance_double(
            ::Ai::DuoWorkflows::WorkflowContextGenerationService,
            generate_workflow_token: workflow_service_token_result,
            generate_oauth_token_with_composite_identity_support: workflow_oauth_token_result,
            duo_agent_platform_feature_setting: nil)
        )
        stub_workflow = instance_double(::Ai::DuoWorkflows::Workflow, id: 1, user: current_user)
        allow_next_instance_of(::Ai::DuoWorkflows::CreateWorkflowService) do |svc|
          allow(svc).to receive(:execute).and_return(
            ServiceResponse.success(payload: { workflow: stub_workflow })
          )
        end
        allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |svc|
          allow(svc).to receive(:execute).and_return(
            ServiceResponse.success(payload: { workload_id: 1 })
          )
        end
      end

      it 'passes nil namespace and nil project in metadata' do
        expect(::Gitlab::DuoWorkflow::Client).to receive(:metadata)
          .with(current_user, namespace: nil, project: nil)
          .and_return({})

        result
      end
    end

    context 'when container is a group' do
      let(:service) do
        described_class.new(
          container: group,
          resource: resource,
          current_user: current_user,
          goal: goal,
          source_branch: source_branch,
          workflow_definition: workflow_definition
        )
      end

      before do
        allow(group).to receive_messages(
          duo_foundational_flows_enabled: true,
          enabled_flow_catalog_item_ids: [catalog_item.id],
          organization: project.organization
        )
        allow(Ability).to receive(:allowed?).with(current_user, :create_duo_workflow_for_ci, group).and_return(true)
      end

      it 'passes nil as the project in metadata' do
        expect(::Gitlab::DuoWorkflow::Client).to receive(:metadata)
          .with(current_user, namespace: group, project: nil)
          .and_call_original

        result
      end
    end
  end
end

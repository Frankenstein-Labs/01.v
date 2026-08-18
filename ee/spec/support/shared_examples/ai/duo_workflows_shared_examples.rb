# frozen_string_literal: true

RSpec.shared_examples 'workflow access is forbidden' do
  it 'workflow access is forbidden' do
    post api(path, user), params: params

    expect(response).to have_gitlab_http_status(:forbidden)
  end
end

RSpec.shared_examples 'returns not found' do
  it 'returns not found' do
    post api(path, user), params: params

    expect(response).to have_gitlab_http_status(:not_found)
  end
end

RSpec.shared_examples 'container resolution for workflows' do
  context 'when container resolution' do
    before do
      allow(Gitlab::AiGateway).to receive(:public_headers).and_return({})
    end

    context 'when project_id does not exist' do
      let(:params) { { project_id: non_existing_record_id } }

      include_examples 'returns not found'
    end

    context 'when namespace_id does not exist' do
      let(:params) { { namespace_id: non_existing_record_id } }

      include_examples 'returns not found'
    end

    context 'when neither project_id nor namespace_id are specified' do
      let(:params) { {} }

      context 'when user has no default duo namespace' do
        before do
          allow_any_instance_of(UserPreference).to receive(:duo_default_namespace_with_fallback).and_return(nil) # rubocop:disable RSpec/AnyInstanceOf -- user is reloaded during request
        end

        it 'returns bad request' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include('No default namespace found')
        end
      end

      context 'when user cannot access the container' do
        let(:inaccessible_namespace) { create(:group, :private) }

        before do
          allow_any_instance_of(UserPreference).to receive(:duo_default_namespace_with_fallback).and_return(inaccessible_namespace) # rubocop:disable RSpec/AnyInstanceOf -- user is reloaded during request
        end

        it 'returns forbidden' do
          post api(path, user), params: {}

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to include('Access to the container is not allowed')
        end
      end
    end
  end
end

RSpec.shared_examples 'foundational flow workflow creation' do
  context 'when workflow_definition is a foundational flow' do
    let_it_be(:foundational_flow_group, freeze: false) { create(:group) }
    let(:foundational_params) do
      {
        project_id: foundational_flow_project.id,
        workflow_definition: 'fix_pipeline/v1',
        goal: 'Fix the pipeline',
        start_workflow: true
      }
    end

    let_it_be(:foundational_flow_service_account, freeze: false) do
      create(:user, :service_account,
        provisioned_by_group: foundational_flow_group
      )
    end

    let_it_be(:foundational_flow_item, freeze: false) do
      create(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'fix_pipeline/v1')
    end

    let_it_be(:foundational_flow_consumer, freeze: false) do
      create(:ai_catalog_item_consumer,
        item: foundational_flow_item,
        group: foundational_flow_group,
        service_account: foundational_flow_service_account
      )
    end

    let_it_be_with_reload(:foundational_flow_project) do
      create(:project, :repository, group: foundational_flow_group, developers: user)
    end

    let_it_be(:foundational_flow_project_consumer, freeze: false) do
      create(:ai_catalog_item_consumer,
        item: foundational_flow_item,
        project: foundational_flow_project,
        parent_item_consumer: foundational_flow_consumer
      )
    end

    let_it_be(:foundational_flow_enabled, freeze: false) do
      create(:ai_catalog_enabled_foundational_flow, :for_project,
        project: foundational_flow_project,
        catalog_item: foundational_flow_item)
    end

    before_all do
      foundational_flow_group.add_developer(user)
      foundational_flow_project.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      foundational_flow_item.latest_version.update!(release_date: Time.current)
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                            .with(foundational_flow_project, :duo_workflow).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                            .with(foundational_flow_project, :foundational_flows).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                            .with(foundational_flow_project, :ai_catalog).and_return(true)
      allow(::Ai::Catalog::FoundationalFlow['fix_pipeline/v1']).to receive(:catalog_item)
        .and_return(foundational_flow_item)
      allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
        allow(client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: { token: "an-encrypted-token" })
        )
      end
      allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(
            payload: {
              oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: 'oauth_token')
            }
          )
        )
      end
      allow_next_instance_of(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { service_account: foundational_flow_service_account })
        )
      end
      allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |svc|
        allow(svc).to receive(:execute)
                        .and_return(ServiceResponse.success(payload: { workload_id: 1 }))
      end
    end

    it 'resolves service account from catalog item consumer and creates the workflow' do
      post api(path, user), params: foundational_params

      expect(response).to have_gitlab_http_status(:created)
      created_workflow = Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.service_account_id).to eq(foundational_flow_service_account.id)
    end

    context 'when service account is resolved from catalog item consumer' do
      let(:params) do
        {
          project_id: foundational_flow_project.id,
          workflow_definition: 'fix_pipeline/v1',
          goal: 'Fix the pipeline',
          start_workflow: true
        }
      end

      before do
        allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |svc|
          allow(svc).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { workload_id: 1 }))
        end
      end

      it 'creates a workflow with the resolved service_account_id' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:created)
        created_workflow = Ai::DuoWorkflows::Workflow.last
        expect(created_workflow.service_account_id).to eq(foundational_flow_service_account.id)
      end

      it 'passes the resolved service_account to CreateWorkflowService' do
        expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).with(
          hash_including(
            params: hash_including(service_account: foundational_flow_service_account)
          )
        ).and_call_original

        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:created)
      end

      it 'passes the resolved service_account to StartWorkflowService' do
        expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
          workflow: anything,
          params: hash_including(service_account: foundational_flow_service_account)
        ).and_call_original

        post api(path, user), params: params
      end
    end

    context 'when no consumer is configured for the foundational flow' do
      let_it_be(:no_consumer_project, freeze: false) do
        create(:project, :repository, group: foundational_flow_group, developers: user)
      end

      before do
        no_consumer_project.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                              .with(no_consumer_project, :duo_workflow).and_return(true)
      end

      it 'returns forbidden' do
        post api(path, user), params: foundational_params.merge(project_id: no_consumer_project.id)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when flow is not in the allow list' do
      before do
        foundational_flow_enabled.destroy!
      end

      it 'returns forbidden' do
        post api(path, user), params: foundational_params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        foundational_flow_project.update!(duo_foundational_flows_enabled: false)
      end

      it 'returns forbidden' do
        post api(path, user), params: foundational_params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end

RSpec.shared_examples 'ai catalog item version workflow creation' do
  context 'when ai_catalog_item_version_id is provided' do
    let_it_be(:ai_catalog_item, freeze: false) { create(:ai_catalog_item) }
    let_it_be(:ai_catalog_item_version, freeze: false) { create(:ai_catalog_item_version, item: ai_catalog_item) }
    let(:params) { super().merge(ai_catalog_item_version_id: ai_catalog_item_version.id) }

    before do
      # TODO: use factory instead https://gitlab.com/gitlab-org/gitlab/-/issues/583818
      allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).and_return(true)
      allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
        allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: true))
      end
    end

    it 'creates a workflow with the AI catalog item version' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['ai_catalog_item_version_id']).to eq(ai_catalog_item_version.id)
      created_workflow = Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.ai_catalog_item_version).to eq(ai_catalog_item_version)
    end

    context 'when user does not have access to the AI catalog item' do
      before do
        allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
          allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: false))
        end
      end

      it 'returns not found error' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to include('ItemVersion not found')
      end
    end

    context 'when ai_catalog_item_version_id does not exist' do
      let(:params) { super().merge(ai_catalog_item_version_id: non_existing_record_id) }

      it 'returns not found error' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end

RSpec.shared_examples 'issue and merge request association for workflows' do
  context 'when no issue_id is provided' do
    let(:params) { { project_id: project.id, issue_id: nil } }

    it 'creates a workflow without issue association' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:created)
      created_workflow = Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.issue).to be_nil
    end
  end

  context 'when issue_id is provided' do
    let(:params) { { project_id: project.id, issue_id: issue.iid } }

    it 'creates a workflow associated with the issue' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:created)
      created_workflow = Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.issue).to eq(issue)
      expect(created_workflow.merge_request).to be_nil
    end
  end

  context 'when issue_id does not exist' do
    let(:params) { { project_id: project.id, issue_id: 9999 } }

    it 'returns not found' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when merge_request_id is provided' do
    let(:params) { { project_id: project.id, merge_request_id: merge_request.iid } }

    it 'creates a workflow associated with the merge request' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:created)
      created_workflow = Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.merge_request).to eq(merge_request)
      expect(created_workflow.issue).to be_nil
    end
  end

  context 'when no merge_request_id is provided' do
    let(:params) { { project_id: project.id, merge_request_id: nil } }

    it 'creates a workflow without merge request association' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:created)
      created_workflow = Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.merge_request).to be_nil
    end
  end

  context 'when project_id is a full path string' do
    context 'with issue_id' do
      let(:params) { { project_id: project.full_path, issue_id: issue.iid } }

      it 'resolves the project by path and associates the issue', :aggregate_failures do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:created)
        created_workflow = Ai::DuoWorkflows::Workflow.last
        expect(created_workflow.project).to eq(project)
        expect(created_workflow.issue).to eq(issue)
      end
    end

    context 'with merge_request_id' do
      let(:params) { { project_id: project.full_path, merge_request_id: merge_request.iid } }

      it 'resolves the project by path and associates the merge request', :aggregate_failures do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:created)
        created_workflow = Ai::DuoWorkflows::Workflow.last
        expect(created_workflow.project).to eq(project)
        expect(created_workflow.merge_request).to eq(merge_request)
      end
    end
  end
end

RSpec.shared_examples 'ai catalog item consumer workflow execution' do
  context 'when ai_catalog_item_consumer_id is provided' do
    let_it_be(:consumer_group, freeze: false) { create(:group) }
    let_it_be(:flow_project, freeze: false) { create(:project, group: consumer_group) }
    let_it_be(:flow, freeze: false) { create(:ai_catalog_flow, :public, project: flow_project) }

    let_it_be(:consumer_service_account, freeze: false) do
      create(:user, :service_account,
        composite_identity_enforced: true,
        provisioned_by_group: consumer_group
      )
    end

    let_it_be(:group_consumer, freeze: false) do
      create(:ai_catalog_item_consumer,
        item: flow,
        group: consumer_group,
        service_account: consumer_service_account
      )
    end

    let_it_be(:execution_project, freeze: false) do
      create(:project, :repository, group: consumer_group, developers: user)
    end

    let_it_be(:project_consumer, freeze: false) do
      create(:ai_catalog_item_consumer,
        item: flow,
        project: execution_project,
        parent_item_consumer: group_consumer
      )
    end

    let_it_be(:execution_project_issue, freeze: false) { create(:issue, project: execution_project) }

    before_all do
      consumer_group.add_developer(user)
      execution_project.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      flow_project.update!(duo_features_enabled: true)
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                            .with(flow_project, :ai_catalog).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                            .with(execution_project, :ai_catalog).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                            .with(execution_project, :duo_workflow).and_return(true)
    end

    it 'executes the AI catalog flow with correct service account from project consumer' do
      fake_workflow = build(:duo_workflows_workflow, id: 180, user: user, project: execution_project)

      expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
        project: execution_project,
        current_user: user,
        params: hash_including(
          item_consumer: project_consumer,
          service_account: consumer_service_account,
          execute_workflow: true,
          event_type: 'api_execution',
          user_prompt: 'Execute catalog flow'
        )
      ).and_return(
        instance_double(
          Ai::Catalog::Flows::ExecuteService,
          execute: ServiceResponse.success(
            payload: { workflow: fake_workflow, workload_id: 123 }
          )
        )
      )

      post api(path, user), params: {
        project_id: execution_project.id,
        ai_catalog_item_consumer_id: project_consumer.id,
        start_workflow: true,
        goal: 'Execute catalog flow'
      }

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['workload']['id']).to eq(123)
    end

    it 'executes the AI catalog flow with correct service account when consumer project is nil' do
      # Mock the consumer to have project_id set but project association as nil
      # This simulates the else branch where consumer.project.present? is false
      allow_any_instance_of(::Ai::Catalog::ItemConsumer).to receive(:project).and_return(nil) # rubocop:disable RSpec/AnyInstanceOf -- not the next instance

      fake_workflow = build(:duo_workflows_workflow, id: 183, user: user, project: execution_project)
      project_consumer_service_account = project_consumer.service_account

      expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
        project: execution_project,
        current_user: user,
        params: hash_including(
          item_consumer: project_consumer,
          service_account: project_consumer_service_account,
          execute_workflow: true,
          event_type: 'api_execution',
          user_prompt: 'Execute catalog flow with nil project'
        )
      ).and_return(
        instance_double(
          Ai::Catalog::Flows::ExecuteService,
          execute: ServiceResponse.success(
            payload: { workflow: fake_workflow, workload_id: 126 }
          )
        )
      )

      post api(path, user), params: {
        project_id: execution_project.id,
        ai_catalog_item_consumer_id: project_consumer.id,
        start_workflow: true,
        goal: 'Execute catalog flow with nil project'
      }

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['workload']['id']).to eq(126)
    end

    it 'executes the AI catalog flow with correct service account when consumer has no parent' do
      # Mock the project_consumer to have no parent, so it uses its own service_account
      allow_any_instance_of(::Ai::Catalog::ItemConsumer).to receive(:parent_item_consumer).and_return(nil) # rubocop:disable RSpec/AnyInstanceOf -- not the next instancef

      fake_workflow = build(:duo_workflows_workflow, id: 183, user: user, project: execution_project)
      project_consumer_service_account = project_consumer.service_account

      expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
        project: execution_project,
        current_user: user,
        params: hash_including(
          item_consumer: project_consumer,
          service_account: project_consumer_service_account,
          execute_workflow: true,
          event_type: 'api_execution',
          user_prompt: 'Execute catalog flow without parent'
        )
      ).and_return(
        instance_double(
          Ai::Catalog::Flows::ExecuteService,
          execute: ServiceResponse.success(
            payload: { workflow: fake_workflow, workload_id: 126 }
          )
        )
      )

      post api(path, user), params: {
        project_id: execution_project.id,
        ai_catalog_item_consumer_id: project_consumer.id,
        start_workflow: true,
        goal: 'Execute catalog flow without parent'
      }

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['workload']['id']).to eq(126)
    end

    it 'passes issue_id to flow params when issue_id is provided' do
      fake_workflow = build(:duo_workflows_workflow, id: 181, user: user, project: execution_project)

      expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
        project: execution_project,
        current_user: user,
        params: hash_including(
          item_consumer: project_consumer,
          service_account: consumer_service_account,
          execute_workflow: true,
          event_type: 'api_execution',
          user_prompt: 'Execute catalog flow with issue',
          issue_id: execution_project_issue.iid
        )
      ).and_return(
        instance_double(
          Ai::Catalog::Flows::ExecuteService,
          execute: ServiceResponse.success(
            payload: { workflow: fake_workflow, workload_id: 124 }
          )
        )
      )

      post api("/ai/duo_workflows/workflows", user), params: {
        project_id: execution_project.id,
        ai_catalog_item_consumer_id: project_consumer.id,
        start_workflow: true,
        goal: 'Execute catalog flow with issue',
        issue_id: execution_project_issue.iid
      }

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['workload']['id']).to eq(124)
    end

    it 'passes nil issue_id when issue_id is not provided' do
      fake_workflow = build(:duo_workflows_workflow, id: 182, user: user, project: execution_project)

      expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
        project: execution_project,
        current_user: user,
        params: hash_including(
          item_consumer: project_consumer,
          service_account: consumer_service_account,
          execute_workflow: true,
          event_type: 'api_execution',
          user_prompt: 'Execute catalog flow without issue',
          issue_id: nil
        )
      ).and_return(
        instance_double(
          Ai::Catalog::Flows::ExecuteService,
          execute: ServiceResponse.success(
            payload: { workflow: fake_workflow, workload_id: 125 }
          )
        )
      )

      post api("/ai/duo_workflows/workflows", user), params: {
        project_id: execution_project.id,
        ai_catalog_item_consumer_id: project_consumer.id,
        start_workflow: true,
        goal: 'Execute catalog flow without issue'
      }

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['workload']['id']).to eq(125)
    end

    it 'returns forbidden when consumer does not belong to project' do
      other_project = create(:project)
      other_flow = create(:ai_catalog_flow, :public, project: other_project)
      other_consumer = create(:ai_catalog_item_consumer, item: other_flow, project: other_project)

      post api(path, user), params: {
        project_id: execution_project.id,
        ai_catalog_item_consumer_id: other_consumer.id,
        goal: 'test'
      }

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(json_response['message']).to include('Agent or flow is not enabled for this project')
    end

    it 'returns not found when consumer does not exist' do
      post api(path, user), params: {
        project_id: execution_project.id,
        ai_catalog_item_consumer_id: non_existing_record_id,
        goal: 'test'
      }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to include('Enabled agent or flow was not found for this project.')
    end

    it 'returns bad request when used in namespace context' do
      post api(path, user), params: {
        namespace_id: consumer_group.id,
        ai_catalog_item_consumer_id: project_consumer.id,
        goal: 'test'
      }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']).to include('AI Catalog flows can only be executed in project context')
    end
  end
end

RSpec.shared_examples 'start workflow execution' do
  context 'when start_workflow is true' do
    before_all do
      project.project_setting.update!(duo_remote_flows_enabled: true)
    end

    let(:params) do
      {
        project_id: project.id,
        start_workflow: true,
        goal: 'test'
      }
    end

    before do
      allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
        allow(client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: { token: "an-encrypted-token" })
        )
      end
      allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(
            payload: {
              oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: 'oauth_token')
            }
          )
        )
      end
    end

    it 'creates a pipeline to run the workflow' do
      expect_next_instance_of(Ci::CreatePipelineService) do |pipeline_service|
        expect(pipeline_service).to receive(:execute).and_call_original
      end

      post api(path, user), params: params

      expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
      expect(json_response['workload']['id']).to eq(Ci::Workloads::Workload.last.id)
      expect(::Ci::Pipeline.last.project_id).to eq(project.id)
    end

    context 'when duo_remote_flows_enabled is off' do
      before do
        project.project_setting.update!(duo_remote_flows_enabled: false)
        project.reload
      end

      include_examples 'workflow access is forbidden'
    end

    context 'when start workflow execution fails' do
      context 'when response reason is unprocessable_entity' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Invalid workflow configuration', reason: :unprocessable_entity)
            )
          end
        end

        it 'returns unprocessable_entity status' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when response reason is feature_unavailable' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Feature is unavailable', reason: :feature_unavailable)
            )
          end
        end

        it 'returns forbidden status' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when response reason is service_account_error' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Service account error', reason: :invalid_service_account)
            )
          end
        end

        it 'returns forbidden status' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when response reason is workload_failure' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Workload failed to start', reason: :workload_failure)
            )
          end
        end

        it 'returns unprocessable_entity status' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when response reason is unknown' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Unknown error', reason: :unknown_error)
            )
          end
        end

        it 'returns internal_server_error status' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:internal_server_error)
        end
      end

      context 'when langsmith_trace header is present' do
        let(:headers) { { 'Langsmith-Trace' => 'trace-123' } }

        it 'includes langsmith_trace in the workflow execution' do
          expect_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            expect(service).to receive(:execute).and_call_original
          end

          post api(path, user), params: params, headers: headers

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when source_branch is provided' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'test',
            source_branch: 'feature-branch'
          }
        end

        it 'passes source_branch to workflow execution' do
          expect_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            expect(service).to receive(:execute).and_call_original
          end

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when additional_context is provided' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'test',
            additional_context: [{ Category: 'agent_user_environment', Content: '{"key": "value"}' }]
          }
        end

        it 'passes additional_context to workflow execution' do
          expect_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            expect(service).to receive(:execute).and_call_original
          end

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when shallow_clone is explicitly set to false' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'test',
            shallow_clone: false
          }
        end

        it 'respects the shallow_clone parameter' do
          expect_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            expect(service).to receive(:execute).and_call_original
          end

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when shallow_clone is not provided' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'test'
          }
        end

        it 'defaults shallow_clone to true' do
          expect_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            expect(service).to receive(:execute).and_call_original
          end

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end
  end
end

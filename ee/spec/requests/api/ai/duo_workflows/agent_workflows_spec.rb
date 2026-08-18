# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::AgentWorkflows, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:ai_workflows_oauth_token) do
    create(:oauth_access_token, user: user, scopes: [:ai_workflows])
  end

  let_it_be(:auth_response) { Ai::UserAuthorizable::Response.new(allowed?: true, namespace_ids: [group.id]) }
  let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
  let(:workflow_definition) { 'software_development' }
  let(:allow_agent_to_request_user) { false }
  let(:path) { "/ai/duo_workflows/agent_workflows" }
  let(:params) do
    {
      project_id: project.id,
      workflow_definition: workflow_definition,
      allow_agent_to_request_user: allow_agent_to_request_user
    }
  end

  before_all do
    group.add_developer(user)
    project.add_member(service_account, Gitlab::Access::DEVELOPER)
  end

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)

    allow_any_instance_of(User).to receive(:allowed_to_use).and_return(auth_response) # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
    allow_next_instance_of(::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService) do |service|
      allow(service).to receive(:execute).and_return(
        ServiceResponse.success(
          payload: {
            oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: 'token-12345')
          }
        )
      )
    end

    ::Ai::Setting.for_organization(project.organization)
      .update!(duo_workflow_service_account_user_id: service_account.id)
    allow(::Gitlab::Auth::Identity).to receive(:resolve_composite_identity_actor).and_call_original
    allow(::Gitlab::Auth::Identity).to receive(:resolve_composite_identity_actor)
                                         .with(user).and_return(service_account)
    allow(::Gitlab::Auth::Identity).to receive(:resolve_composite_identity_actor)
                                         .with(service_account).and_return(service_account)
    project.update!(allow_composite_identities_to_run_pipelines: true)
    project.reload
  end

  describe 'POST /ai/duo_workflows/agent_workflows' do
    before do
      allow_next_instance_of(Ai::UsageQuotaService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    context 'when agentic_foundational_flow_tool feature flag is disabled' do
      before do
        stub_feature_flags(agentic_foundational_flow_tool: false)
      end

      it 'returns not found' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post api(path), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as a regular user' do
      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :duo_workflow_execute_workflow,
            governing_namespace_id: user.governing_namespace(project).id,
            organization_id: user.governing_namespace(project).organization_id,
            subject: user
          )
          .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
      end

      it 'creates a workflow' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        created_workflow = Ai::DuoWorkflows::Workflow.last
        expect(json_response['id']).to eq(created_workflow.id)
        expect(created_workflow.workflow_definition).to eq(workflow_definition)
        expect(created_workflow.allow_agent_to_request_user).to eq(allow_agent_to_request_user)
      end
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :duo_workflow_execute_workflow,
            governing_namespace_id: user.governing_namespace(project).id,
            organization_id: user.governing_namespace(project).organization_id,
            subject: user)
          .and_return({})
      end

      it 'creates the workflow (agent-initiated foundational flow)' do
        expect do
          post api(path, oauth_access_token: ai_workflows_oauth_token), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
      end
    end

    context 'with a catalog workflow' do
      let_it_be(:flow) { create(:ai_catalog_flow, :public, project: project) }
      let_it_be(:consumer) do
        create(:ai_catalog_item_consumer, item: flow, project: project, pinned_version_prefix: nil)
      end

      let(:input_required_workflow) do
        create(:duo_workflows_workflow, user: user, project: project, status: 6,
          ai_catalog_item: flow, ai_catalog_item_version: flow.latest_version)
      end

      context 'when workflow execution returns error' do
        before do
          allow_next_instance_of(::Ai::Catalog::Flows::ExecuteService) do |svc|
            allow(svc).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Something went wrong', reason: :validation_error)
            )
          end
        end

        it 'returns 400' do
          post api(path, user), params: params.merge(ai_catalog_item_consumer_id: consumer.id)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include('Something went wrong')
        end
      end
    end

    context 'without a catalog workflow when workflow creation fails with error status' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CreateWorkflowService) do |svc|
          response = instance_double(ServiceResponse)
          allow(response).to receive(:error?).and_return(false)
          allow(response).to receive(:[]).with(:status).and_return(:error)
          allow(response).to receive(:[]).with(:message).and_return('Workflow creation failed')
          allow(svc).to receive(:execute).and_return(response)
        end
      end

      it 'returns 400' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to include('Workflow creation failed')
      end
    end

    context 'when agent_privileges is provided' do
      before do
        allow(Gitlab::AiGateway).to receive(:public_headers).and_return({})
      end

      it 'ignores the parameter and creates the workflow with default privileges' do
        post api(path, user), params: params.merge(
          agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES]
        )

        expect(response).to have_gitlab_http_status(:created)

        created_workflow = Ai::DuoWorkflows::Workflow.last
        expect(created_workflow.agent_privileges).to match_array(
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
        )
      end
    end

    context 'when pre_approved_agent_privileges is provided' do
      before do
        allow(Gitlab::AiGateway).to receive(:public_headers).and_return({})
      end

      it 'ignores the parameter and creates workflow with the database default pre-approved privileges' do
        post api(path, user), params: params.merge(
          pre_approved_agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES]
        )

        expect(response).to have_gitlab_http_status(:created)

        created_workflow = Ai::DuoWorkflows::Workflow.last
        # pre_approved_agent_privileges is not accepted by this endpoint, so the passed value is ignored
        # and the DB default [READ_WRITE_FILES, READ_ONLY_GITLAB] is used instead
        expect(created_workflow.pre_approved_agent_privileges).to match_array([
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB
        ])
      end
    end

    context 'when workflow creation fails' do
      context 'when user is not a developer' do
        let(:user) { create(:user, guest_of: project) }

        it_behaves_like 'workflow access is forbidden'
      end

      context 'when duo_features_enabled is off' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
          project.reload
        end

        it_behaves_like 'workflow access is forbidden'
      end

      context 'when there are not enough credits' do
        before do
          allow_next_instance_of(Ai::UsageQuotaService) do |instance|
            allow(instance).to receive(:execute).and_return(
              ServiceResponse.error(message: "Usage quota exceeded", reason: :usage_quota_exceeded)
            )
          end
        end

        it_behaves_like 'workflow access is forbidden'
      end
    end

    it_behaves_like 'start workflow execution'

    it_behaves_like 'foundational flow workflow creation'

    it_behaves_like 'ai catalog item consumer workflow execution'

    it_behaves_like 'ai catalog item version workflow creation'

    it_behaves_like 'issue and merge request association for workflows'

    it_behaves_like 'container resolution for workflows'

    context 'when agent sends project path with issue IID (agent-initiated linkage)' do
      let(:agent_params) do
        {
          project_id: project.full_path,
          workflow_definition: 'developer/v1',
          goal: 'implement feature X',
          issue_id: issue.iid,
          environment: 'ambient'
        }
      end

      before do
        allow(Gitlab::AiGateway).to receive(:public_headers).and_return({})
      end

      it 'creates workflow linked to the issue with a system note', :aggregate_failures do
        expect(SystemNoteService).to receive(:agent_session_started).with(
          issue,
          project,
          be_a(Integer),
          user,
          anything
        )

        post api(path, user), params: agent_params

        expect(response).to have_gitlab_http_status(:created)

        created_workflow = Ai::DuoWorkflows::Workflow.last
        expect(created_workflow.project).to eq(project)
        expect(created_workflow.issue).to eq(issue)
        expect(created_workflow.merge_request).to be_nil
        expect(created_workflow.environment).to eq('ambient')
      end
    end

    context 'when service account is resolved' do
      let_it_be(:foundational_flow_group) { create(:group) }
      let(:foundational_params) do
        {
          project_id: foundational_flow_project.id,
          workflow_definition: 'fix_pipeline/v1',
          goal: 'Fix the pipeline',
          start_workflow: true
        }
      end

      let_it_be(:foundational_flow_service_account) do
        create(:user, :service_account,
          provisioned_by_group: foundational_flow_group
        )
      end

      let_it_be_with_reload(:foundational_flow_item) do
        create(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'fix_pipeline/v1')
      end

      let_it_be(:foundational_flow_consumer) do
        create(:ai_catalog_item_consumer,
          item: foundational_flow_item,
          group: foundational_flow_group,
          service_account: foundational_flow_service_account
        )
      end

      let_it_be_with_reload(:foundational_flow_project) do
        create(:project, :repository, group: foundational_flow_group, developers: user)
      end

      let_it_be(:foundational_flow_project_consumer) do
        create(:ai_catalog_item_consumer,
          item: foundational_flow_item,
          project: foundational_flow_project,
          parent_item_consumer: foundational_flow_consumer
        )
      end

      let_it_be(:foundational_flow_enabled) do
        create(:ai_catalog_enabled_foundational_flow, :for_project,
          project: foundational_flow_project,
          catalog_item: foundational_flow_item)
      end

      before_all do
        foundational_flow_group.add_developer(user)
        foundational_flow_project.update!(duo_features_enabled: true, duo_remote_flows_enabled: true,
          duo_foundational_flows_enabled: true)
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

      it 'passes the resolved service_account to StartWorkflowService' do
        expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
          hash_including(
            params: hash_including(service_account: foundational_flow_service_account)
          )
        ).and_wrap_original do |original, **kwargs|
          instance = original.call(**kwargs)
          allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: { workload_id: 1 }))
          instance
        end

        post api(path, user), params: foundational_params

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    # An agent caller must not reach the client-executed branch, whatever it passes.
    context 'when an agent delegates a foundational flow to a group' do
      let_it_be(:delegated_item) do
        create(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'developer/v1')
      end

      let(:params) do
        { namespace_id: group.id, workflow_definition: 'developer/v1', goal: 'Do the thing' }
      end

      before do
        stub_feature_flags(duo_client_executed_flow_governance: true)
        allow(::Ai::Catalog::FoundationalFlow['developer/v1']).to receive(:catalog_item)
          .and_return(delegated_item)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :foundational_flows).and_return(true)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, group).and_return(true)
      end

      it 'stays catalog-governed even without start_workflow' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the caller sends an environment' do
      let(:params) { super().merge(environment: 'ambient') }

      it 'stores it exactly as sent' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(Ai::DuoWorkflows::Workflow.last.environment).to eq('ambient')
      end
    end

    context 'when workflow access is forbidden' do
      let(:user) { create(:user, guest_of: project) }

      it_behaves_like 'workflow access is forbidden'
    end
  end
end

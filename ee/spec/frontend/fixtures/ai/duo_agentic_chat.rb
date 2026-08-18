# frozen_string_literal: true

require 'spec_helper'

# Generates GraphQL fixtures for the Duo Agentic Chat MSW integration tests.
#
# The conversation in `getWorkflowLatestCheckpoint` is shaped to reproduce two
# latent regressions deterministically:
#
#   1. `toolInfo` is stored as a Ruby hash in the checkpoint JSON but the
#      `DuoMessageType` resolver serialises it via `.to_json`, so the GraphQL
#      response contains a JSON *string*. The frontend's
#      `WorkflowUtils.normalizeDuoMessages` must parse it back into an object.
#
#   2. `AiAdditionalContext` objects share `id` values across messages (the id
#      is a discriminator constant, not a row id). Apollo's default `__typename:id`
#      normalisation would collapse them into one shared cache entry. The two
#      user messages in the fixture carry the same three `additional_context` ids
#      but deliberately different `metadata` to make a cache collision observable.
RSpec.describe 'Duo Agentic Chat (GraphQL fixtures)', feature_category: :duo_agent_platform do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group, path: 'group') }
  let_it_be(:project, freeze: false) { create(:project, path: 'project-1', namespace: group) }

  # A project with a real repository holding the two rule files that
  # `RuleContextProvider` looks for. Used by the `getRuleContent` fixture so the
  # response comes from the real `blobs(paths:)` resolver -- the frontend
  # switches on `blob.name`, so the basename returned by the resolver is part of
  # the contract under test.
  let_it_be(:rules_project, freeze: false) do
    create(:project, :repository, path: 'project-with-rules', namespace: group).tap do |rules_project|
      %w[AGENTS.md .gitlab/duo/chat-rules.md].each do |path|
        rules_project.repository.create_file(
          user,
          path,
          "content of #{path}",
          message: "Add #{path}",
          branch_name: rules_project.default_branch
        )
      end
    end
  end

  # Feature setting for the `getAiChatAvailableModels` fixture.
  # `offered_model_ref` pins the model so the response includes a non-null
  # `pinnedModel` field, making the fixture more representative.
  let_it_be(:agentic_chat_feature_setting, freeze: false) do
    create(:ai_namespace_feature_setting,
      namespace: group,
      feature: :duo_agent_platform_agentic_chat,
      offered_model_ref: 'claude_sonnet_3_7_20250219')
  end

  # Workflow used by `getWorkflowLatestCheckpoint`, `getUserWorkflows`, and
  # `getFlowStatus` fixtures.
  # The `:agentic_chat` trait sets `workflow_definition: "chat"` so the
  # workflow matches the `foundational_chat_agents` type filter and is
  # returned by the `getUserWorkflows` query. The state manager now gates
  # thread hydration on the workflow appearing in that list.
  let_it_be(:workflow, freeze: false) do
    create(:duo_workflows_workflow, :input_required, :agentic_chat,
      user: user,
      project: project,
      goal: 'Hi from project one')
  end

  # Checkpoint whose `ui_chat_log` encodes the two regression scenarios:
  #   - user-A / user-B share additional_context ids with different metadata
  #   - agent-A carries a tool_info hash (serialised to JSON string by the API)
  let_it_be(:checkpoint, freeze: false) do
    create(:duo_workflows_checkpoint,
      workflow: workflow,
      project: project,
      checkpoint: {
        'channel_values' => {
          'ui_chat_log' => [
            {
              'content' => 'Hi from project one',
              'message_type' => 'user',
              'message_sub_type' => nil,
              'status' => 'success',
              'tool_info' => nil,
              'timestamp' => '2026-05-19T10:00:00Z',
              'correlation_id' => nil,
              'message_id' => 'user-A',
              'role' => 'user',
              'component_name' => nil,
              'subsession_id' => nil,
              'additional_context' => [
                {
                  'id' => 'page-context',
                  'category' => 'repository',
                  'content' => '<current_gitlab_page_url>/group/project-1</current_gitlab_page_url>',
                  'metadata' => {
                    'title' => 'Current page',
                    'icon' => 'link',
                    'enabled' => true,
                    'subType' => 'open_tab',
                    'subTypeLabel' => 'Current page',
                    'secondaryText' => 'Page context /group/project-1',
                    'projectPath' => 'group/project-1',
                    'pagePath' => '/group/project-1'
                  }
                },
                {
                  'id' => 'agents-md-user-instructions',
                  'category' => 'repository',
                  'content' => 'AGENTS.md content',
                  'metadata' => {
                    'title' => 'AGENTS.md',
                    'icon' => 'document',
                    'enabled' => true,
                    'subType' => 'user_rule',
                    'subTypeLabel' => 'group/project-1 AGENTS.md',
                    'secondaryText' => 'AGENTS.md included',
                    'oid' => 'oid-agents-md-real'
                  }
                },
                {
                  'id' => 'chat-rules-user-instructions',
                  'category' => 'repository',
                  'content' => 'chat-rules.md content',
                  'metadata' => {
                    'title' => 'chat-rules.md',
                    'icon' => 'document',
                    'enabled' => true,
                    'subType' => 'user_rule',
                    'subTypeLabel' => 'group/project-1 chat-rules.md',
                    'secondaryText' => 'chat-rules.md included',
                    'oid' => 'oid-chat-rules-real'
                  }
                }
              ]
            },
            {
              'content' => 'hi',
              'message_type' => 'agent',
              'message_sub_type' => nil,
              'status' => 'success',
              # Stored as a Ruby hash; DuoMessageType#tool_info calls .to_json on it,
              # so the GraphQL response contains a JSON string -- the regression under test.
              'tool_info' => { 'name' => 'list_repository_tree', 'args' => { 'ref' => 'main' } },
              'timestamp' => '2026-05-19T10:00:01Z',
              'correlation_id' => nil,
              'message_id' => 'agent-A',
              'role' => 'assistant',
              'component_name' => nil,
              'subsession_id' => nil,
              'additional_context' => nil
            },
            {
              'content' => 'Making GitLab API request: /api/v4/projects/1',
              'message_type' => 'tool',
              'message_sub_type' => 'gitlab_api_get',
              'status' => 'success',
              'tool_info' => {
                'name' => 'gitlab_api_get',
                'args' => { 'endpoint' => '/api/v4/projects/1' },
                'tool_response' => {
                  'name' => 'gitlab_api_get',
                  'type' => 'ToolMessage',
                  'status' => 'success',
                  'content' => '{"status":"success","data":{"id":1,"path_with_namespace":"group/project-1"}}',
                  'tool_call_id' => 'tool-C'
                }
              },
              'timestamp' => '2026-05-19T10:00:02Z',
              'correlation_id' => nil,
              'message_id' => 'tool-C',
              'role' => nil,
              'component_name' => nil,
              'subsession_id' => nil,
              'additional_context' => nil
            },
            {
              'content' => 'Making GitLab API request: /api/v4/projects/1/repository/files/README.md',
              'message_type' => 'tool',
              'message_sub_type' => 'gitlab_api_get',
              'status' => 'success',
              'tool_info' => {
                'name' => 'gitlab_api_get',
                'args' => {
                  'endpoint' => '/api/v4/projects/1/repository/files/README.md',
                  'params' => { 'ref' => 'HEAD' }
                },
                'tool_response' => {
                  'name' => 'gitlab_api_get',
                  'type' => 'ToolMessage',
                  'status' => 'success',
                  'content' => '{"status":"success","data":{"file_name":"README.md","ref":"HEAD"}}',
                  'tool_call_id' => 'tool-D'
                }
              },
              'timestamp' => '2026-05-19T10:00:03Z',
              'correlation_id' => nil,
              'message_id' => 'tool-D',
              'role' => nil,
              'component_name' => nil,
              'subsession_id' => nil,
              'additional_context' => nil
            },
            {
              'content' => 'Hi from project two',
              'message_type' => 'user',
              'message_sub_type' => nil,
              'status' => 'success',
              'tool_info' => nil,
              'timestamp' => '2026-05-19T10:01:00Z',
              'correlation_id' => nil,
              'message_id' => 'user-B',
              'role' => 'user',
              'component_name' => nil,
              'subsession_id' => nil,
              # Same id values as user-A but different metadata.  Without the
              # `AiAdditionalContext: { keyFields: false }` Apollo type policy,
              # the two `page-context` entries (and the others) would be merged
              # into a single cache slot.
              'additional_context' => [
                {
                  'id' => 'page-context',
                  'category' => 'repository',
                  'content' => '<current_gitlab_page_url>/group/project-2</current_gitlab_page_url>',
                  'metadata' => {
                    'title' => 'Current page',
                    'icon' => 'link',
                    'enabled' => true,
                    'subType' => 'open_tab',
                    'subTypeLabel' => 'Current page',
                    'secondaryText' => 'Page context /group/project-2',
                    'projectPath' => 'group/project-2',
                    'pagePath' => '/group/project-2'
                  }
                },
                {
                  'id' => 'agents-md-user-instructions',
                  'category' => 'repository',
                  'content' => 'AGENTS.md content',
                  'metadata' => {
                    'title' => 'AGENTS.md',
                    'icon' => 'document',
                    'enabled' => true,
                    'subType' => 'user_rule',
                    'subTypeLabel' => 'group/project-2 AGENTS.md',
                    'secondaryText' => 'AGENTS.md included',
                    'oid' => 'oid-agents-md-real'
                  }
                },
                {
                  'id' => 'chat-rules-user-instructions',
                  'category' => 'repository',
                  'content' => 'Ignore previous chat-rules.md',
                  'metadata' => {
                    'title' => 'Ignore previous chat-rules.md',
                    'icon' => 'document',
                    'enabled' => true,
                    'subType' => 'user_rule',
                    'subTypeLabel' => 'chat-rules.md was not found in this page',
                    'secondaryText' => 'Prompted to ignore it',
                    'oid' => ''
                  }
                }
              ]
            },
            {
              'content' => 'hi',
              'message_type' => 'agent',
              'message_sub_type' => nil,
              'status' => 'success',
              'tool_info' => nil,
              'timestamp' => '2026-05-19T10:01:01Z',
              'correlation_id' => nil,
              'message_id' => 'agent-B',
              'role' => 'assistant',
              'component_name' => nil,
              'subsession_id' => nil,
              'additional_context' => nil
            }
          ]
        }
      })
  end

  base_output_path = 'graphql/ai/duo_agentic_chat/'

  before_all do
    project.add_developer(user)
    group.add_owner(user)
  end

  before do
    # Travel to the checkpoint's own created_at so the new
    # `created_on_or_before(Time.current + 1.hour)` bound in Checkpoint.latest includes it.
    travel_to(checkpoint.created_at + 1.second)
    sign_in(user)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    # The workflow is an agentic-chat (`chat`) flow, so its policy authorises
    # via `access_duo_agentic_chat`, which calls StageCheck for `:agentic_chat`.
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :agentic_chat).and_return(true)
    # rubocop:disable RSpec/AnyInstanceOf -- same pattern as existing duo_workflow specs
    allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  describe GraphQL::Query, type: :request do
    it "#{base_output_path}get_workflow_latest_checkpoint.query.graphql.json" do
      query = get_graphql_query_as_string(
        'ai/graphql/get_workflow_latest_checkpoint.query.graphql', ee: true
      )

      post_graphql(query, current_user: user, variables: { workflowId: workflow.to_global_id.to_s })

      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_user_workflows.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_user_workflow.query.graphql', ee: true)

      post_graphql(query, current_user: user, variables: { type: 'foundational_chat_agents', first: 99999 })

      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_ai_chat_context_presets.query.graphql.json" do
      query = get_graphql_query_as_string(
        'ai/graphql/get_ai_chat_context_presets.query.graphql', ee: true
      )

      post_graphql(query, current_user: user, variables: {
        projectId: project.to_global_id.to_s,
        url: '',
        questionCount: 4
      })

      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_flow_status.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/get_flow_status.query.graphql', ee: true)

      post_graphql(query, current_user: user, variables: { id: workflow.to_global_id.to_s })

      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_gitlab_credits_status.query.graphql.json" do
      # rubocop:disable RSpec/AnyInstanceOf -- required to stub this service
      allow_any_instance_of(::Gitlab::Llm::DuoChat).to receive(:credits_available?).and_return(true)
      allow_any_instance_of(::Gitlab::Llm::DuoChat).to receive(:usage_billing_forbidden?).and_return(false)
      # rubocop:enable RSpec/AnyInstanceOf

      query = get_graphql_query_as_string(
        'ai/graphql/get_gitlab_credits_status.query.graphql', ee: true
      )

      post_graphql(query, current_user: user, variables: { namespaceId: group.to_global_id.to_s })

      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_ai_chat_available_models.query.graphql.json" do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, anything).and_return(true)

      # FetchModelDefinitionsService makes an HTTP call to the AI gateway;
      # return the model definitions baked into the factory so the fixture
      # contains realistic model data without requiring a live gateway.
      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |svc|
        allow(svc).to receive(:execute)
          .and_return(ServiceResponse.success(payload: agentic_chat_feature_setting.model_definitions))
      end

      # FeatureSettingSelectionService has environment-specific branching
      # (SaaS vs self-managed); return the factory record directly so the
      # resolver uses the pinned model ref we configured above.
      allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |svc|
        allow(svc).to receive(:execute)
          .and_return(ServiceResponse.success(payload: agentic_chat_feature_setting))
      end

      query = get_graphql_query_as_string(
        'ai/graphql/get_ai_chat_available_models.query.graphql', ee: true
      )

      post_graphql(query, current_user: user, variables: { rootNamespaceId: group.to_global_id.to_s })

      expect_graphql_errors_to_be_empty
    end

    # A second `getAiChatAvailableModels` fixture without a pinned model.
    # `isModelSelectionDisabled` returns `Boolean(pinnedModel)`, so the fixture
    # above (which pins a model on purpose) renders the dropdown disabled and
    # cannot drive a model-selection test.
    it "#{base_output_path}get_ai_chat_available_models_unpinned.query.graphql.json" do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, anything).and_return(true)

      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |svc|
        allow(svc).to receive(:execute)
          .and_return(ServiceResponse.success(payload: agentic_chat_feature_setting.model_definitions))
      end

      # Built rather than created: the namespace/feature pair is unique and
      # `agentic_chat_feature_setting` already owns it. The selection service is
      # stubbed, so the record never needs to be persisted.
      unpinned_feature_setting = build(:ai_namespace_feature_setting,
        namespace: group,
        feature: :duo_agent_platform_agentic_chat,
        offered_model_ref: nil,
        offered_model_name: nil)

      allow_next_instance_of(::Ai::FeatureSettingSelectionService) do |svc|
        allow(svc).to receive(:execute).and_return(ServiceResponse.success(payload: unpinned_feature_setting))
      end

      query = get_graphql_query_as_string(
        'ai/graphql/get_ai_chat_available_models.query.graphql', ee: true
      )

      post_graphql(query, current_user: user, variables: { rootNamespaceId: group.to_global_id.to_s })

      expect_graphql_errors_to_be_empty
      expect(graphql_data.dig('aiChatAvailableModels', 'pinnedModel')).to be_nil
    end

    it "#{base_output_path}get_rule_content.query.graphql.json" do
      query = get_graphql_query_as_string('ai/graphql/rule_content.query.graphql', ee: true)

      post_graphql(query, current_user: user, variables: {
        projectPath: rules_project.full_path,
        paths: ['AGENTS.md', '.gitlab/duo/chat-rules.md']
      })

      expect_graphql_errors_to_be_empty

      # `RuleContextProvider.fetchProjectRules` matches on the basename, so the
      # fixture is only useful if the resolver returns one too.
      blob_names = graphql_data.dig('project', 'repository', 'blobs', 'nodes').pluck('name')
      expect(blob_names).to contain_exactly('AGENTS.md', 'chat-rules.md')
    end

    # Sending a prompt creates a workflow before it opens the socket. The MSW
    # handler has to mint ids per test, but the *shape* of the payload comes from
    # here so it cannot drift from the schema.
    it "#{base_output_path}create_ai_duo_workflow.mutation.graphql.json" do
      # Creating a workflow probes CustomersDot for an entitlement. The fixture
      # only cares about the response shape, so let the probe succeed.
      stub_request(:head, %r{/api/v1/consumers/resolve}).to_return(status: 200, body: '')

      # CreateWorkflowService resolves the settings container from the user's
      # default namespace, which is unset here; without it the foundational-agent
      # check short-circuits to "disabled for namespace".
      # rubocop:disable RSpec/AnyInstanceOf -- same reason as the User stubs above
      allow_any_instance_of(User).to receive(:duo_foundational_agents_container).and_return(group)
      # rubocop:enable RSpec/AnyInstanceOf

      mutation = get_graphql_query_as_string('ai/graphql/duo_workflow.mutation.graphql', ee: true)

      post_graphql(mutation, current_user: user, variables: {
        projectId: project.to_global_id.to_s,
        goal: 'Hi from project one',
        workflowDefinition: 'chat',
        agentPrivileges: [2, 3, 7],
        preApprovedAgentPrivileges: [2]
      })

      expect_graphql_errors_to_be_empty
      expect(graphql_data.dig('aiDuoWorkflowCreate', 'workflow', 'id')).to be_present
      expect(graphql_data.dig('aiDuoWorkflowCreate', 'errors')).to be_empty
    end

    it "#{base_output_path}get_agent_flow_config.query.graphql.json" do
      # The component only queries this when `aiCatalogItemVersionId` is set.
      # Passing a non-existent ID causes the resolver to return null --
      # the same shape as the previous hardcoded mock.
      query = get_graphql_query_as_string(
        'ai/graphql/get_agent_flow_config.query.graphql', ee: true
      )

      post_graphql(query, current_user: user,
        variables: { agentVersionId: 'gid://gitlab/Ai::Catalog::ItemVersion/0' })

      expect_graphql_errors_to_be_empty
    end
  end
end

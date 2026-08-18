# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Many cases to deal with here.
RSpec.describe 'Querying Duo Workflows Workflows', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:ai_settings, freeze: false) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be(:group, freeze: false) { create(:group, ai_settings: ai_settings) }
  let_it_be(:project, freeze: false) { create(:project, :public, group: group) }
  let_it_be(:project_2, freeze: false) { create(:project, :public, group: group) }
  let_it_be(:user, freeze: false) { create(:user, developer_of: group) }
  let_it_be(:another_user, freeze: false) { create(:user, developer_of: group) }
  let_it_be(:workflow_without_environment, freeze: false) do
    create(:duo_workflows_workflow, project: project, user: user, created_at: 1.day.ago).tap do |workflow|
      workload = create(:ci_workload, project: project)
      workflow.workflows_workloads.create!(workload: workload, project: project)
      create(:ci_build, pipeline: workload.pipeline, project: project)
    end
  end

  let_it_be(:ai_catalog_item_version, freeze: false) { create(:ai_catalog_agent_version) }

  let_it_be(:workflow_with_ide_environment, freeze: false) do
    create(:duo_workflows_workflow, environment: :ide, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:workflow_with_web_environment, freeze: false) do
    create(:duo_workflows_workflow, environment: :web, project: project, user: user, created_at: 1.day.ago)
  end

  let_it_be(:remote_execution_workflow_another_user, freeze: false) do
    create(:duo_workflows_workflow, project: project, user: another_user, environment: :web,
      workflow_definition: :convert_to_gitlab_ci)
  end

  let_it_be(:archived_workflow, freeze: false) do
    create(:duo_workflows_workflow,
      project: project,
      user: user,
      created_at: (Ai::DuoWorkflows::CHECKPOINT_RETENTION_DAYS + 1).days.ago)
  end

  let_it_be(:stalled_workflow, freeze: false) do
    workflow = create(:duo_workflows_workflow, project: project, user: user)
    workflow.start!
    workflow
  end

  let_it_be(:non_stalled_workflow_with_checkpoint, freeze: false) do
    workflow = create(:duo_workflows_workflow, project: project, user: user)
    workflow.start!
    create(:duo_workflows_checkpoint, workflow: workflow, project: workflow.project)
    workflow
  end

  let_it_be(:namespace_level_workflow, freeze: false) do
    create(:duo_workflows_workflow, :agentic_chat, namespace: group, user: user)
  end

  let_it_be(:workflows, freeze: false) do
    [
      workflow_without_environment,
      workflow_with_ide_environment,
      workflow_with_web_environment,
      archived_workflow,
      stalled_workflow,
      non_stalled_workflow_with_checkpoint
    ]
  end

  let_it_be(:workflows_project_2, freeze: false) do
    create_list(:duo_workflows_workflow, 2, project: project_2, user: user,
      ai_catalog_item_version: ai_catalog_item_version)
  end

  let_it_be(:workflows_for_different_user, freeze: false) do
    create_list(:duo_workflows_workflow, 4, project: project, user: another_user)
  end

  let(:all_project_workflows) { workflows + workflows_project_2 }
  let(:all_namespace_workflows) { [namespace_level_workflow] }

  let(:fields) do
    <<~GRAPHQL
      pageInfo {
        hasPreviousPage
        hasNextPage
        endCursor
      }
      nodes {
        id,
        userId,
        projectId,
        project {
          id
          name
        },
        namespaceId,
        namespace {
          id
          name
        },
        humanStatus,
        goal,
        workflowDefinition,
        environment,
        createdAt,
        updatedAt,
        status,
        statusName,
        statusGroup,
        agentPrivilegesNames,
        preApprovedAgentPrivilegesNames,
        mcpEnabled
        incrementalCheckpointsEnabled
        allowAgentToRequestUser
        archived
        stalled
        firstCheckpoint {
          checkpoint
          metadata
          threadTs
          workflowStatus
          duoMessages {
            content
            messageType
            status
            toolInfo
            timestamp
            correlationId
            role
            messageId
            additionalContext {
              id
              category
              content
              metadata
            }
          }
          lastDuoMessage {
            content
            messageId
          }
          checkpointWrites {
            id
            threadTs
            task
            idx
            channel
            writeType
            data
          }
        }
        latestCheckpoint {
          checkpoint
          metadata
          threadTs
          workflowStatus
          duoMessages {
            content
            messageType
            status
            toolInfo
            timestamp
            correlationId
            role
            messageId
            threadTs
            parentTs
            alternativeCount
            additionalContext {
              id
              category
              content
              metadata
            }
          }
          checkpointWrites {
            id
            threadTs
            task
            idx
            channel
            writeType
            data
          }
        }
        lastExecutorLogsUrl
        allExecutorLogsUrls
        aiCatalogItemVersionId
        agentName
        modelMetadataName
        modelMetadataIdentifier
        flowMetadataVersion
        flowMetadataId
        flowMetadataSchemaVersion
        title
        summary
      }
    GRAPHQL
  end

  let(:variables) { nil }
  let(:current_user) { user }
  let(:query) { graphql_query_for('duoWorkflowWorkflows', variables, fields) }

  # Create a checkpoint for the first workflow to test the firstCheckpoint field
  let_it_be(:checkpoint, freeze: false) do
    workflow = workflows.first
    create(:duo_workflows_checkpoint, workflow: workflow, project: workflow.project)
  end

  before do
    # Allow StageCheck for any project
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(false)
  end

  subject(:returned_workflows) { graphql_data.dig('duoWorkflowWorkflows', 'nodes') }

  context 'when duo workflow is not available' do
    # Anonymous requests are capped at GitlabSchema::DEFAULT_MAX_COMPLEXITY, so keep the
    # query minimal here since only emptiness of the result is being asserted.
    let(:fields) { 'nodes { id }' }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(false)
    end

    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(returned_workflows).to be_empty
    end
  end

  context 'when duo workflow is available' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(true)
    end

    context 'when user is not logged in' do
      # Anonymous requests are capped at GitlabSchema::DEFAULT_MAX_COMPLEXITY, so keep the
      # query minimal here since only emptiness of the result is being asserted.
      let(:fields) { 'nodes { id }' }

      it 'returns an empty array' do
        post_graphql(query, current_user: nil)

        expect(returned_workflows).to be_empty
      end
    end

    context 'when the user does not have access to the project' do
      let(:current_user) { create(:user) }

      it 'returns an empty array', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil
        expect(returned_workflows).to be_empty
      end
    end

    context 'when the user has access to the project and is allowed to use duo_agent_platform' do
      before do
        # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
        allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
        # rubocop:enable RSpec/AnyInstanceOf
      end

      it 'returns the workflows' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil

        expect(returned_workflows).not_to be_empty
        expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
        all_workflows_by_id = (all_project_workflows + all_namespace_workflows).index_by { |w| w.to_global_id.to_s }
        returned_workflows.each do |returned_workflow|
          matching_workflow = all_workflows_by_id[returned_workflow['id']]
          expect(matching_workflow).not_to be_nil
          expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)

          if matching_workflow.project_level?
            expect(returned_workflow['projectId']).to eq(matching_workflow.project.to_global_id.to_s)
            expect(returned_workflow['project']['id']).to eq(matching_workflow.project.to_global_id.to_s)
            expect(returned_workflow['project']['name']).to eq(matching_workflow.project.name)
            expect(returned_workflow['namespaceId']).to be_nil
            expect(returned_workflow['namespace']).to be_nil
          elsif matching_workflow.namespace_level?
            expect(returned_workflow['projectId']).to be_nil
            expect(returned_workflow['project']).to be_nil
            expect(returned_workflow['namespaceId'])
              .to eq("gid://gitlab/Types::Namespace/#{matching_workflow.namespace.id}")
            expect(returned_workflow['namespace']['id']).to eq(matching_workflow.namespace.to_global_id.to_s)
            expect(returned_workflow['namespace']['name']).to eq(matching_workflow.namespace.name)
          end

          expect(returned_workflow['humanStatus']).to eq(matching_workflow.human_status_name)
          expect(returned_workflow['createdAt']).to eq(matching_workflow.created_at.iso8601)
          expect(returned_workflow['updatedAt']).to eq(matching_workflow.updated_at.iso8601)
          expect(returned_workflow['goal']).to eq("Fix pipeline")
          expect(returned_workflow['workflowDefinition']).to eq(matching_workflow.workflow_definition)
          expected_status = case matching_workflow
                            when stalled_workflow, non_stalled_workflow_with_checkpoint
                              "RUNNING"
                            else
                              "CREATED"
                            end
          expect(returned_workflow['status']).to eq(expected_status)
          expect(returned_workflow['statusName']).to eq(matching_workflow.status_name.to_s)
          expect(returned_workflow['statusGroup']).to eq(matching_workflow.status_group.to_s.upcase)
          expect(returned_workflow['agentPrivilegesNames']).to eq(["read_write_files"])
          expect(returned_workflow['preApprovedAgentPrivilegesNames']).to eq([])
          expect(returned_workflow['mcpEnabled']).to eq(matching_workflow.mcp_enabled?)
          expect(returned_workflow['incrementalCheckpointsEnabled'])
            .to eq(matching_workflow.incremental_checkpoints_enabled)
          expect(returned_workflow['allowAgentToRequestUser']).to eq(matching_workflow.allow_agent_to_request_user)
          expect(returned_workflow['lastExecutorLogsUrl']).to eq(matching_workflow.last_executor_logs_url)
          expect(returned_workflow['aiCatalogItemVersionId']).to eq(
            matching_workflow.ai_catalog_item_version&.to_global_id&.to_s
          )
          expect(returned_workflow['title']).to eq(matching_workflow.title)
          expect(returned_workflow['summary']).to eq(matching_workflow.summary)

          expect(returned_workflow).to have_key('firstCheckpoint')
        end
      end

      context 'with the project_path argument' do
        let(:variables) { { project_path: project.full_path } }

        it 'returns only the workflows for that project owned by that user', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(workflows.length)
          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['userId']).to eq(user.to_global_id.to_s)
          end
        end
      end

      context 'when scoped under a project' do
        let_it_be(:project_fields, freeze: false) do
          <<~GRAPHQL
            duoWorkflowWorkflows {
              nodes {
                id
              }
            }
          GRAPHQL
        end

        let_it_be(:project_query, freeze: false) do
          graphql_query_for('project', { full_path: project.full_path }, project_fields)
        end

        it 'returns .from_pipeline workflows for the project', :aggregate_failures do
          post_graphql(project_query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          project_workflows = graphql_data.dig("project", "duoWorkflowWorkflows", "nodes")
          expect(project_workflows.length).to eq(2)

          expected_workflows = Ai::DuoWorkflows::Workflow.for_project(project).from_pipeline
          expected_global_ids = expected_workflows.map { |workflow| workflow.to_global_id.to_s }
          project_workflows_ids = project_workflows.pluck("id")

          expect(expected_global_ids).to match_array(project_workflows_ids)
        end
      end

      context 'with the environment argument' do
        context 'when environment argument is web' do
          let(:variables) { { environment: :WEB } }

          it 'returns only workflows with web environment', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(1)
            returned_workflows.each do |returned_workflow|
              expect(returned_workflow['environment']).to eq("WEB")
            end
          end
        end

        context 'when environment argument is not given' do
          let(:variables) { {} }

          it 'returns workflows independent of environment', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
          end
        end
      end

      context 'with the workflow_id argument' do
        let(:specific_workflow) { workflows.first }
        let(:variables) { { workflow_id: specific_workflow.to_global_id.to_s } }

        before do
          # Ensure the checkpoint is associated with the specific workflow
          specific_workflow.reload
        end

        it 'returns only the specified workflow', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(specific_workflow.to_global_id.to_s)
          expect(returned_workflows.first['userId']).to eq(user.to_global_id.to_s)
          expect(returned_workflows.first['projectId']).to eq(specific_workflow.project.to_global_id.to_s)
          expect(returned_workflows.first['project']['id']).to eq(specific_workflow.project.to_global_id.to_s)
          expect(returned_workflows.first['project']['name']).to eq(specific_workflow.project.name)
          expect(returned_workflows.first['namespaceId']).to be_nil
          expect(returned_workflows.first['namespace']).to be_nil
          expect(returned_workflows.first['goal']).to eq("Fix pipeline")
          expect(returned_workflows.first['workflowDefinition']).to eq("software_development")
          expect(returned_workflows.first['status']).to eq("CREATED")
          expect(returned_workflows.first['statusName']).to eq(specific_workflow.status_name.to_s)
          expect(returned_workflows.first['agentPrivilegesNames']).to eq(["read_write_files"])
          expect(returned_workflows.first['preApprovedAgentPrivilegesNames']).to eq([])
          expect(returned_workflows.first['mcpEnabled']).to eq(
            specific_workflow.project.root_ancestor.duo_workflow_mcp_enabled)
          expect(returned_workflows.first['allowAgentToRequestUser']).to eq(
            specific_workflow.allow_agent_to_request_user
          )
          expect(returned_workflows.first['lastExecutorLogsUrl']).not_to be_nil
          expect(returned_workflows.first['lastExecutorLogsUrl']).to eq(
                                                                       specific_workflow.last_executor_logs_url
                                                                     )
          expect(returned_workflows.first['allExecutorLogsUrls']).to eq(
                                                                       specific_workflow.all_executor_logs_urls
                                                                     )
          expect(returned_workflows.first['aiCatalogItemVersionId']).to eq(
            specific_workflow.ai_catalog_item_version&.to_global_id&.to_s
          )
          expect(returned_workflows.first).to have_key('firstCheckpoint')
        end

        context 'when checkpoint has duo messages with message_id and additional_context' do
          before do
            checkpoint.update!(checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  {
                    'content' => 'hello',
                    'message_type' => 'user',
                    'status' => 'success',
                    'tool_info' => nil,
                    'timestamp' => '2025-11-25T21:10:57.734182+00:00',
                    'correlation_id' => 'corr-abc',
                    'role' => nil,
                    'message_id' => 'msg-integration-1',
                    'additional_context' => [
                      {
                        'id' => 'ctx-1',
                        'category' => 'file',
                        'content' => 'file contents here',
                        'metadata' => { 'path' => 'README.md' }
                      }
                    ]
                  }
                ]
              }
            })
          end

          it 'returns message_id and additional_context in duoMessages', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)

            messages = returned_workflows.first.dig('firstCheckpoint', 'duoMessages')
            expect(messages).to be_present
            expect(messages.first['messageId']).to eq('msg-integration-1')
            expect(messages.first['additionalContext']).to eq([
              {
                'id' => 'ctx-1',
                'category' => 'FILE',
                'content' => 'file contents here',
                'metadata' => { 'path' => 'README.md' }
              }
            ])
          end
        end

        context 'when checkpoint has multiple duo messages' do
          before do
            checkpoint.update!(checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'content' => 'first', 'message_id' => 'msg-1' },
                  { 'content' => 'second', 'message_id' => 'msg-2' },
                  { 'content' => 'latest', 'message_id' => 'msg-3' }
                ]
              }
            })
          end

          it 'returns only the most recent message in lastDuoMessage', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)

            last_message = returned_workflows.first.dig('firstCheckpoint', 'lastDuoMessage')
            expect(last_message['content']).to eq('latest')
            expect(last_message['messageId']).to eq('msg-3')
          end
        end

        context 'when checkpoint has checkpoint writes' do
          let_it_be(:checkpoint_write, freeze: false) do
            create(:duo_workflows_checkpoint_write, workflow: checkpoint.workflow, thread_ts: checkpoint.thread_ts,
              project: checkpoint.workflow.project)
          end

          it 'returns the checkpoint writes in checkpointWrites', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)

            writes = returned_workflows.first.dig('firstCheckpoint', 'checkpointWrites')
            expect(writes).to contain_exactly(
              {
                'id' => checkpoint_write.to_global_id.to_s,
                'threadTs' => checkpoint_write.thread_ts,
                'task' => checkpoint_write.task,
                'idx' => checkpoint_write.idx,
                'channel' => checkpoint_write.channel,
                'writeType' => checkpoint_write.write_type,
                'data' => checkpoint_write.data
              }
            )
          end
        end

        context 'when the user does not have access to the workflow' do
          let(:specific_workflow) { workflows_for_different_user.first }
          let(:current_user) { create(:user) }

          it 'returns a permission error with INSUFFICIENT_NAMESPACE_PERMISSIONS code', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error = json_response['errors'].first
            expect(error['message']).to eq("You don't have permission to access this workflow.")
            expect(error['extensions']['code']).to eq('INSUFFICIENT_NAMESPACE_PERMISSIONS')
          end
        end

        context 'when the user has exceeded the unauthorized access rate limit' do
          let_it_be(:specific_workflow) { workflows_for_different_user.first }
          let_it_be(:current_user) { create(:user) }

          before do
            allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
            allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
              .with(:duo_workflow_unauthorized_access, scope: [current_user, specific_workflow])
              .and_return(true)
          end

          it 'returns a too many requests error without the permission error code', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error = json_response['errors'].first
            expect(error['message']).to eq('Too many requests.')
            expect(error.dig('extensions', 'code')).to be_nil
          end
        end

        context 'when the user needs to select a default namespace' do
          let(:specific_workflow) { workflows_for_different_user.first }
          let(:current_user) { create(:user) }
          let(:group_1) { create(:group) }
          let(:group_2) { create(:group) }

          before do
            # Setup user with multiple namespaces (Duo add-on seats)
            group_1.add_developer(current_user)
            group_2.add_developer(current_user)

            # Mock the user preference to simulate multiple namespace candidates with no default selected
            allow_next_instance_of(UserPreference) do |pref|
              allow(pref).to receive_messages(
                duo_default_namespace_with_fallback: nil,
                duo_default_namespace_candidates: Namespace.where(id: [group_1.id, group_2.id])
              )
            end
          end

          it 'returns a permission error with NO_DEFAULT_NAMESPACE code', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error = json_response['errors'].first
            expect(error['message']).to include("select a default namespace")
            expect(error['extensions']['code']).to eq('NO_DEFAULT_NAMESPACE')
          end
        end

        context 'when the workflow does not exist' do
          let(:variables) { { workflow_id: "gid://gitlab/Ai::DuoWorkflows::Workflow/#{non_existent_record_id}" } }
          let(:non_existent_record_id) { 999999 }

          it 'returns a resource not available error', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            error = json_response['errors'].first
            expect(error['message']).to eq('Workflow not found')
            expect(error['extensions']['code']).to eq('WORKFLOW_NOT_FOUND')
          end
        end

        context 'with namespace-level workflow' do
          let(:variables) { { workflow_id: namespace_level_workflow.to_global_id.to_s } }

          it 'returns only the specified workflow', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(1)
            expect(returned_workflows.first['id']).to eq(namespace_level_workflow.to_global_id.to_s)
            expect(returned_workflows.first['userId']).to eq(user.to_global_id.to_s)
            expect(returned_workflows.first['projectId']).to be_nil
            expect(returned_workflows.first['project']).to be_nil
            expect(returned_workflows.first['namespaceId'])
              .to eq("gid://gitlab/Types::Namespace/#{namespace_level_workflow.namespace.id}")
            expect(returned_workflows.first['namespace']['id'])
              .to eq(namespace_level_workflow.namespace.to_global_id.to_s)
            expect(returned_workflows.first['namespace']['name']).to eq(namespace_level_workflow.namespace.name)
          end
        end
      end

      context 'with a session with multiple branches (retries)' do
        # Say 2 was "retried" and Say 3/Say 4 were sent in the retry.
        # Say 3 was choosen, and Say 5 was sent to continue the branch.
        #
        #   Say 1              say_1     <- root
        #     1                answer_1  <- say_1
        #       Say 2          say_2     <- answer_1  (abandoned)
        #         2            answer_2  <- say_2
        #       Say 3          say_3     <- answer_1
        #         3            answer_3  <- say_3
        #           Say 5      say_5     <- answer_3
        #             5        answer_5  <- say_5
        #       Say 4          say_4     <- answer_1  (abandoned)
        #         4            answer_4  <- say_4
        let(:ts) do
          {
            root: '1f192411-91bf-6baf-bfff-b4779a56d807',
            say_1: '1f192411-91c3-6881-8000-e4befb64000c',
            answer_1: '1f192411-a2ba-6327-8001-222f6d14dde7',
            say_2: '1f192411-de85-670e-8002-c1a157799d0f',
            answer_2: '1f192412-0e7a-6f11-8003-5b1c2d3e4f50',
            say_3: '1f192413-729b-64be-8002-039f395ff2c8',
            answer_3: '1f192413-b136-6be0-8003-d085c4c28c04',
            say_4: '1f192413-dbfd-6cb7-8002-0c5c638e5999',
            answer_4: '1f192413-ef1b-68ef-8003-e497bd22eb13',
            say_5: '1f192415-a967-6c60-8004-a9eb76960a4d',
            answer_5: '1f192415-b616-6f5c-8005-397267e5a102'
          }
        end

        let(:forked_workflow) do
          create(:duo_workflows_workflow, project: project, user: current_user,
            incremental_checkpoints_enabled: true)
        end

        let(:variables) { { workflow_id: forked_workflow.to_global_id.to_s } }

        def msg(content, message_type)
          { 'content' => content, 'message_type' => message_type }
        end

        # A checkpoint as the gateway writes it under incremental checkpoints: a header
        # carrying the lineage, plus a zlib-compressed ui_chat_log delta.
        def add_checkpoint(thread_ts, parent_ts, version: nil, messages: [])
          create(:duo_workflows_checkpoint_header, workflow: forked_workflow,
            thread_ts: thread_ts, parent_ts: parent_ts, current_thread: 0)
          create(:duo_workflows_checkpoint, workflow: forked_workflow, project: project,
            thread_ts: thread_ts, parent_ts: parent_ts, current_thread: 0)
          return if messages.empty?

          create(:duo_workflows_checkpoint_blob, workflow: forked_workflow, thread_ts: thread_ts,
            current_thread: 0, channel: 'ui_chat_log', version: version, step_action: 'conversation',
            data: Zlib::Deflate.deflate(Gitlab::Json.dump(messages)))
        end

        before do
          stub_feature_flags(duo_workflow_read_incremental_checkpoints: project,
            dw_read_blobs_graphql: project)

          add_checkpoint(ts[:root], nil)
          add_checkpoint(ts[:say_1], ts[:root], version: '1', messages: [msg('Say 1', 'user')])
          add_checkpoint(ts[:answer_1], ts[:say_1], version: '2', messages: [msg('1', 'agent')])
          # Channel versions replay after a fork, so the abandoned branches reuse the
          # versions of the branch that replaced them.
          add_checkpoint(ts[:say_2], ts[:answer_1], version: '3', messages: [msg('Say 2', 'user')])
          add_checkpoint(ts[:answer_2], ts[:say_2], version: '4', messages: [msg('2', 'agent')])
          add_checkpoint(ts[:say_4], ts[:answer_1], version: '3', messages: [msg('Say 4', 'user')])
          add_checkpoint(ts[:answer_4], ts[:say_4], version: '4', messages: [msg('4', 'agent')])
          add_checkpoint(ts[:say_3], ts[:answer_1], version: '3', messages: [msg('Say 3', 'user')])
          add_checkpoint(ts[:answer_3], ts[:say_3], version: '4', messages: [msg('3', 'agent')])
          add_checkpoint(ts[:say_5], ts[:answer_3], version: '5', messages: [msg('Say 5', 'user')])
          add_checkpoint(ts[:answer_5], ts[:say_5], version: '6', messages: [msg('5', 'agent')])
        end

        it 'returns only the messages of the branch the latest checkpoint descends from' do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          contents = returned_workflows.first.dig('latestCheckpoint', 'duoMessages').pluck('content')

          expect(contents).to eq(['Say 1', '1', 'Say 3', '3', 'Say 5', '5'])
          # The retried turns and their answers are never rendered.
          expect(contents).to exclude('Say 2', '2', 'Say 4', '4')
        end

        it 'stamps every message with the checkpoint that introduced it and its fork point' do
          post_graphql(query, current_user: current_user)

          messages = returned_workflows.first.dig('latestCheckpoint', 'duoMessages')

          expect(messages.map { |message| message.values_at('content', 'threadTs', 'parentTs') }).to eq(
            [
              ['Say 1', ts[:say_1], ts[:root]],
              ['1', ts[:answer_1], ts[:say_1]],
              ['Say 3', ts[:say_3], ts[:answer_1]],
              ['3', ts[:answer_3], ts[:say_3]],
              ['Say 5', ts[:say_5], ts[:answer_3]],
              ['5', ts[:answer_5], ts[:say_5]]
            ]
          )
        end

        it 'counts the abandoned attempts on the user message of the retried turn' do
          post_graphql(query, current_user: current_user)

          messages = returned_workflows.first.dig('latestCheckpoint', 'duoMessages')

          # Say 3 replaced Say 2 and was itself retried as Say 4, so its turn has two
          # alternatives. Answers carry no count -- the user message anchors the turn.
          expect(messages.map { |message| message.values_at('content', 'alternativeCount') }).to eq(
            [['Say 1', 0], ['1', nil], ['Say 3', 2], ['3', nil], ['Say 5', 0], ['5', nil]]
          )
        end
      end

      context 'with the ids argument' do
        let(:requested_workflow_a) { workflow_with_ide_environment }
        let(:requested_workflow_b) { workflow_with_web_environment }

        let(:variables) do
          { ids: [requested_workflow_a.to_global_id.to_s, requested_workflow_b.to_global_id.to_s] }
        end

        it 'returns only workflows whose ids were supplied', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil
          expect(returned_workflows.pluck('id')).to match_array(
            [requested_workflow_a.to_global_id.to_s, requested_workflow_b.to_global_id.to_s]
          )
        end

        context 'with a single id' do
          let(:variables) { { ids: [requested_workflow_a.to_global_id.to_s] } }

          it 'returns the matching workflow', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(returned_workflows.pluck('id')).to match_array([requested_workflow_a.to_global_id.to_s])
          end
        end

        context 'when ids is an empty array' do
          let(:variables) { { ids: [] } }

          it 'returns an empty connection without falling back to all workflows', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil
            expect(returned_workflows).to be_empty
          end
        end

        context 'when ids references a workflow the current user cannot read' do
          let(:variables) do
            { ids: [requested_workflow_a.to_global_id.to_s, remote_execution_workflow_another_user.to_global_id.to_s] }
          end

          it 'filters out the unauthorized workflow', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(returned_workflows.pluck('id')).to match_array([requested_workflow_a.to_global_id.to_s])
          end
        end
      end

      context 'with toolCallApproved field' do
        let(:specific_workflow) { workflow_without_environment }
        let(:variables) { { workflow_id: specific_workflow.to_global_id.to_s } }
        let(:tool_name) { 'run_command' }
        let(:tool_call_args) { '{"command":"ls"}' }
        let(:query) do
          <<~GQL
            query {
              duoWorkflowWorkflows(workflowId: "#{specific_workflow.to_global_id}") {
                nodes {
                  id
                  toolCallApproved(toolName: "#{tool_name}", toolCallArgs: #{tool_call_args.to_json})
                }
              }
            }
          GQL
        end

        it 'returns false when no approvals exist' do
          post_graphql(query, current_user: current_user)

          expect(returned_workflows.first['toolCallApproved']).to be false
        end

        it 'returns true for exact match approval' do
          approvals = Ai::DuoWorkflows::Workflow::ToolCallApprovals.new
          approvals.add_approval(tool_name: 'run_command', call_args: tool_call_args)
          specific_workflow.update!(tool_call_approvals: approvals.to_h)

          post_graphql(query, current_user: current_user)

          expect(returned_workflows.first['toolCallApproved']).to be true
        end

        it 'returns true for pattern match approval' do
          git_args = '{"command":"git status"}'
          git_query = <<~GQL
            query {
              duoWorkflowWorkflows(workflowId: "#{specific_workflow.to_global_id}") {
                nodes {
                  id
                  toolCallApproved(toolName: "run_command", toolCallArgs: #{git_args.to_json})
                }
              }
            }
          GQL

          approvals = Ai::DuoWorkflows::Workflow::ToolCallApprovals.new
          approvals.add_pattern_approval(tool_name: 'run_command', pattern: 'git *')
          specific_workflow.update!(tool_call_approvals: approvals.to_h)

          post_graphql(git_query, current_user: current_user)

          expect(returned_workflows.first['toolCallApproved']).to be true
        end

        it 'returns false for non-matching tool' do
          approvals = Ai::DuoWorkflows::Workflow::ToolCallApprovals.new
          approvals.add_approval(tool_name: 'read_file', call_args: '{"path": "/tmp"}')
          specific_workflow.update!(tool_call_approvals: approvals.to_h)

          post_graphql(query, current_user: current_user)

          expect(returned_workflows.first['toolCallApproved']).to be false
        end

        it 'returns false when tool_call_approvals is empty' do
          specific_workflow.update!(tool_call_approvals: {})

          post_graphql(query, current_user: current_user)

          expect(returned_workflows.first['toolCallApproved']).to be false
        end
      end

      context 'with externalMcpBlocked field' do
        let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, organization: group.organization) }
        let_it_be(:mcp_agent_version) do
          create(:ai_catalog_agent_version, organization: group.organization, definition: {
            'system_prompt' => 'p', 'tools' => [], 'user_prompt' => '', 'mcp_servers' => [mcp_server.id]
          })
        end

        let_it_be(:mcp_workflow) do
          create(:duo_workflows_workflow, user: user, project: project,
            ai_catalog_item_version: mcp_agent_version)
        end

        let(:query) do
          <<~GQL
            query {
              duoWorkflowWorkflows(workflowId: "#{mcp_workflow.to_global_id}") {
                nodes { id externalMcpBlocked }
              }
            }
          GQL
        end

        before do
          stub_feature_flags(mcp_server_block_enforcement: true)
        end

        context 'when the attached MCP server is blocked for the group' do
          before do
            create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server,
              organization: group.organization)
          end

          it 'returns true' do
            post_graphql(query, current_user: current_user)

            expect(returned_workflows.first['externalMcpBlocked']).to be true
          end

          it 'returns false when enforcement is disabled' do
            stub_feature_flags(mcp_server_block_enforcement: false)

            post_graphql(query, current_user: current_user)

            expect(returned_workflows.first['externalMcpBlocked']).to be false
          end
        end

        it 'returns false when no server is blocked' do
          post_graphql(query, current_user: current_user)

          expect(returned_workflows.first['externalMcpBlocked']).to be false
        end

        it 'batches the blocks lookup and avoids N+1 across workflows' do
          create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server,
            organization: group.organization)
          create(:duo_workflows_workflow, user: user, project: project, ai_catalog_item_version: mcp_agent_version)

          list_query = <<~GQL
            query {
              duoWorkflowWorkflows {
                nodes { id externalMcpBlocked }
              }
            }
          GQL

          recorder = ActiveRecord::QueryRecorder.new do
            post_graphql(list_query, current_user: current_user)
          end

          block_queries = recorder.log.count { |sql| sql.include?('ai_catalog_mcp_server_blocks') }
          expect(block_queries).to be <= 1
        end

        context 'when the workflow has no catalog agent' do
          let(:query) do
            <<~GQL
              query {
                duoWorkflowWorkflows(workflowId: "#{workflow_without_environment.to_global_id}") {
                  nodes { id externalMcpBlocked }
                }
              }
            GQL
          end

          it 'returns false' do
            post_graphql(query, current_user: current_user)

            expect(returned_workflows.first['externalMcpBlocked']).to be false
          end
        end
      end

      context 'with toolCallApprovalMatch field' do
        let(:specific_workflow) { workflow_without_environment }
        let(:tool_name) { 'run_command' }
        let(:tool_call_args) { '{"command":"ls"}' }
        let(:query) do
          <<~GQL
            query {
              duoWorkflowWorkflows(workflowId: "#{specific_workflow.to_global_id}") {
                nodes {
                  id
                  toolCallApprovalMatch(toolName: "#{tool_name}", toolCallArgs: #{tool_call_args.to_json}) {
                    matched
                    matchType
                    matchedPattern
                  }
                }
              }
            }
          GQL
        end

        it 'returns unmatched when no approvals exist' do
          post_graphql(query, current_user: current_user)

          match = returned_workflows.first['toolCallApprovalMatch']
          expect(match).to eq('matched' => false, 'matchType' => nil, 'matchedPattern' => nil)
        end

        it 'returns EXACT_HASH for an exact match approval' do
          approvals = Ai::DuoWorkflows::Workflow::ToolCallApprovals.new
          approvals.add_approval(tool_name: 'run_command', call_args: tool_call_args)
          specific_workflow.update!(tool_call_approvals: approvals.to_h)

          post_graphql(query, current_user: current_user)

          match = returned_workflows.first['toolCallApprovalMatch']
          expect(match).to eq('matched' => true, 'matchType' => 'EXACT_HASH', 'matchedPattern' => nil)
        end

        it 'returns PATTERN and the winning pattern for a pattern match approval' do
          git_args = '{"command":"git status"}'
          git_query = <<~GQL
            query {
              duoWorkflowWorkflows(workflowId: "#{specific_workflow.to_global_id}") {
                nodes {
                  id
                  toolCallApprovalMatch(toolName: "run_command", toolCallArgs: #{git_args.to_json}) {
                    matched
                    matchType
                    matchedPattern
                  }
                }
              }
            }
          GQL

          approvals = Ai::DuoWorkflows::Workflow::ToolCallApprovals.new
          approvals.add_pattern_approval(tool_name: 'run_command', pattern: 'git *')
          specific_workflow.update!(tool_call_approvals: approvals.to_h)

          post_graphql(git_query, current_user: current_user)

          match = returned_workflows.first['toolCallApprovalMatch']
          expect(match).to eq('matched' => true, 'matchType' => 'PATTERN', 'matchedPattern' => 'git *')
        end

        it 'returns unmatched for a non-matching tool' do
          approvals = Ai::DuoWorkflows::Workflow::ToolCallApprovals.new
          approvals.add_approval(tool_name: 'read_file', call_args: '{"path": "/tmp"}')
          specific_workflow.update!(tool_call_approvals: approvals.to_h)

          post_graphql(query, current_user: current_user)

          match = returned_workflows.first['toolCallApprovalMatch']
          expect(match).to eq('matched' => false, 'matchType' => nil, 'matchedPattern' => nil)
        end
      end

      context 'with the sort argument' do
        context 'when CREATED_ASC' do
          let(:variables) { { sort: :CREATED_ASC } }

          it 'returns the workflows oldest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
            expect(returned_workflows.first['createdAt']).to be < returned_workflows.last['createdAt']
          end
        end

        context 'when CREATED_DESC' do
          let(:variables) { { sort: :CREATED_DESC } }

          it 'returns the workflows latest first', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows.length).to eq(all_project_workflows.length + all_namespace_workflows.length)
            expect(returned_workflows.first['createdAt']).to be > returned_workflows.last['createdAt']
          end
        end

        context 'when STATUS_ASC' do
          let(:variables) { { sort: :STATUS_ASC } }

          it 'returns the workflows ordered by status ascending', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            statuses = returned_workflows.pluck('status')
            expect(statuses).to eq(%w[
              CREATED CREATED CREATED
              CREATED CREATED CREATED
              CREATED RUNNING RUNNING
            ])
          end
        end

        context 'when STATUS_DESC' do
          let(:variables) { { sort: :STATUS_DESC } }

          it 'returns the workflows ordered by status descending', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            statuses = returned_workflows.pluck('status')
            expect(statuses).to eq(%w[
              RUNNING RUNNING CREATED
              CREATED CREATED CREATED
              CREATED CREATED CREATED
            ])
          end
        end
      end

      context 'with the type argument' do
        let(:variables) { { type: 'software_development' } }

        it 'returns only workflows with the specified type', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).to eq('software_development')
          end
        end
      end

      context 'with the search argument' do
        let(:variables) { { search: 'soft devel' } }

        it 'returns only workflows matching the search criteria', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).to eq('software_development')
          end
        end
      end

      context 'with the search argument containing possible IDs' do
        let(:variables) do
          { search: "soft devel #{workflow_with_web_environment.id} ##{archived_workflow.id}" }
        end

        it 'returns only workflows matching the search criteria', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(2)
          expect(returned_workflows[0]['workflowDefinition']).to eq('software_development')
          expect(returned_workflows[0]['id']).to eq(workflow_with_web_environment.to_global_id.to_s)
          expect(returned_workflows[1]['workflowDefinition']).to eq('software_development')
          expect(returned_workflows[1]['id']).to eq(archived_workflow.to_global_id.to_s)
        end
      end

      context 'with the status_group argument' do
        let(:variables) { { statusGroup: :ACTIVE } }

        it 'returns only workflows with in that status group', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['statusGroup']).to eq('ACTIVE')
          end
        end
      end

      context 'with the exclude_types argument' do
        let(:variables) { { exclude_types: %w[chat] } }

        it 'excludes workflows with the specified types', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).not_to eq('chat')
          end
        end
      end

      context 'with multiple exclude_types' do
        let(:variables) { { exclude_types: %w[chat convert_to_gitlab_ci] } }

        it 'excludes workflows with any of the specified types', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows).not_to be_empty

          returned_workflows.each do |returned_workflow|
            expect(returned_workflow['workflowDefinition']).not_to be_in(%w[chat convert_to_gitlab_ci])
          end
        end
      end

      context 'with both type and exclude_types arguments' do
        context 'when type and exclude_types are different' do
          let(:variables) { { type: 'software_development', exclude_types: %w[chat] } }

          it 'applies both filters correctly', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows).not_to be_empty

            returned_workflows.each do |returned_workflow|
              expect(returned_workflow['workflowDefinition']).to eq('software_development')
              expect(returned_workflow['workflowDefinition']).not_to eq('chat')
            end
          end
        end

        context 'when type matches one of exclude_types' do
          let(:variables) { { type: 'software_development', exclude_types: %w[chat software_development] } }

          it 'returns an empty array', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil
            expect(returned_workflows).to be_empty
          end
        end

        context 'when type is different from all exclude_types' do
          let(:variables) { { type: 'software_development', exclude_types: %w[chat convert_to_gitlab_ci] } }

          it 'applies all filters correctly', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            expect(returned_workflows).not_to be_empty

            returned_workflows.each do |returned_workflow|
              expect(returned_workflow['workflowDefinition']).to eq('software_development')
              expect(returned_workflow['workflowDefinition']).not_to be_in(%w[chat convert_to_gitlab_ci])
            end
          end
        end
      end

      context 'with archived and stalled fields' do
        it 'returns the correct archived and stalled values', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          returned_workflows_by_id = returned_workflows.index_by { |w| w['id'] }

          # Check archived workflow
          archived_result = returned_workflows_by_id[archived_workflow.to_global_id.to_s]
          expect(archived_result).not_to be_nil
          expect(archived_result['archived']).to be(true)
          expect(archived_result['stalled']).to be(false) # archived workflows in created state are not stalled

          # Check stalled workflow (running state with no checkpoints)
          stalled_result = returned_workflows_by_id[stalled_workflow.to_global_id.to_s]
          expect(stalled_result).not_to be_nil
          expect(stalled_result['archived']).to be(false)
          expect(stalled_result['stalled']).to be(true)

          # Check non-stalled workflow with checkpoint
          non_stalled_result = returned_workflows_by_id[non_stalled_workflow_with_checkpoint.to_global_id.to_s]
          expect(non_stalled_result).not_to be_nil
          expect(non_stalled_result['archived']).to be(false)
          expect(non_stalled_result['stalled']).to be(false)

          # Check regular workflows (not archived, in created state so not stalled)
          [workflow_without_environment, workflow_with_ide_environment,
            workflow_with_web_environment].each do |workflow|
            result = returned_workflows_by_id[workflow.to_global_id.to_s]
            expect(result).not_to be_nil
            expect(result['archived']).to be(false)
            expect(result['stalled']).to be(false)
          end
        end
      end

      context 'with the workflow_id argument for archived workflow' do
        let(:variables) { { workflow_id: archived_workflow.to_global_id.to_s } }

        it 'returns the archived workflow with correct archived status', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(archived_workflow.to_global_id.to_s)
          expect(returned_workflows.first['archived']).to be(true)
          expect(returned_workflows.first['stalled']).to be(false)
        end
      end

      context 'with the workflow_id argument for stalled workflow' do
        let(:variables) { { workflow_id: stalled_workflow.to_global_id.to_s } }

        it 'returns the stalled workflow with correct stalled status', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          expect(returned_workflows.length).to eq(1)
          expect(returned_workflows.first['id']).to eq(stalled_workflow.to_global_id.to_s)
          expect(returned_workflows.first['archived']).to be(false)
          expect(returned_workflows.first['stalled']).to be(true)
        end
      end

      context 'when offset pagination is needed' do
        let(:page_info) { graphql_data.dig('duoWorkflowWorkflows', 'pageInfo') }
        let(:variables) { { sort: :STATUS_DESC, first: 3, after: GraphQL::Schema::Base64Encoder.encode('3') } }

        it 'returns the workflows ordered by status descending', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(returned_workflows.length).to eq(3)
          expect(returned_workflows.pluck('status')).to eq(%w[CREATED CREATED CREATED])
          expect(page_info['hasNextPage']).to be(true)
          expect(page_info['hasPreviousPage']).to be(true)
        end
      end

      it 'does not have N+1 queries when adding more workflows', :request_store do
        # Minimal fields to keep the query focused on the N+1 from authorization
        n1_fields = <<~GRAPHQL
          nodes { id goal workflowDefinition status }
        GRAPHQL
        n1_query = graphql_query_for('duoWorkflowWorkflows', {}, n1_fields)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(n1_query, current_user: current_user)
        end

        create_list(:duo_workflows_workflow, 3, project: project, user: user)

        expect do
          post_graphql(n1_query, current_user: current_user)
        end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
      end

      it 'batch-loads checkpointWrites into a single query instead of one query per workflow' do
        workflows_with_writes = create_list(:duo_workflows_workflow, 3, project: project, user: user)
        workflows_with_writes.each do |workflow|
          checkpoint = create(:duo_workflows_checkpoint, workflow: workflow, project: project)
          create(:duo_workflows_checkpoint_write, workflow: workflow, thread_ts: checkpoint.thread_ts,
            project: project)
        end

        fields_with_writes = <<~GRAPHQL
          nodes { id firstCheckpoint { threadTs checkpointWrites { id } } }
        GRAPHQL
        n1_query = graphql_query_for('duoWorkflowWorkflows', {}, fields_with_writes)

        recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(n1_query, current_user: current_user)
        end

        checkpoint_write_queries = recorder.log.count { |sql| sql.include?('duo_workflows_checkpoint_writes') }

        expect(checkpoint_write_queries).to eq(1)
      end

      context 'with agentName field' do
        it 'returns agent names correctly', :aggregate_failures do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to be_nil

          # Custom catalog agent - should return the catalog item name
          workflow_with_catalog_agent = returned_workflows.find do |w|
            w['aiCatalogItemVersionId'] == ai_catalog_item_version.to_global_id.to_s
          end
          expect(workflow_with_catalog_agent).not_to be_nil
          expect(workflow_with_catalog_agent['agentName']).to eq(ai_catalog_item_version.item.name)

          # Foundational agent - should return foundational agent name
          agentic_chat_workflow = returned_workflows.find do |w|
            w['id'] == namespace_level_workflow.to_global_id.to_s
          end
          expect(agentic_chat_workflow).not_to be_nil
          expect(agentic_chat_workflow['agentName']).to eq('GitLab Duo')

          # No agent info - should return nil
          workflows_without_agents = returned_workflows.select do |w|
            w['aiCatalogItemVersionId'].nil? && w['agentName'].nil?
          end
          expect(workflows_without_agents).not_to be_empty
        end
      end

      context 'with modelMetadataName and modelMetadataIdentifier fields' do
        let(:model_metadata) do
          Gitlab::Json.dump({ 'provider' => 'gitlab', 'name' => 'claude_sonnet_4_6',
                              'identifier' => 'claude-sonnet-4-20250514' })
        end

        let(:specific_workflow) { workflow_without_environment }
        let(:variables) { { workflow_id: specific_workflow.to_global_id.to_s } }

        context 'when model_metadata_json is set on the workflow' do
          before do
            specific_workflow.update!(model_metadata_json: model_metadata)
          end

          it 'returns the model name and identifier', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            returned_workflow = returned_workflows.first
            expect(returned_workflow['modelMetadataName']).to eq('claude_sonnet_4_6')
            expect(returned_workflow['modelMetadataIdentifier']).to eq('claude-sonnet-4-20250514')
          end
        end

        context 'when model_metadata_json is not set on the workflow' do
          before do
            specific_workflow.update_column(:model_metadata_json, nil)
          end

          it 'returns nil for model name and identifier', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            returned_workflow = returned_workflows.first
            expect(returned_workflow['modelMetadataName']).to be_nil
            expect(returned_workflow['modelMetadataIdentifier']).to be_nil
          end
        end
      end

      context 'with flowMetadataVersion, flowMetadataId, and flowMetadataSchemaVersion fields' do
        let(:flow_metadata) do
          Gitlab::Json.dump({ 'flow_version' => '2.0.0', 'schema_version' => 'v1', 'flow_id' => 'developer' })
        end

        let(:specific_workflow) { workflow_without_environment }
        let(:variables) { { workflow_id: specific_workflow.to_global_id.to_s } }

        context 'when flow_metadata_json is set on the workflow' do
          before do
            specific_workflow.update!(flow_metadata_json: flow_metadata)
          end

          it 'returns the flow version, id, and schema version', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            returned_workflow = returned_workflows.first
            expect(returned_workflow['flowMetadataVersion']).to eq('2.0.0')
            expect(returned_workflow['flowMetadataId']).to eq('developer')
            expect(returned_workflow['flowMetadataSchemaVersion']).to eq('v1')
          end
        end

        context 'when flow_metadata_json is not set on the workflow' do
          before do
            specific_workflow.update_column(:flow_metadata_json, nil)
          end

          it 'returns nil for flow metadata fields', :aggregate_failures do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors).to be_nil

            returned_workflow = returned_workflows.first
            expect(returned_workflow['flowMetadataVersion']).to be_nil
            expect(returned_workflow['flowMetadataId']).to be_nil
            expect(returned_workflow['flowMetadataSchemaVersion']).to be_nil
          end
        end
      end
    end

    context 'when duo_features_enabled settings vary across the namespace hierarchy' do
      let_it_be(:hierarchy_group, freeze: false) { create(:group) }
      let_it_be(:enabled_project, freeze: false) do
        create(:project, :public, group: hierarchy_group, project_setting: build(:project_setting))
      end

      let_it_be(:disabled_project, freeze: false) do
        create(:project, :public, group: hierarchy_group, project_setting: build(:project_setting))
      end

      let_it_be(:hierarchy_user, freeze: false) { create(:user, developer_of: hierarchy_group) }

      let_it_be(:enabled_project_workflow, freeze: false) do
        create(:duo_workflows_workflow, project: enabled_project, user: hierarchy_user)
      end

      let_it_be(:disabled_project_workflow, freeze: false) do
        create(:duo_workflows_workflow, project: disabled_project, user: hierarchy_user)
      end

      let_it_be(:hierarchy_namespace_workflow, freeze: false) do
        create(:duo_workflows_workflow, :agentic_chat, namespace: hierarchy_group, user: hierarchy_user)
      end

      before do
        # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
        allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
        # rubocop:enable RSpec/AnyInstanceOf

        disabled_project.project_setting.reload.update!(duo_features_enabled: false)
        enabled_project.project_setting.reload.update!(duo_features_enabled: group_and_project_states[:project])
        hierarchy_group.namespace_settings.reload.update!(duo_features_enabled: group_and_project_states[:group])
      end

      def returned_workflow_ids
        post_graphql(query, current_user: hierarchy_user)
        returned_workflows.pluck('id')
      end

      context 'when Duo features are disabled everywhere in the hierarchy' do
        let(:group_and_project_states) { { group: false, project: false } }

        it 'returns no workflows from any resource in the hierarchy' do
          expect(returned_workflow_ids).to be_empty
        end
      end

      context 'when Duo features are disabled on the group but enabled on a descendant project' do
        let(:group_and_project_states) { { group: false, project: true } }

        it 'returns only the Duo-enabled project workflow, not the group-level or Duo-disabled workflows, ' \
          'for the current user', :aggregate_failures do
          ids = returned_workflow_ids

          expect(ids).to include(enabled_project_workflow.to_global_id.to_s)
          expect(ids).not_to include(disabled_project_workflow.to_global_id.to_s)
          expect(ids).not_to include(hierarchy_namespace_workflow.to_global_id.to_s)
          expect(returned_workflows.pluck('userId').uniq).to contain_exactly(hierarchy_user.to_global_id.to_s)
        end
      end

      context 'when Duo features are enabled on both the group and a descendant project' do
        let(:group_and_project_states) { { group: true, project: true } }

        it 'returns the Duo-enabled and namespace workflows, but not the Duo-disabled project', :aggregate_failures do
          ids = returned_workflow_ids

          expect(ids).to include(enabled_project_workflow.to_global_id.to_s)
          expect(ids).not_to include(disabled_project_workflow.to_global_id.to_s)
          expect(ids).to include(hierarchy_namespace_workflow.to_global_id.to_s)
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers

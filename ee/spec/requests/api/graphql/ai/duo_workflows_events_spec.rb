# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying Duo Workflow Events', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:another_project) { create(:project, group: group) }
  let_it_be_with_reload(:user) { create(:user, developer_of: [project, another_project]) }
  let_it_be(:another_user) { create(:user, developer_of: project) }
  # `freeze: false` is required here: this `let_it_be` subject is mutated
  # in-memory across examples in a way that survives both
  # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
  # association/collection or a non-persisted attribute). Keeping it unfrozen
  # is the only correct cure (see gitlab-org/gitlab#602925).
  let_it_be(:checkpoints, freeze: false) { create_list(:duo_workflows_checkpoint, 3, :ui_chat_log, project: project) }

  let_it_be_with_reload(:ide_workflow) do
    create(:duo_workflows_workflow, project: project, user: user, checkpoints: checkpoints, environment: :ide)
  end

  let_it_be(:remote_workflow) do
    create(:duo_workflows_workflow, project: project, user: user,
      checkpoints: create_list(:duo_workflows_checkpoint, 2, project: project), environment: :web,
      workflow_definition: :convert_to_gitlab_ci)
  end

  let_it_be(:remote_workflow_for_another_project) do
    create(:duo_workflows_workflow, project: another_project, user: user,
      checkpoints: create_list(:duo_workflows_checkpoint, 2, project: another_project), environment: :web,
      workflow_definition: :convert_to_gitlab_ci)
  end

  let(:fields) do
    <<~GRAPHQL
      edges {
        cursor
        node {
          errors,
          checkpoint,
          compressedCheckpoint,
          metadata,
          workflowGoal,
          workflowDefinition,
          threadTs,
          parentTs,
          duoMessages {
            content
            messageType
            status
            toolInfo
            timestamp
            correlationId
            role
          }
        }
      }
      pageInfo {
        hasPreviousPage
        startCursor
        hasNextPage
        endCursor
      }
    GRAPHQL
  end

  let(:arguments) { { workflowId: global_id_of(ide_workflow) } }
  let(:query) { graphql_query_for('duoWorkflowEvents', arguments, fields) }

  subject(:event_nodes) { graphql_data.dig('duoWorkflowEvents', 'edges') }

  context 'when user is not logged in' do
    it 'returns an empty array' do
      post_graphql(query, current_user: nil)

      expect(event_nodes).to be_empty
    end
  end

  context 'when user is logged in' do
    let_it_be(:chat_log) do
      [{ "content" => "hi", "correlationId" => nil, "messageType" => "user", "role" => nil, "status" => "success",
         "timestamp" => "2025-11-25T21:10:57.734182+00:00", "toolInfo" => "null" }]
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf  -- not the next instance
      allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    context 'with default pagination (no cursor arguments)' do
      it 'returns only the latest checkpoint', :aggregate_failures do
        post_graphql(query, current_user: user)

        expect(event_nodes).not_to be_empty
        expect(event_nodes.length).to eq(1)

        event = event_nodes.first['node']
        expect(event['errors']).to eq([])

        # The resolver orders by created_at DESC so the returned checkpoint
        # must be the most recently created one.
        # Reload to compare against jsonb-normalized values: Postgres
        # jsonb reorders keys (by length, then alpha), so an in-memory
        # factory Hash and the API's serialized response only line up
        # after a DB round-trip.
        latest = checkpoints.max_by { |c| [c.created_at, c.id] }.reload
        expect(Gitlab::Json.safe_parse(event['checkpoint'])).to eq(latest.checkpoint)
        expect(event['compressedCheckpoint']).to eq(
          Base64.strict_encode64(Zlib::Deflate.deflate(latest.checkpoint.to_json, 6))
        )
        expect(Gitlab::Json.safe_parse(event['metadata'])).to eq(latest.metadata)
        expect(event['threadTs']).to eq(latest.thread_ts)
        expect(event['parentTs']).to eq(latest.parent_ts)
        expect(event['workflowGoal']).to eq("Fix pipeline")
        expect(event['workflowDefinition']).to eq("software_development")
        expect(event['duoMessages']).to eq(chat_log)
      end

      it 'reports hasNextPage true when older checkpoints exist' do
        post_graphql(query, current_user: user)

        page_info = graphql_data.dig('duoWorkflowEvents', 'pageInfo')
        expect(page_info['hasNextPage']).to be(true)
      end
    end

    context 'with offset pagination' do
      it 'returns N checkpoints when first: N is supplied', :aggregate_failures do
        paginated_query = graphql_query_for(
          'duoWorkflowEvents',
          arguments.merge(first: 2),
          fields
        )
        post_graphql(paginated_query, current_user: user)

        nodes = graphql_data.dig('duoWorkflowEvents', 'edges')
        expect(nodes.length).to eq(2)

        # Results must be ordered newest-first
        returned_ts = nodes.map { |e| e['node']['threadTs'] }
        expected_ts = checkpoints.sort_by { |c| [c.created_at, c.id] }.last(2).reverse.map(&:thread_ts)
        expect(returned_ts).to eq(expected_ts)
      end

      it 'pages to older checkpoints using after cursor', :aggregate_failures do
        # First page: newest checkpoint
        post_graphql(query, current_user: user)

        after_cursor = graphql_data.dig('duoWorkflowEvents', 'pageInfo', 'endCursor')
        expect(after_cursor).to be_present

        # Second page: the two older checkpoints
        paginated_query = graphql_query_for(
          'duoWorkflowEvents',
          arguments.merge(first: 2, after: after_cursor),
          fields
        )
        post_graphql(paginated_query, current_user: user)

        older_nodes = graphql_data.dig('duoWorkflowEvents', 'edges')
        expect(older_nodes.length).to eq(2)

        returned_thread_ts = older_nodes.map { |e| e['node']['threadTs'] }
        latest_thread_ts = checkpoints.max_by { |c| [c.created_at, c.id] }.thread_ts
        expect(returned_thread_ts).not_to include(latest_thread_ts)
      end

      it 'reports hasNextPage false when all checkpoints fit in one page', :aggregate_failures do
        all_query = graphql_query_for(
          'duoWorkflowEvents',
          arguments.merge(first: 10),
          fields
        )
        post_graphql(all_query, current_user: user)

        page_info = graphql_data.dig('duoWorkflowEvents', 'pageInfo')
        expect(page_info['hasNextPage']).to be(false)
        expect(graphql_data.dig('duoWorkflowEvents', 'edges').length).to eq(3)
      end
    end
  end

  context 'when project_path is specified' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(another_project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf  -- not the next instance
      allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    let_it_be(:project_fields) { project_fields_for_workflow(remote_workflow) }
    let_it_be(:project_query) { graphql_query_for('project', { full_path: project.full_path }, project_fields) }

    it 'returns only the latest checkpoint for a users remote flow' do
      post_graphql(project_query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events.length).to eq(1)
    end

    it 'returns only the latest checkpoint for another users remote flow' do
      post_graphql(project_query, current_user: another_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events.length).to eq(1)
    end

    it "does not return another users ide flow events for the project" do
      project_fields_ide = project_fields_for_workflow(ide_workflow)
      ide_workflow_project_query = graphql_query_for('project', { full_path: project.full_path }, project_fields_ide)
      post_graphql(ide_workflow_project_query, current_user: another_user)

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events).to be_empty
    end

    it 'returns empty array if workflow is not in project' do
      project_fields = project_fields_for_workflow(remote_workflow)
      another_project_query = graphql_query_for('project', { full_path: another_project.full_path }, project_fields)
      post_graphql(another_project_query, current_user: user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events).to be_empty
    end
  end

  context 'when project_path is specified and user is not a member of the project' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(another_project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf  -- not the next instance
      allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    let_it_be(:project_fields) { project_fields_for_workflow(remote_workflow_for_another_project) }
    let_it_be(:project_query) { graphql_query_for('project', { full_path: another_project.full_path }, project_fields) }

    it 'returns an empty array for a remote flow' do
      post_graphql(project_query, current_user: another_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(graphql_errors).to be_nil

      events = graphql_data.dig("project", "duoWorkflowEvents", "nodes")
      expect(events).to be_nil
    end
  end

  def project_fields_for_workflow(workflow)
    <<~GRAPHQL
      duoWorkflowEvents(workflowId: "#{workflow.to_global_id}") {
        nodes {
          checkpoint
        }
      }
    GRAPHQL
  end
end

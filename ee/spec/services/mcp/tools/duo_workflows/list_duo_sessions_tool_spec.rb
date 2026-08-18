# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::DuoWorkflows::ListDuoSessionsTool, feature_category: :mcp_server do
  let_it_be(:ai_settings, freeze: false) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be(:group, freeze: false) { create(:group, ai_settings: ai_settings) }
  let_it_be(:user, freeze: false) { create(:user, developer_of: group) }
  let_it_be(:other_user, freeze: false) { create(:user, developer_of: group) }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:other_project, freeze: false) { create(:project, group: group) }

  let(:params) { {} }
  let(:tool) { described_class.new(current_user: user, params: params) }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(true)
    # rubocop:disable RSpec/AnyInstanceOf -- Duo Agent Platform authorization is evaluated by the workflow policy.
    allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  describe 'versioning' do
    it 'queries the Duo workflow connection' do
      expect(tool.operation_name).to eq('duoWorkflowWorkflows')
    end
  end

  describe '#build_variables' do
    let(:excluded_types) { ::Ai::FoundationalChatAgent.only_duo_chat_agent.map(&:workflow_definition) }

    it 'uses the default page size and excludes Duo Chat workflow definitions' do
      expect(tool.build_variables).to eq(
        excludeTypes: excluded_types,
        first: 20
      )
    end

    context 'with a project path' do
      let(:params) { { project_id: project.full_path } }

      it 'resolves the project before passing its path to GraphQL' do
        expect(tool.build_variables).to eq(projectPath: project.full_path, excludeTypes: excluded_types, first: 20)
      end
    end

    context 'with a numeric project ID' do
      let(:params) { { project_id: project.id.to_s } }

      it 'resolves the project before passing its path to GraphQL' do
        expect(tool.build_variables).to eq(projectPath: project.full_path, excludeTypes: excluded_types, first: 20)
      end
    end

    context 'with a project URL' do
      let(:params) { { url: "#{project.web_url}/-/automate/agent-sessions" } }

      it 'resolves the project URL before passing its path to GraphQL' do
        expect(tool.build_variables).to eq(projectPath: project.full_path, excludeTypes: excluded_types, first: 20)
      end
    end

    context 'with status group and cursor filters' do
      let(:params) { { status_group: 'awaiting_input', first: 25, after: 'cursor-1' } }

      it 'uses the GraphQL enum and cursor pagination variables' do
        expect(tool.build_variables).to eq(
          statusGroup: 'AWAITING_INPUT',
          excludeTypes: excluded_types,
          first: 25,
          after: 'cursor-1'
        )
      end
    end

    context 'when both project identifiers are provided' do
      let(:params) { { url: project.web_url, project_id: project.full_path } }

      it 'rejects the ambiguous request' do
        expect { tool.build_variables }.to raise_error(ArgumentError, /Provide at most one of/)
      end
    end
  end

  describe '#execute' do
    it 'excludes Duo Chat sessions and returns other authenticated user sessions in compact MCP shape' do
      workflow = create(:duo_workflows_workflow, user: user, project: project, goal: 'a' * 200)
      namespace_workflow = create(:duo_workflows_workflow, user: user, namespace: group)
      create(:duo_workflows_workflow, :agentic_chat, user: user, namespace: group)
      create(:duo_workflows_workflow, user: other_user, project: project)

      result = tool.execute

      expect(result).to include(
        isError: false,
        structuredContent: {
          'sessions' => contain_exactly(expected_session(workflow), expected_session(namespace_workflow)),
          'pageInfo' => a_hash_including('hasNextPage' => false)
        }
      )
      expect(result[:content]).to eq([{ type: 'text', text: Gitlab::Json.dump(result[:structuredContent]) }])
    end

    it 'filters sessions by project' do
      matching_workflow = create(:duo_workflows_workflow, user: user, project: project)
      create(:duo_workflows_workflow, user: user, project: other_project)

      result = execute_tool(project_id: project.full_path)

      expect(result.dig(:structuredContent, 'sessions')).to contain_exactly(expected_session(matching_workflow))
    end

    it 'filters sessions by the complete awaiting input status group' do
      input_required = create(:duo_workflows_workflow, user: user, project: project,
        status: status_value(:input_required))
      plan_approval = create(:duo_workflows_workflow, user: user, project: project,
        status: status_value(:plan_approval_required))
      tool_approval = create(:duo_workflows_workflow, user: user, project: project,
        status: status_value(:tool_call_approval_required))
      create(:duo_workflows_workflow, user: user, project: project, status: status_value(:running))

      result = execute_tool(status_group: 'awaiting_input')

      expect(result.dig(:structuredContent, 'sessions')).to contain_exactly(
        expected_session(input_required),
        expected_session(plan_approval),
        expected_session(tool_approval)
      )
    end

    it 'uses the GraphQL cursor for the next page' do
      workflows = []

      travel_to(Time.zone.parse('2026-08-04 10:00:00 UTC')) do
        workflows << create(:duo_workflows_workflow, user: user, project: project)
      end
      travel_to(Time.zone.parse('2026-08-04 11:00:00 UTC')) do
        workflows << create(:duo_workflows_workflow, user: user, project: project)
      end
      travel_to(Time.zone.parse('2026-08-04 12:00:00 UTC')) do
        workflows << create(:duo_workflows_workflow, user: user, project: project)
      end

      first_page = execute_tool(first: 2)
      second_page = execute_tool(first: 2, after: first_page.dig(:structuredContent, 'pageInfo', 'endCursor'))

      expect(first_page.dig(:structuredContent, 'sessions')).to eq([
        expected_session(workflows[2]),
        expected_session(workflows[1])
      ])
      expect(first_page.dig(:structuredContent, 'pageInfo')).to include('hasNextPage' => true)
      expect(second_page.dig(:structuredContent, 'sessions')).to eq([expected_session(workflows[0])])
      expect(second_page.dig(:structuredContent, 'pageInfo')).to include('hasNextPage' => false)
    end

    it 'returns an empty connection when there are no matching sessions' do
      result = execute_tool(status_group: 'failed')

      expect(result).to include(
        isError: false,
        structuredContent: {
          'sessions' => [],
          'pageInfo' => a_hash_including('hasNextPage' => false)
        }
      )
    end

    context 'when the project does not exist' do
      let(:params) { { project_id: non_existing_record_id.to_s } }

      it 'raises before executing GraphQL' do
        expect { tool.execute }.to raise_error(StandardError, /not found or inaccessible/)
      end
    end
  end

  private

  def execute_tool(params)
    described_class.new(current_user: user, params: params).execute
  end

  def expected_session(workflow)
    {
      'id' => workflow.id,
      'status' => workflow.status_name.to_s,
      'goal' => workflow.goal&.truncate(160),
      'flow' => workflow.workflow_definition,
      'web_url' => workflow.web_url,
      'created_at' => workflow.created_at.iso8601
    }
  end

  def status_value(status)
    ::Ai::DuoWorkflows::Workflow.state_machines[:status].states.fetch(status).value
  end
end

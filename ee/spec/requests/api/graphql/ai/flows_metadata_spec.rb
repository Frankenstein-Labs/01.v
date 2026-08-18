# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.aiFlowsMetadata', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: create(:group)) }

  let(:current_user) { user }
  let(:namespace_id) { nil }
  let(:project_id) { nil }

  let(:query) do
    query_arguments = {
      namespaceId: namespace_id,
      projectId: project_id
    }.compact

    <<~QUERY
      query {
        aiFlowsMetadata#{"(#{attributes_to_graphql(query_arguments)})" if query_arguments.present?} {
          capabilities {
            name
            metadata
          }
        }
      }
    QUERY
  end

  subject(:request) { post_graphql(query, current_user: current_user) }

  before_all do
    group.add_developer(user)
    project.add_developer(user)
  end

  before do
    allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
      allow(client).to receive(:list_capabilities)
        .and_return(ServiceResponse.success(payload: { capabilities: [] }))
    end
  end

  context 'when the user is not authenticated' do
    let(:current_user) { nil }

    before do
      request
    end

    it_behaves_like 'a working graphql query'

    it 'always includes the static Rails capabilities' do
      expect(graphql_data_at(:ai_flows_metadata, :capabilities)).to include(
        { 'name' => 'job_trace_pagination', 'metadata' => nil },
        { 'name' => 'tool_call_approval_source', 'metadata' => nil }
      )
    end
  end

  context 'when namespace_id is not provided' do
    before do
      stub_feature_flags(duo_workflow_incremental_checkpoints: false)
    end

    context 'with default feature flag state' do
      before do
        request
      end

      it_behaves_like 'a working graphql query'

      it 'always includes the static Rails capabilities' do
        expect(graphql_data_at(:ai_flows_metadata, :capabilities)).to include(
          { 'name' => 'job_trace_pagination', 'metadata' => nil },
          { 'name' => 'tool_call_approval_source', 'metadata' => nil }
        )
      end

      it 'does not include namespace-scoped capabilities' do
        names = graphql_data_at(:ai_flows_metadata, :capabilities).pluck('name')

        expect(names).not_to include('advanced_search', 'incremental_checkpoints')
      end
    end

    context 'when duo_cli_default_flow is enabled for the current user' do
      before do
        stub_feature_flags(duo_cli_default_flow: user)

        request
      end

      it 'includes the duo_developer capability with the registry coordinates' do
        expect(graphql_data_at(:ai_flows_metadata, :capabilities)).to include(
          {
            'name' => 'duo_developer',
            'metadata' => {
              'flow_config_id' => 'developer',
              'flow_config_schema_version' => 'v1',
              'flow_version' => '2.0.0-interactive'
            }
          }
        )
      end
    end
  end

  context 'when namespace_id is provided' do
    let(:namespace_id) { group.to_global_id.to_s }

    context 'when the user can read the namespace' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
          .with(scope: group).and_return(true)
        stub_feature_flags(duo_workflow_incremental_checkpoints: group)

        request
      end

      it_behaves_like 'a working graphql query'

      it 'includes the namespace-scoped capabilities' do
        names = graphql_data_at(:ai_flows_metadata, :capabilities).pluck('name')

        expect(names).to include('advanced_search', 'incremental_checkpoints')
      end
    end

    context 'when the user cannot read the namespace' do
      let_it_be(:private_group) { create(:group, :private) }

      let(:namespace_id) { private_group.to_global_id.to_s }

      before do
        request
      end

      it_behaves_like 'a query that returns a top-level access error'
    end

    context 'when the Duo Workflow Service returns capabilities' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_capabilities).and_return(
            ServiceResponse.success(
              payload: {
                capabilities: [
                  { name: 'tool_call_approval', metadata: nil },
                  { name: 'tool_call_pattern_approval', metadata: nil },
                  { name: 'mcp_tools', metadata: { 'version' => 1 } }
                ]
              }
            )
          )
        end
      end

      context 'when tool approval for session is disabled for the namespace (default)' do
        before do
          request
        end

        it 'includes non tool-approval capabilities' do
          expect(graphql_data_at(:ai_flows_metadata, :capabilities)).to include(
            { 'name' => 'mcp_tools', 'metadata' => { 'version' => 1 } }
          )
        end

        it 'filters out tool approval capabilities' do
          names = graphql_data_at(:ai_flows_metadata, :capabilities).pluck('name')

          expect(names).not_to include('tool_call_approval', 'tool_call_pattern_approval')
        end
      end

      context 'when tool approval for session is enabled for the namespace' do
        before do
          group.reload.namespace_settings.update!(tool_approval_for_session_enabled: true)

          request
        end

        it 'includes tool approval capabilities' do
          names = graphql_data_at(:ai_flows_metadata, :capabilities).pluck('name')

          expect(names).to include('tool_call_approval', 'tool_call_pattern_approval')
        end
      end
    end
  end

  context 'when project_id is provided' do
    let(:project_id) { project.to_global_id.to_s }

    context 'when the user can read the project' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
          .with(scope: project).and_return(true)

        request
      end

      it_behaves_like 'a working graphql query'

      it 'includes the project-scoped capabilities' do
        names = graphql_data_at(:ai_flows_metadata, :capabilities).pluck('name')

        expect(names).to include('advanced_search')
      end
    end

    context 'when the user cannot read the project' do
      let_it_be(:private_project) { create(:project, :private) }

      let(:project_id) { private_project.to_global_id.to_s }

      before do
        request
      end

      it_behaves_like 'a query that returns a top-level access error'
    end

    context 'when the Duo Workflow Service returns capabilities' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_capabilities).and_return(
            ServiceResponse.success(
              payload: { capabilities: [{ name: 'tool_call_approval', metadata: nil }] }
            )
          )
        end
      end

      context 'when tool approval for session is disabled for the project (default)' do
        before do
          request
        end

        it 'filters out tool approval capabilities' do
          names = graphql_data_at(:ai_flows_metadata, :capabilities).pluck('name')

          expect(names).not_to include('tool_call_approval')
        end
      end

      context 'when tool approval for session is enabled for the project' do
        before do
          project.reload.project_setting.update!(tool_approval_for_session_enabled: true)

          request
        end

        it 'includes tool approval capabilities' do
          names = graphql_data_at(:ai_flows_metadata, :capabilities).pluck('name')

          expect(names).to include('tool_call_approval')
        end
      end
    end
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :read_flows_metadata do
    let(:boundary_object) { group }
    let(:namespace_id) { group.to_global_id.to_s }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :read_flows_metadata do
    let(:boundary_object) { project }
    let(:project_id) { project.to_global_id.to_s }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :read_flows_metadata do
    let(:boundary_object) { :instance }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
    :read_flows_metadata do
    let(:boundary_object) { group }
    let(:namespace_id) { group.to_global_id.to_s }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    let(:skipped_data_path) { %i[ai_flows_metadata capabilities] }
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
    :read_flows_metadata do
    let(:boundary_object) { project }
    let(:project_id) { project.to_global_id.to_s }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    let(:skipped_data_path) { %i[ai_flows_metadata capabilities] }
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
    :read_flows_metadata do
    let(:boundary_object) { :instance }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
    let(:skipped_data_path) { %i[ai_flows_metadata capabilities] }
  end
end

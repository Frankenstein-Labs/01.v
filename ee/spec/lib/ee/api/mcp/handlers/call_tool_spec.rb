# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Mcp::Handlers::CallTool, feature_category: :mcp_server do
  let(:manager) { instance_double(Mcp::Tools::Manager) }
  let(:request) { instance_double(Rack::Request) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  subject(:handler) { described_class.new(manager) }

  describe '#invoke' do
    let(:tool_name) { 'test_tool' }
    let(:arguments) { { param: 'value' } }
    let(:params) { { name: tool_name, arguments: arguments } }
    let(:tool) { instance_double(Mcp::Tools::Base::BaseService) }

    before do
      allow(request).to receive(:[]).with(:id).and_return('1')
      allow(manager).to receive(:get_tool).with(name: tool_name).and_return(tool)
      allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
      allow(tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
      allow(tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      allow(handler).to receive(:track_internal_event)
    end

    context 'when tool is found and version matches' do
      it 'executes the tool successfully and tracks events' do
        result = handler.invoke(request, params, current_user)

        expect(manager).to have_received(:get_tool).with(name: tool_name)
        expect(tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })

        expect(handler).to have_received(:track_internal_event).with(
          'start_mcp_tool_call',
          user: current_user,
          additional_properties: hash_including(tool_name: tool_name, session_id: '1')
        )

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          additional_properties: hash_including(tool_name: tool_name, has_tool_call_success: 'true')
        )
      end
    end

    context 'when tool is a custom service' do
      let(:custom_tool) { instance_double(Mcp::Tools::Base::CustomService) }

      before do
        allow(manager).to receive(:get_tool).with(name: tool_name).and_return(custom_tool)
        allow(custom_tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(true)
        allow(custom_tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(false)
        allow(custom_tool).to receive(:set_cred)
        allow(custom_tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      end

      it 'sets credentials before executing and tracks events' do
        result = handler.invoke(request, params, current_user)

        expect(custom_tool).to have_received(:set_cred).with(current_user: current_user)
        expect(custom_tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          additional_properties: hash_including(tool_name: tool_name, has_tool_call_success: 'true')
        )
      end
    end

    context 'when tool is a graphql service' do
      let(:graphql_tool) { instance_double(Mcp::Tools::Base::GraphqlService) }

      before do
        allow(manager).to receive(:get_tool).with(name: tool_name).and_return(graphql_tool)
        allow(graphql_tool).to receive(:is_a?).with(Mcp::Tools::Base::CustomService).and_return(false)
        allow(graphql_tool).to receive(:is_a?).with(Mcp::Tools::Base::GraphqlService).and_return(true)
        allow(graphql_tool).to receive(:set_cred)
        allow(graphql_tool).to receive(:execute).and_return({ content: [{ type: 'text', text: 'Success' }] })
      end

      it 'sets credentials before executing and tracks events' do
        result = handler.invoke(request, params, current_user)

        expect(graphql_tool).to have_received(:set_cred).with(current_user: current_user)
        expect(graphql_tool).to have_received(:execute).with(request: request, params: params)
        expect(result).to eq({ content: [{ type: 'text', text: 'Success' }] })

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          additional_properties: hash_including(tool_name: tool_name, has_tool_call_success: 'true')
        )
      end
    end

    context 'when arguments do not contain project_id or group_id' do
      it 'tracks events without a project or namespace' do
        handler.invoke(request, params, current_user)

        expect(handler).to have_received(:track_internal_event).with(
          'start_mcp_tool_call',
          user: current_user,
          additional_properties: hash_including(tool_name: tool_name, session_id: '1')
        )

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          additional_properties: hash_including(tool_name: tool_name, has_tool_call_success: 'true')
        )
      end
    end

    context 'when arguments include a project_id as an integer id' do
      let(:arguments) { { project_id: project.id.to_s } }

      it 'tracks events with the project (namespace auto-derived by InternalEvents)' do
        handler.invoke(request, params, current_user)

        expect(handler).to have_received(:track_internal_event).with(
          'start_mcp_tool_call',
          user: current_user,
          project: project,
          additional_properties: hash_including(tool_name: tool_name)
        )

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          project: project,
          additional_properties: hash_including(has_tool_call_success: 'true')
        )
      end
    end

    context 'when arguments include a project_id as a full path' do
      let(:arguments) { { project_id: project.full_path } }

      it 'resolves the project from its full path' do
        handler.invoke(request, params, current_user)

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          project: project,
          additional_properties: hash_including(has_tool_call_success: 'true')
        )
      end
    end

    context 'when arguments include a group_id as an integer id' do
      let(:arguments) { { group_id: group.id.to_s } }

      it 'tracks events with the group as the namespace' do
        handler.invoke(request, params, current_user)

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          namespace: group,
          additional_properties: hash_including(has_tool_call_success: 'true')
        )
      end
    end

    context 'when arguments include a group_id as a full path' do
      let(:arguments) { { group_id: group.full_path } }

      it 'resolves the group from its full path' do
        handler.invoke(request, params, current_user)

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          namespace: group,
          additional_properties: hash_including(has_tool_call_success: 'true')
        )
      end
    end

    context 'when arguments use string keys (JSON-originated params)' do
      let(:params) { { name: tool_name, 'arguments' => { 'project_id' => project.id.to_s } } }

      it 'still resolves the project from string-keyed arguments' do
        handler.invoke(request, params, current_user)

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          project: project,
          additional_properties: hash_including(has_tool_call_success: 'true')
        )
      end
    end

    context 'when project_id is invalid or unknown' do
      let(:arguments) { { project_id: 'non-existent/project' } }

      it 'falls back to tracking without a project or namespace' do
        handler.invoke(request, params, current_user)

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          additional_properties: hash_including(has_tool_call_success: 'true')
        )
      end
    end

    context 'when tool is not found' do
      let(:arguments) { { project_id: project.id.to_s } }

      before do
        allow(manager).to receive(:get_tool).with(name: tool_name)
          .and_raise(Mcp::Tools::Manager::ToolNotFoundError.new(tool_name))
      end

      it 'raises ArgumentError and tracks both start and finish events with the resolved project' do
        expect { handler.invoke(request, params, current_user) }
          .to raise_error(ArgumentError, "Tool '#{tool_name}' not found.")

        expect(handler).to have_received(:track_internal_event).with(
          'start_mcp_tool_call',
          user: current_user,
          project: project,
          additional_properties: hash_including(tool_name: tool_name, session_id: '1')
        )

        expect(handler).to have_received(:track_internal_event).with(
          'finish_mcp_tool_call',
          user: current_user,
          project: project,
          additional_properties: hash_including(tool_name: tool_name, has_tool_call_success: 'false')
        )
      end
    end

    context 'when logging the tool call' do
      let(:logger) { instance_double(Gitlab::Mcp::Logger) }

      before do
        allow(Gitlab::Mcp::Logger).to receive(:build).and_return(logger)
        allow(logger).to receive(:conditional_info)
      end

      context 'when arguments include a project_id' do
        let(:arguments) { { project_id: project.id.to_s } }

        it 'gates expanded logging on the root ancestor of the project namespace' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(namespace: project.root_ancestor)
          )
        end
      end

      context 'when arguments include a group_id' do
        let(:arguments) { { group_id: group.id.to_s } }

        it 'gates expanded logging on the root ancestor of the group' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(namespace: group.root_ancestor)
          )
        end
      end

      context 'when arguments contain no project_id or group_id' do
        it 'passes a nil namespace' do
          handler.invoke(request, params, current_user)

          expect(logger).to have_received(:conditional_info).with(
            current_user, hash_including(namespace: nil)
          )
        end
      end
    end
  end
end

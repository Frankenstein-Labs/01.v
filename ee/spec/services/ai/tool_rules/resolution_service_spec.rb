# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ToolRules::ResolutionService, feature_category: :ai_agents do
  let_it_be_with_reload(:namespace) { create(:group) }

  let(:surface) { :web }
  let(:result) { service.execute }

  subject(:service) { described_class.new(namespace: namespace, surface: surface) }

  before do
    ::Ai::ToolRules::Registry.instance_variable_set(:@all_tool_names, nil)
    ::Ai::ToolRules::Registry.instance_variable_set(:@catalog_tool_names, nil)
    ::Ai::ToolRules::Registry.instance_variable_set(:@action_type_for, nil)
  end

  describe '#execute' do
    it 'returns a success response' do
      expect(result).to be_success
    end

    it 'always includes START_FLOWS in both privilege lists' do
      expect(result.payload[:agent_privileges]).to include(
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::START_FLOWS
      )
      expect(result.payload[:pre_approved_agent_privileges]).to include(
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::START_FLOWS
      )
    end

    context 'when no explicit rules are configured' do
      it 'falls back to :ask for non-preapproved groups', :aggregate_failures do
        expect(result.payload[:pre_approved_tools]).not_to be_empty
        expect(result.payload[:pre_approved_agent_privileges]).not_to include(
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
        )
      end
    end

    context 'when no rules exist for the namespace' do
      it 'includes all privilege group constants in agent_privileges' do
        expect(result.payload[:agent_privileges]).to include(
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
        )
      end

      it 'only includes the read-only GitLab group in pre_approved_agent_privileges' do
        expect(result.payload[:pre_approved_agent_privileges]).to match_array([
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::START_FLOWS
        ])
      end

      it 'returns pre_approved_tools only for preapproved groups', :aggregate_failures do
        expect(result.payload[:pre_approved_tools]).not_to be_empty
        expect(result.payload[:pre_approved_tools]).to include('list_issues')
        expect(result.payload[:pre_approved_tools]).not_to include('create_work_item', 'read_file', 'run_command')
        expect(result.payload[:denied_tools]).to be_empty
      end
    end

    context 'when rules exist for the namespace' do
      context 'when a group has a deny rule' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :deny)
        end

        it 'excludes the group constant from agent_privileges' do
          expect(result.payload[:agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end

        it 'excludes the group from pre_approved_agent_privileges' do
          expect(result.payload[:pre_approved_agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end

        it 'includes the tool in denied_tools' do
          expect(result.payload[:denied_tools]).to include('create_work_item')
        end
      end

      context 'when a group has an ask rule' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :ask)
        end

        it 'includes the group constant in agent_privileges' do
          expect(result.payload[:agent_privileges]).to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end

        it 'excludes the group from pre_approved_agent_privileges' do
          expect(result.payload[:pre_approved_agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end

        it 'does not include the tool in pre_approved_tools' do
          expect(result.payload[:pre_approved_tools]).not_to include('create_work_item')
        end
      end

      context 'when a group has an allow rule' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
        end

        it 'includes the group constant in agent_privileges' do
          expect(result.payload[:agent_privileges]).to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end

        it 'includes the group constant in pre_approved_agent_privileges' do
          expect(result.payload[:pre_approved_agent_privileges]).to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end

        it 'includes the MCP tool name in pre_approved_tools' do
          expect(result.payload[:pre_approved_tools]).to include('create_work_item')
        end
      end

      context 'when tools in a group have mixed permissions' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
          create(:ai_tool_rule, namespace: namespace, tool_name: 'update_issue', web_access: :deny)
        end

        it 'deny takes precedence over allow' do
          expect(result.payload[:agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end

        it 'includes the allowed tool in pre_approved_tools' do
          expect(result.payload[:pre_approved_tools]).to include('create_work_item')
        end

        it 'includes the denied tool in denied_tools' do
          expect(result.payload[:denied_tools]).to include('update_issue')
        end
      end
    end

    context 'when read_only_files group has a rule' do
      context 'when a tool in the group is denied' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'read_file', web_access: :deny)
        end

        it 'excludes READ_ONLY_FILES from agent_privileges and includes the tool in denied_tools',
          :aggregate_failures do
          expect(result.payload[:agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_FILES
          )
          expect(result.payload[:denied_tools]).to include('read_file')
        end
      end
    end

    context 'when surface is local' do
      let(:surface) { :local }

      before do
        create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue',
          web_access: :deny, local_access: :allow)
      end

      it 'uses local_access instead of web_access' do
        expect(result.payload[:pre_approved_agent_privileges]).to include(
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
        )
      end
    end

    context 'when surface is ambient' do
      let(:surface) { :ambient }

      before do
        create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
      end

      it 'treats ambient as a web surface' do
        expect(result.payload[:pre_approved_agent_privileges]).to include(
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
        )
      end
    end

    context 'when project is provided' do
      let_it_be(:project) { create(:project, namespace: namespace) }

      subject(:service) { described_class.new(namespace: namespace, surface: surface, project: project) }

      context 'when project has no rules — inherits namespace rules' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :ask)
        end

        it 'uses the namespace rule', :aggregate_failures do
          expect(result.payload[:agent_privileges]).to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
          expect(result.payload[:pre_approved_agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end
      end

      context 'when project escalates namespace rule (ask → deny)' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :ask)
          create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue', web_access: :deny)
        end

        it 'applies the more restrictive project rule', :aggregate_failures do
          expect(result.payload[:agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
          expect(result.payload[:denied_tools]).to include('create_work_item')
        end
      end

      context 'when only a project rule exists with no namespace rule' do
        before do
          create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue', web_access: :deny)
        end

        it 'applies the project rule' do
          expect(result.payload[:denied_tools]).to include('create_work_item')
        end
      end

      context 'when namespace rule has nil for the queried surface' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: nil, local_access: :deny)
          create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue', web_access: :allow)
        end

        it 'allows project rule to set the unconfigured surface' do
          expect(result.payload[:pre_approved_tools]).to include('create_work_item')
        end
      end

      context 'when project rule has nil for the queried surface' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :ask)
          create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue', web_access: nil,
            local_access: :deny)
        end

        it 'keeps the namespace rule for the unconfigured surface', :aggregate_failures do
          expect(result.payload[:agent_privileges]).to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
          expect(result.payload[:pre_approved_agent_privileges]).not_to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
          )
        end
      end
    end

    context 'when surface is background' do
      let(:surface) { :background }

      context 'when no background rule is set' do
        it 'coerces the ask default to allow so un-ruled tools run (nil->allow rollout)', :aggregate_failures do
          # run_command defaults to :ask on web/local; on a background flow there is no
          # approver, so it must resolve to allow rather than land in neither list.
          expect(result.payload[:denied_tools]).to be_empty
          expect(result.payload[:agent_privileges]).to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS
          )
          expect(result.payload[:pre_approved_agent_privileges]).to include(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS
          )
        end
      end

      context 'when a background_access deny rule is set' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', background_access: :deny)
        end

        # `create_issue` resolves to the MCP tool name `create_work_item` in the
        # returned allow/deny lists (matches the existing web-surface deny spec above).
        it 'includes the tool in denied_tools' do
          expect(result.payload[:denied_tools]).to include('create_work_item')
        end
      end

      context 'when a background_access allow rule is set' do
        before do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', background_access: :allow)
        end

        it 'includes the tool in pre_approved_tools and not denied', :aggregate_failures do
          expect(result.payload[:pre_approved_tools]).to include('create_work_item')
          expect(result.payload[:denied_tools]).not_to include('create_work_item')
        end
      end

      context 'when a web/local-only rule exists with background_access unset' do
        before do
          # read_file has no distinct MCP alias in its group, so this genuinely
          # exercises the per-tool background fallback (a duplicate-named tool would
          # be pre-approved via its unruled sibling and mask the behaviour).
          create(:ai_tool_rule, namespace: namespace, tool_name: 'read_file', web_access: :deny)
        end

        it 'treats the unset background permission as allow, matching the displayed default', :aggregate_failures do
          # A rule with background_access nil must behave like no background rule on the background
          # surface (nil->allow), so display (resolver) and enforcement agree.
          expect(result.payload[:pre_approved_tools]).to include('read_file')
          expect(result.payload[:denied_tools]).not_to include('read_file')
        end
      end
    end

    context 'when surface is web and a background-only rule exists' do
      let(:surface) { :web }

      before do
        # A background-only rule leaves web_access nil; on web it must fall back to the
        # group default, so a background rule never demotes a default-allow tool on web.
        create(:ai_tool_rule, namespace: namespace, tool_name: 'list_issues', web_access: nil, background_access: :deny)
      end

      it 'keeps the default-allow tool pre-approved on web, matching the displayed default' do
        expect(result.payload[:pre_approved_tools]).to include('list_issues')
      end
    end
  end
end

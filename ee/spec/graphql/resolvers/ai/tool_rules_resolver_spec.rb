# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::ToolRulesResolver, feature_category: :ai_agents do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: namespace) }
  let_it_be(:developer) { create(:user, developer_of: namespace) }

  let(:current_user) { owner }
  let(:args) { { full_path: namespace.full_path } }

  subject(:result) { resolve(described_class, args: args, ctx: { current_user: current_user }) }

  before do
    ::Ai::ToolRules::Registry.instance_variable_set(:@all_tool_names, nil)
    ::Ai::ToolRules::Registry.instance_variable_set(:@catalog_tool_names, nil)
    ::Ai::ToolRules::Registry.instance_variable_set(:@action_type_for, nil)
  end

  describe '#resolve' do
    context 'when the namespace does not exist' do
      let(:args) { { full_path: 'non/existent' } }

      it 'returns ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the namespace is not a root namespace' do
      let_it_be(:subgroup) { create(:group, parent: namespace) }
      let(:args) { { full_path: subgroup.full_path } }

      it 'returns ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the current user is not an owner' do
      let(:current_user) { developer }

      it 'returns ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the current user is not authenticated' do
      let(:current_user) { nil }

      it 'returns ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when current_user cannot access the project' do
      let_it_be(:private_project) { create(:project, :private, namespace: namespace) }
      let_it_be(:non_member) { create(:user) }
      let(:current_user) { non_member }
      let(:args) { { full_path: namespace.full_path, project_path: private_project.full_path } }

      it 'returns ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the project does not belong to the namespace' do
      let_it_be(:other_namespace) { create(:group) }
      # :public so the read_project check passes and containment is what rejects.
      let_it_be(:other_project) { create(:project, :public, namespace: other_namespace) }

      let(:args) { { full_path: namespace.full_path, project_path: other_project.full_path } }

      it 'rejects the query with the containment error', :aggregate_failures do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        expect(result.message).to eq('Project does not belong to the namespace')
      end

      context 'when the caller legitimately owns both namespaces' do
        let_it_be(:dual_owner) { create(:user, owner_of: [namespace, other_namespace]) }

        let(:current_user) { dual_owner }

        it 'still rejects the query', :aggregate_failures do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
          expect(result.message).to eq('Project does not belong to the namespace')
        end
      end
    end

    # Pins today's behaviour rather than endorsing it: the sibling write path raises for an
    # unresolvable project_path. Aligning them is a change held out of this security fix.
    context 'when project_path does not resolve to a project' do
      let(:args) { { full_path: namespace.full_path, project_path: 'no/such-project' } }

      it 'does not reject the query' do
        expect(result.items.length).to eq(Ai::ToolRules::Registry.all_tool_names.length)
      end
    end

    context 'when the project is in a subgroup of the namespace' do
      let_it_be(:project_subgroup) { create(:group, parent: namespace) }
      let_it_be(:nested_project) { create(:project, namespace: project_subgroup) }

      let(:args) { { full_path: namespace.full_path, project_path: nested_project.full_path } }

      it 'does not reject a project nested below the root namespace' do
        expect(result.items.length).to eq(Ai::ToolRules::Registry.all_tool_names.length)
      end
    end

    context 'when the user is authorized' do
      it 'returns a result for every tool in the registry' do
        expect(result.items.length).to eq(Ai::ToolRules::Registry.all_tool_names.length)
      end

      it 'returns tools with correct fields' do
        tool = result.items.find { |t| t[:id] == 'create_issue' }

        expect(tool).to include(
          id: 'create_issue',
          name: 'Create Issue',
          action_type: :write,
          category: 'GitLab Write',
          source: 'gitlab',
          web_access: 'ask',
          local_access: 'ask',
          background_access: 'allow'
        )
      end

      it 'defaults a preapproved read tool to allow', :aggregate_failures do
        read_tool = Ai::ToolRules::Registry::PRIVILEGE_GROUP_MAPPING[:read_only_gitlab].first
        tool = result.items.find { |t| t[:id] == read_tool }

        expect(tool[:web_access]).to eq('allow')
        expect(tool[:local_access]).to eq('allow')
        expect(tool[:background_access]).to eq('allow')
      end

      context 'when rules exist for the namespace' do
        let_it_be(:rule) do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
        end

        it 'returns the existing rule values for configured tools' do
          tool = result.items.find { |t| t[:id] == 'create_issue' }

          expect(tool[:web_access]).to eq('allow')
          expect(tool[:local_access]).to eq('ask')
        end

        it 'returns a configured background_access value verbatim' do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'run_command', background_access: :deny)

          tool = result.items.find { |t| t[:id] == 'run_command' }

          expect(tool[:background_access]).to eq('deny')
        end

        it 'still returns fallback values for unconfigured tools', :aggregate_failures do
          read_file = result.items.find { |t| t[:id] == 'read_file' }
          list_issues = result.items.find { |t| t[:id] == 'list_issues' }

          # read-only file tools fall back to ask (local filesystem, least privilege)
          expect(read_file[:web_access]).to eq('ask')
          # read-only GitLab tools still fall back to allow
          expect(list_issues[:web_access]).to eq('allow')
        end
      end

      it 'returns tools with correct action types' do
        run_command = result.items.find { |t| t[:id] == 'run_command' }
        read_file = result.items.find { |t| t[:id] == 'read_file' }
        create_issue = result.items.find { |t| t[:id] == 'create_issue' }

        expect(run_command[:action_type]).to eq(:destroy)
        expect(read_file[:action_type]).to eq(:read)
        expect(create_issue[:action_type]).to eq(:write)
      end

      it 'returns correct source for all tools' do
        expect(result.items).to all(satisfy { |t| t[:source] == 'gitlab' })
      end

      context 'when project_path is provided' do
        let_it_be(:project) { create(:project, namespace: namespace) }
        let(:args) { { full_path: namespace.full_path, project_path: project.full_path } }

        it 'returns a result for every tool in the registry' do
          expect(result.items.length).to eq(Ai::ToolRules::Registry.all_tool_names.length)
        end

        context 'when no project rules exist — inherits namespace rules' do
          let_it_be(:namespace_rule) do
            create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :ask)
          end

          it 'returns the namespace rule values' do
            tool = result.items.find { |t| t[:id] == 'create_issue' }

            expect(tool[:web_access]).to eq('ask')
          end
        end

        context 'when project rule is stricter than namespace rule' do
          before do
            create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :ask)
            create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue', web_access: :deny)
          end

          it 'returns the more restrictive project rule' do
            tool = result.items.find { |t| t[:id] == 'create_issue' }

            expect(tool[:web_access]).to eq('deny')
          end
        end

        context 'when only a project rule exists with no namespace rule' do
          before do
            create(:ai_tool_rule, namespace: namespace, project: project, tool_name: 'create_issue', web_access: :deny)
          end

          it 'returns the project rule' do
            tool = result.items.find { |t| t[:id] == 'create_issue' }

            expect(tool[:web_access]).to eq('deny')
          end
        end
      end

      context 'when search is provided' do
        let(:args) { { full_path: namespace.full_path, search: 'issue' } }

        before do
          allow(::Ai::ToolRules::Registry).to receive_messages(all_tool_names: %w[create_issue read_file run_command],
            action_type_for: { 'create_issue' => :write, 'read_file' => :read, 'run_command' => :destroy })
        end

        it 'returns only tools whose name matches the search term' do
          expect(result.items.map { |t| t[:id] }).to contain_exactly('create_issue')
        end

        it 'excludes tools that do not match the search term' do
          expect(result.items.map { |t| t[:id] }).not_to include('read_file', 'run_command')
        end

        it 'is case-insensitive' do
          upper_result = resolve(described_class,
            args: { full_path: namespace.full_path, search: 'ISSUE' },
            ctx: { current_user: current_user })
          expect(result.items.map { |t| t[:id] }).to match_array(upper_result.items.map { |t| t[:id] })
        end
      end

      context 'when action_type is provided' do
        let(:args) { { full_path: namespace.full_path, action_type: 'WRITE' } }

        before do
          allow(::Ai::ToolRules::Registry).to receive_messages(all_tool_names: %w[create_issue read_file run_command],
            action_type_for: { 'create_issue' => :write, 'read_file' => :read, 'run_command' => :destroy })
        end

        it 'returns only tools matching the action type' do
          expect(result.items).to all(satisfy { |t| t[:action_type] == :write })
        end

        it 'excludes tools with a different action type' do
          expect(result.items.map { |t| t[:id] }).not_to include('read_file', 'run_command')
        end
      end

      context 'when search and action_type are combined' do
        let(:args) { { full_path: namespace.full_path, search: 'issue', action_type: 'WRITE' } }

        before do
          allow(::Ai::ToolRules::Registry).to receive_messages(
            all_tool_names: %w[create_issue get_issue read_file
              run_command], action_type_for: {
                'create_issue' => :write, 'get_issue' => :read, 'read_file' => :read, 'run_command' => :destroy
              })
        end

        it 'returns only tools matching both filters' do
          expect(result.items.map { |t| t[:id] }).to contain_exactly('create_issue')
        end
      end

      context 'when no filters are provided' do
        it 'returns all tools' do
          expect(result.items.length).to eq(Ai::ToolRules::Registry.all_tool_names.length)
        end
      end

      context 'when search matches display name but not tool_name' do
        let(:args) { { full_path: namespace.full_path, search: 'GitLab User' } }

        before do
          allow(::Ai::ToolRules::Registry).to receive_messages(all_tool_names: %w[gitlab__user_search read_file],
            action_type_for: { 'gitlab__user_search' => :read, 'read_file' => :read })
        end

        it 'returns tools matching the display name' do
          expect(result.items.map { |t| t[:id] }).to include('gitlab__user_search')
        end
      end

      context 'when search is an empty string' do
        let(:args) { { full_path: namespace.full_path, search: '' } }

        it 'returns all tools' do
          expect(result.items.length).to eq(Ai::ToolRules::Registry.all_tool_names.length)
        end
      end
    end
  end
end

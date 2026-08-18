# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::UpdateAiToolRule, feature_category: :ai_agents do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('UpdateAiToolRule') }

  it { is_expected.to have_graphql_fields(:tool_rule, :errors, :client_mutation_id) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :full_path,
      :project_path,
      :tool_id,
      :web_access,
      :local_access,
      :background_access,
      :client_mutation_id
    )
  end

  describe '#resolve' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:owner) { create(:user, owner_of: namespace) }
    let_it_be(:developer) { create(:user, developer_of: namespace) }

    let(:current_user) { owner }
    let(:tool_id) { 'create_issue' }
    let(:web_access) { 'ask' }
    let(:local_access) { nil }
    let(:mutation_params) do
      {
        full_path: namespace.full_path,
        tool_id: tool_id,
        web_access: web_access,
        local_access: local_access
      }
    end

    subject(:result) { resolve(described_class, args: mutation_params, ctx: { current_user: current_user }) }

    before do
      ::Ai::ToolRules::Registry.instance_variable_set(:@all_tool_names, nil)
      ::Ai::ToolRules::Registry.instance_variable_set(:@catalog_tool_names, nil)
      ::Ai::ToolRules::Registry.instance_variable_set(:@action_type_for, nil)
    end

    context 'when the user is not authorized' do
      let(:current_user) { developer }

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the namespace does not exist' do
      let(:mutation_params) { { full_path: 'non/existent', tool_id: tool_id, web_access: web_access } }

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when namespace is not a root namespace' do
      let(:subgroup) { create(:group, parent: namespace) }
      let(:mutation_params) { { full_path: subgroup.full_path, tool_id: tool_id, web_access: web_access } }

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the tool_id is not a known tool name' do
      let(:tool_id) { 'invented_tool' }

      it 'returns an argument error' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ArgumentError)
      end
    end

    context 'when current_user cannot access the project' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:private_project) { create(:project, :private, namespace: other_namespace) }

      let(:mutation_params) do
        {
          full_path: namespace.full_path,
          project_path: private_project.full_path,
          tool_id: tool_id,
          web_access: web_access
        }
      end

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user is authorized' do
      it 'creates a new rule and returns the correct fields', :aggregate_failures do
        expect(result[:tool_rule][:web_access]).to eq('ask')
        expect(result[:tool_rule][:local_access]).to be_nil
        expect(result[:errors]).to be_empty
      end

      it 'persists the rule to the database' do
        expect { result }.to change { Ai::ToolRule.count }.by(1)
      end

      it 'creates the rule with the correct attributes', :aggregate_failures do
        result

        rule = Ai::ToolRule.find_by(namespace_id: namespace.id, tool_name: 'create_issue')
        expect(rule.web_access).to eq('ask')
        expect(rule.local_access).to be_nil
      end

      context 'when a rule already exists for the tool' do
        let_it_be(:existing_rule) do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
        end

        it 'updates the existing rule' do
          expect { result }.not_to change { Ai::ToolRule.count }
        end

        it 'returns the updated values', :aggregate_failures do
          expect(result[:tool_rule][:web_access]).to eq('ask')
          expect(result[:errors]).to be_empty
        end
      end

      context 'when background_access is provided' do
        let(:mutation_params) do
          { full_path: namespace.full_path, tool_id: tool_id, background_access: 'deny' }
        end

        it 'persists and returns background_access', :aggregate_failures do
          expect(result[:tool_rule][:background_access]).to eq('deny')
          expect(result[:errors]).to be_empty
          rule = Ai::ToolRule.find_by(namespace_id: namespace.id, tool_name: 'create_issue')
          expect(rule.background_access).to eq('deny')
        end
      end

      context 'when only local_access is provided' do
        let(:web_access) { nil }
        let(:local_access) { 'deny' }

        it 'sets only local_access', :aggregate_failures do
          result

          rule = Ai::ToolRule.find_by(namespace_id: namespace.id, tool_name: 'create_issue')
          expect(rule.web_access).to be_nil
          expect(rule.local_access).to eq('deny')
        end
      end

      context 'when the service returns an error' do
        before do
          allow_next_instance_of(::Ai::ToolRules::UpsertService) do |service|
            allow(service).to receive(:execute)
              .and_return(ServiceResponse.error(message: 'rule could not be saved'))
          end
        end

        it 'returns errors in the payload', :aggregate_failures do
          expect(result[:errors]).to include('rule could not be saved')
          expect(result[:tool_rule]).to be_nil
        end
      end

      context 'when project_path is provided' do
        let_it_be(:project) { create(:project, namespace: namespace) }

        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            project_path: project.full_path,
            tool_id: tool_id,
            web_access: web_access
          }
        end

        it 'creates a project-scoped rule', :aggregate_failures do
          result
          rule = Ai::ToolRule.find_by(namespace_id: namespace.id, project_id: project.id, tool_name: 'create_issue')

          expect(rule).to be_present
          expect(rule.web_access).to eq('ask')
        end

        it 'does not affect namespace-level rules' do
          result

          expect(Ai::ToolRule.for_namespace(namespace.id).find_by(tool_name: 'create_issue')).to be_nil
        end
      end

      context 'when project_path does not exist' do
        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            project_path: 'non/existent',
            tool_id: tool_id,
            web_access: web_access
          }
        end

        it 'returns ResourceNotAvailable' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when project does not belong to namespace' do
        let_it_be(:other_namespace) { create(:group) }
        let_it_be(:other_project) { create(:project, namespace: other_namespace) }

        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            project_path: other_project.full_path,
            tool_id: tool_id,
            web_access: web_access
          }
        end

        it 'returns ResourceNotAvailable' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::BulkUpdateAiToolRules, feature_category: :ai_agents do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('BulkUpdateAiToolRules') }

  it { is_expected.to have_graphql_fields(:results, :errors, :client_mutation_id) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :full_path,
      :project_path,
      :tool_rules,
      :client_mutation_id
    )
  end

  describe '#resolve' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:owner) { create(:user, owner_of: namespace) }
    let_it_be(:developer) { create(:user, developer_of: namespace) }

    let(:current_user) { owner }
    let(:mutation_params) do
      {
        full_path: namespace.full_path,
        tool_rules: [
          { tool_id: 'create_issue', web_access: 'ask' },
          { tool_id: 'read_file', web_access: 'deny' }
        ]
      }
    end

    subject(:result) { resolve(described_class, args: mutation_params, ctx: { current_user: current_user }) }

    before do
      ::Ai::ToolRules::Registry.instance_variable_set(:@all_tool_names, nil)
      ::Ai::ToolRules::Registry.instance_variable_set(:@catalog_tool_names, nil)
      ::Ai::ToolRules::Registry.instance_variable_set(:@action_type_for, nil)
      allow(Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when the user is not authorized' do
      let(:current_user) { developer }

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the namespace does not exist' do
      let(:mutation_params) do
        { full_path: 'non/existent', tool_rules: [{ tool_id: 'create_issue', web_access: 'ask' }] }
      end

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when namespace is not a root namespace' do
      let_it_be(:subgroup) { create(:group, parent: namespace) }
      let(:mutation_params) do
        { full_path: subgroup.full_path, tool_rules: [{ tool_id: 'create_issue', web_access: 'ask' }] }
      end

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when current_user cannot access the project' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:private_project) { create(:project, :private, namespace: other_namespace) }

      let(:mutation_params) do
        {
          full_path: namespace.full_path,
          project_path: private_project.full_path,
          tool_rules: [{ tool_id: 'create_issue', web_access: 'ask' }]
        }
      end

      it 'raises ResourceNotAvailable' do
        expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user is authorized' do
      it 'creates rules and returns results', :aggregate_failures do
        expect(result[:results].length).to eq(2)
        expect(result[:errors]).to be_empty
      end

      it 'persists all rules in a single upsert', :aggregate_failures do
        expect(::Ai::ToolRule).to receive(:upsert_all).once.and_call_original
        expect { result }.to change { Ai::ToolRule.count }.by(2)
      end

      it 'returns correct values for each rule', :aggregate_failures do
        create_issue_result = result[:results].find { |r| r[:tool_id] == 'create_issue' }
        read_file_result = result[:results].find { |r| r[:tool_id] == 'read_file' }

        expect(create_issue_result[:tool_rule][:web_access]).to eq('ask')
        expect(create_issue_result[:errors]).to be_empty
        expect(read_file_result[:tool_rule][:web_access]).to eq('deny')
        expect(read_file_result[:errors]).to be_empty
      end

      it 'emits a single bulk audit event' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'ai_tool_rules_bulk_updated',
            author: owner,
            scope: namespace,
            additional_details: hash_including(
              tool_count: 2,
              tool_names: %w[create_issue read_file]
            )
          )
        )

        result
      end

      context 'when background_access is provided' do
        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            tool_rules: [{ tool_id: 'create_issue', background_access: 'deny' }]
          }
        end

        it 'persists and returns background_access', :aggregate_failures do
          create_issue_result = result[:results].find { |r| r[:tool_id] == 'create_issue' }

          expect(create_issue_result[:tool_rule][:background_access]).to eq('deny')
          rule = Ai::ToolRule.find_by(namespace_id: namespace.id, tool_name: 'create_issue')
          expect(rule.background_access).to eq('deny')
        end

        context 'when the rule already exists (on_duplicate update)' do
          before do
            create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', background_access: :allow)
          end

          it 'updates background_access via the upsert on_duplicate clause' do
            expect { result }.to change {
              Ai::ToolRule.find_by(namespace_id: namespace.id, tool_name: 'create_issue').background_access
            }.from('allow').to('deny')
          end
        end
      end

      context 'when a rule already exists for a tool' do
        let_it_be(:existing_rule) do
          create(:ai_tool_rule, namespace: namespace, tool_name: 'create_issue', web_access: :allow)
        end

        it 'updates the existing rule without creating a new one' do
          existing_rule

          expect { result }.to change { Ai::ToolRule.count }.by(1)
        end

        it 'returns the updated values' do
          create_issue_result = result[:results].find { |r| r[:tool_id] == 'create_issue' }

          expect(create_issue_result[:tool_rule][:web_access]).to eq('ask')
        end
      end

      context 'when one tool_id is unknown' do
        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            tool_rules: [
              { tool_id: 'create_issue', web_access: 'ask' },
              { tool_id: 'invented_tool', web_access: 'deny' }
            ]
          }
        end

        it 'returns an error for the unknown tool and succeeds for the known one', :aggregate_failures do
          create_issue_result = result[:results].find { |r| r[:tool_id] == 'create_issue' }
          invented_result = result[:results].find { |r| r[:tool_id] == 'invented_tool' }

          expect(create_issue_result[:errors]).to be_empty
          expect(create_issue_result[:tool_rule]).to be_present
          expect(invented_result[:errors]).to include('invented_tool is not a known tool name')
          expect(invented_result[:tool_rule]).to be_nil
        end

        it 'only persists the valid rule' do
          expect { result }.to change { Ai::ToolRule.count }.by(1)
        end

        it 'does not include the unknown tool in the audit event' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              additional_details: hash_including(
                tool_count: 1,
                tool_names: ['create_issue']
              )
            )
          )

          result
        end
      end

      context 'when all tool_ids are unknown' do
        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            tool_rules: [{ tool_id: 'invented_tool', web_access: 'deny' }]
          }
        end

        it 'does not emit an audit event' do
          expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(
            hash_including(name: 'ai_tool_rules_bulk_updated')
          )

          result
        end

        it 'does not persist any rules' do
          expect { result }.not_to change { Ai::ToolRule.count }
        end
      end

      context 'when project_path is provided' do
        let_it_be(:project) { create(:project, namespace: namespace) }

        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            project_path: project.full_path,
            tool_rules: [{ tool_id: 'create_issue', web_access: 'ask' }]
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
            tool_rules: [{ tool_id: 'create_issue', web_access: 'ask' }]
          }
        end

        it 'raises ResourceNotAvailable' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when project does not belong to the namespace' do
        let_it_be(:other_namespace) { create(:group) }
        let_it_be(:other_project) { create(:project, namespace: other_namespace) }

        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            project_path: other_project.full_path,
            tool_rules: [{ tool_id: 'create_issue', web_access: 'ask' }]
          }
        end

        it 'raises ResourceNotAvailable' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when no access surface is provided' do
        let(:mutation_params) do
          {
            full_path: namespace.full_path,
            tool_rules: [{ tool_id: 'create_issue' }]
          }
        end

        it 'returns a per-item error', :aggregate_failures do
          expect(result[:results].first[:errors]).to include(
            'At least one of web_access, local_access, or background_access must be provided'
          )
          expect(result[:results].first[:tool_rule]).to be_nil
        end

        it 'does not persist any rules' do
          expect { result }.not_to change { Ai::ToolRule.count }
        end
      end

      context 'when the database raises an error' do
        before do
          allow(::Ai::ToolRule).to receive(:upsert_all)
            .and_raise(ActiveRecord::StatementInvalid.new('DB error'))
        end

        it 'returns a top-level error and per-item errors for valid inputs', :aggregate_failures do
          expect(result[:errors]).to include('Failed to save tool rules')
          expect(result[:results].length).to eq(2)
          expect(result[:results]).to all(satisfy { |r|
            r[:errors].include?('Failed to save rule') && r[:tool_rule].nil?
          })
        end

        it 'does not emit an audit event' do
          expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(
            hash_including(name: 'ai_tool_rules_bulk_updated')
          )

          result
        end

        it 'tracks the exception' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(ActiveRecord::StatementInvalid),
            hash_including(namespace_id: namespace.id)
          )

          result
        end
      end
    end
  end
end

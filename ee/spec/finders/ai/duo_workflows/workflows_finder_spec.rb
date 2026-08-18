# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowsFinder, feature_category: :duo_agent_platform do
  let_it_be_with_reload(:ai_settings) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be_with_reload(:group) { create(:group, ai_settings: ai_settings) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  before do
    allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
  end

  describe '#default_options' do
    subject(:default_options) { described_class.new(current_user: user).default_options }

    it 'returns the default options' do
      expect(default_options).to eq({ sort: 'created_desc' })
    end
  end

  describe '#resolve_type' do
    let_it_be(:workflows) do
      %w[chat some_cool_agent another_cool_agent].map do |workflow_definition|
        create(:duo_workflows_workflow, :created, project: project, user: user, created_at: 2.days.ago,
          workflow_definition: workflow_definition)
      end
    end

    let(:type) { 'chat' }

    let(:options) { { current_user: user, source: user, type: type } }

    before do
      allow(::Ai::FoundationalChatAgent).to receive(:workflow_definitions).and_return(%w[chat some_cool_agent])
    end

    subject(:results) { described_class.new(options).results }

    context 'when is foundational_chat_agents' do
      let(:type) { 'foundational_chat_agents' }

      it 'fetches workflows for foundational chat agents' do
        expect(results).to match_array([workflows[0], workflows[1]])
      end
    end

    context 'when is non_foundational_chat_agents' do
      let(:type) { 'non_foundational_chat_agents' }

      it 'fetches workflows that are not foundational chat agents' do
        expect(results).to match_array([workflows[2]])
      end
    end

    context 'when is chat' do
      it 'fetches only workflows for duo agent chat' do
        expect(results).to match_array([workflows[0]])
      end
    end

    context 'when type is not a string' do
      let(:type) { 123 }

      it 'raises an ArgumentError' do
        expect { results }.to raise_error(ArgumentError, /type must be a string/)
      end
    end
  end

  describe '#resolve_sort' do
    subject(:results) { described_class.new(options).results }

    let(:options) { { current_user: user, source: user, sort: sort } }

    context 'when sorting is created' do
      let_it_be(:first_workflow) do
        create(:duo_workflows_workflow, project: project, user: user, created_at: 2.days.ago)
      end

      let_it_be(:second_workflow) do
        create(:duo_workflows_workflow, project: project, user: user, created_at: 1.day.ago)
      end

      context 'and direction is asc' do
        let(:sort) { 'created_asc' }

        it 'orders results by created_at ascending' do
          expect(results).to eq([first_workflow, second_workflow])
        end
      end

      context 'and direction is desc' do
        let(:sort) { 'created_desc' }

        it 'orders results by created_at descending' do
          expect(results.records).to eq([second_workflow, first_workflow])
        end
      end

      context 'and direction is invalid' do
        let(:sort) { 'created' }

        it 'falls back to ascending direction' do
          expect(results).to eq([first_workflow, second_workflow])
        end
      end
    end

    context 'when sorting is status' do
      let_it_be(:created_workflow) do
        create(:duo_workflows_workflow, :created, project: project, user: user, created_at: 2.days.ago)
      end

      let_it_be(:running_workflow) do
        create(:duo_workflows_workflow, :running, project: project, user: user, created_at: 1.day.ago)
      end

      context 'and direction is asc' do
        let(:sort) { 'status_asc' }

        it 'orders results by their status ascending' do
          expect(results).to eq([created_workflow, running_workflow])
        end
      end

      context 'and direction is desc' do
        let(:sort) { 'status_desc' }

        it 'orders results by their status descending' do
          expect(results.records).to eq([running_workflow, created_workflow])
        end
      end
    end
  end

  describe '#resolve_search' do
    using RSpec::Parameterized::TableSyntax

    subject(:query) { described_class.new(options).results.to_sql }

    let(:options) do
      { current_user: user, source: user, search: term }
    end

    # rubocop:disable Layout/LineLength -- Required for formatting of table
    where(:term, :filter_by_words, :filter_by_ids) do
      '123'                                                | []                                                     | [123]
      '#456'                                               | []                                                     | [456]
      'soft devel'                                         | %w[soft devel]                                         | []
      'soft devel v1'                                      | %w[soft devel v1]                                      | []
      'soft devel 123'                                     | %w[soft devel]                                         | [123]
      'soft devel #123'                                    | %w[soft devel]                                         | [123]
      '#123 soft devel'                                    | %w[soft devel]                                         | [123]
      'soft devel v1 #123'                                 | %w[soft devel v1]                                      | [123]
      'soft devel v1 123 456'                              | %w[soft devel v1]                                      | [123, 456]
      'soft devel v1 #123 #456'                            | %w[soft devel v1]                                      | [123, 456]
      'soft devel v13 #123 456'                            | %w[soft devel v13]                                     | [123, 456]
      'http://example.com/group/proj/-/pipelines/1154'     | %w[http://example.com/group/proj/-/pipelines/1154]     | []
      'fix http://example.com/group/proj/-/pipelines/1154' | %w[fix http://example.com/group/proj/-/pipelines/1154] | []
      '#42 http://example.com/group/proj/-/pipelines/1154' | %w[http://example.com/group/proj/-/pipelines/1154]     | [42]
    end
    # rubocop:enable Layout/LineLength

    with_them do
      it 'fuzzy searches all words' do
        if filter_by_words.empty?
          expect(query).not_to include('ILIKE')
        else
          expected_query = [:workflow_definition, :goal].map do |column|
            filter_by_words.map do |word|
              Ai::DuoWorkflows::Workflow.arel_table[column].matches("%#{word}%")
            end.reduce(:and)
          end.reduce(:or).to_sql

          expect(query).to include(expected_query)
        end
      end

      it 'filters by IDs' do
        if filter_by_ids.empty?
          expect(query).not_to include('"duo_workflows_workflows"."id"')
        elsif filter_by_ids.many?
          expect(query).to include(Ai::DuoWorkflows::Workflow.arel_table[:id].in(filter_by_ids).to_sql)
        else
          expect(query).to include(Ai::DuoWorkflows::Workflow.arel_table[:id].eq(filter_by_ids.first).to_sql)
        end
      end
    end
  end

  describe '#resolve_updated_after' do
    subject(:results) { described_class.new(options).results }

    let_it_be(:old_workflow) do
      create(:duo_workflows_workflow, project: project, user: user, updated_at: 40.days.ago)
    end

    let_it_be(:recent_workflow) do
      create(:duo_workflows_workflow, project: project, user: user, updated_at: 10.days.ago)
    end

    let_it_be(:very_recent_workflow) do
      create(:duo_workflows_workflow, project: project, user: user, updated_at: 1.day.ago)
    end

    context 'when updated_after is provided' do
      let(:options) do
        { current_user: user, source: user, updated_after: 30.days.ago }
      end

      it 'returns only workflows updated after the specified date' do
        expect(results).to match_array([recent_workflow, very_recent_workflow])
      end

      it 'excludes workflows updated before the specified date' do
        expect(results).not_to include(old_workflow)
      end
    end

    context 'when updated_after is not provided' do
      let(:options) do
        { current_user: user, source: user }
      end

      it 'returns all workflows' do
        expect(results).to match_array([old_workflow, recent_workflow, very_recent_workflow])
      end
    end
  end

  describe 'filtering by ids option' do
    subject(:results) { described_class.new(options).results }

    let_it_be(:workflow_a) { create(:duo_workflows_workflow, project: project, user: user) }
    let_it_be(:workflow_b) { create(:duo_workflows_workflow, project: project, user: user) }
    let_it_be(:workflow_c) { create(:duo_workflows_workflow, project: project, user: user) }

    context 'when ids is a populated array' do
      let(:options) do
        { current_user: user, source: user, ids: [workflow_a.id, workflow_c.id] }
      end

      it 'returns only the matching workflows' do
        expect(results).to match_array([workflow_a, workflow_c])
      end
    end

    context 'when ids contains an id the user does not own' do
      let_it_be(:other_user) { create(:user) }
      let_it_be(:other_workflow) { create(:duo_workflows_workflow, project: project, user: other_user) }

      let(:options) do
        { current_user: user, source: user, ids: [workflow_a.id, other_workflow.id] }
      end

      it 'filters out unauthorized workflows via the base_query scope' do
        expect(results).to match_array([workflow_a])
      end
    end

    context 'when ids is an empty array' do
      let(:options) do
        { current_user: user, source: user, ids: [] }
      end

      it 'returns no workflows because id_in([]) matches nothing' do
        expect(results).to be_empty
      end
    end

    context 'when ids is not provided' do
      let(:options) do
        { current_user: user, source: user }
      end

      it 'returns all workflows for the user' do
        expect(results).to match_array([workflow_a, workflow_b, workflow_c])
      end
    end
  end
end

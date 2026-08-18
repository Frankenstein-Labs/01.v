# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Search::SearchService, feature_category: :mcp_server do
  let(:mock_tool_global) { instance_double(Mcp::Tools::Base::ApiTool, name: :gitlab_search_in_instance) }
  let(:mock_tool_group) { instance_double(Mcp::Tools::Base::ApiTool, name: :gitlab_search_in_group) }
  let(:mock_tool_project) { instance_double(Mcp::Tools::Base::ApiTool, name: :gitlab_search_in_project) }
  let(:tools) { [mock_tool_global, mock_tool_group, mock_tool_project] }
  let(:service) { described_class.new(tools: tools) }

  describe '#description' do
    it 'returns the correct description' do
      expect(service.description).to eq("" \
        "Search across GitLab with automatic selection of the best available search method.\n\n" \
        "**Capabilities:** basic (keywords, file filters)\n\n" \
        "**Syntax Examples:**\n- Basic: \"bug fix\", \"filename:*.rb\", \"extension:js\"")
    end

    context 'when advanced search is enabled' do
      it 'returns the correct description' do
        stub_ee_application_setting(elasticsearch_search: true)

        expect(service.description).to include('advanced (boolean operators)')
      end
    end

    context 'when exact code search is enabled' do
      it 'returns the correct description' do
        allow(::Search::Zoekt).to receive(:search_enabled?).and_return(true)

        expect(service.description).to include('exact code (exact match, regex, symbols)')
      end
    end
  end

  describe '#input_schema' do
    let(:schema) { service.input_schema }
    let(:base_properties) do
      %i[scope search group_id project_id state confidential order_by sort per_page page type]
    end

    before do
      stub_ee_application_setting(elasticsearch_search: advanced_search, elasticsearch_indexing: advanced_search)
      allow(::Search::Zoekt).to receive(:search_enabled?).and_return(exact_code_search)
    end

    context 'when neither advanced nor exact code search is enabled' do
      let(:advanced_search) { false }
      let(:exact_code_search) { false }

      it 'exposes the base properties and the work item type filter', :aggregate_failures do
        expect(schema[:properties].keys).to match_array(base_properties)
        expect(schema[:properties][:type][:type]).to eq('array')
        expect(schema[:properties][:type][:items][:type]).to eq('string')
      end
    end

    context 'when only exact code search is enabled' do
      let(:advanced_search) { false }
      let(:exact_code_search) { true }

      it 'adds the regex property', :aggregate_failures do
        expect(schema[:properties].keys).to match_array(base_properties + [:regex])
        expect(schema[:properties][:regex][:type]).to eq('boolean')
        expect(schema[:properties][:regex][:description]).to eq(
          'Performs a regex code search. Available for blobs scope; other scopes are ignored.'
        )
      end
    end

    context 'when only advanced search is enabled' do
      let(:advanced_search) { true }
      let(:exact_code_search) { false }

      it 'adds the fields property', :aggregate_failures do
        expect(schema[:properties].keys).to match_array(base_properties + [:fields])
        expect(schema[:properties][:fields][:type]).to eq('array')
        expect(schema[:properties][:fields][:items][:type]).to eq('string')
        expect(schema[:properties][:fields][:description]).to eq(
          "Specify which fields to search within. Currently supported:\n" \
            "- Allowed values: title only\n" \
            "- Applicable scopes: work_items, merge_requests"
        )
      end
    end

    context 'when both advanced and exact code search are enabled' do
      let(:advanced_search) { true }
      let(:exact_code_search) { true }

      it 'adds both the regex and fields properties' do
        expect(schema[:properties].keys).to match_array(base_properties + [:regex, :fields])
      end
    end

    context 'when advanced search is enabled' do
      let(:advanced_search) { true }
      let(:exact_code_search) { false }

      it 'exposes the expected input schema' do
        expect(schema).to match(
          type: 'object',
          additionalProperties: false,
          required: %w[scope search],
          properties: {
            scope: {
              type: 'string',
              description: a_string_including(
                'GitLab instance: projects, blobs, work_items, merge_requests, wiki_blobs, commits, notes, ' \
                  'milestones, users, snippet_titles',
                'Group: projects, blobs, work_items, merge_requests, wiki_blobs, commits, notes, milestones, users',
                'Use "work_items" to search for issues, tasks, epics, and other work items'
              )
            },
            search: { type: 'string', description: 'The term to search for' },
            group_id: { type: 'string', description: a_string_including('within a group') },
            project_id: { type: 'string', description: a_string_including('within a project') },
            state: {
              type: 'string',
              description: a_string_including(
                'Work items:',
                'Only applies to work_items and merge_requests scopes.'
              )
            },
            confidential: { type: 'boolean', description: a_string_including('confidentiality') },
            order_by: { type: 'string', description: a_string_including('created_at') },
            sort: { type: 'string', description: a_string_including('asc, desc') },
            per_page: { type: 'integer', minimum: 1, description: a_string_including('per page') },
            page: { type: 'integer', minimum: 1, description: a_string_including('Page number') },
            fields: {
              type: 'array',
              items: { type: 'string' },
              description: a_string_including('Applicable scopes: work_items, merge_requests')
            },
            type: {
              type: 'array',
              items: { type: 'string' },
              description: a_string_including('Only applies to work_items scope.')
            }
          }
        )
      end
    end
  end

  describe '#transform_arguments' do
    let_it_be_with_reload(:project) { create(:project) }

    subject(:transform_arguments) { service.send(:transform_arguments, args) }

    context 'when scope is blobs' do
      let(:args) { { scope: 'blobs', search: 'test query', id: project.id.to_s } }

      context 'with no exclusion rules' do
        it 'returns args unchanged' do
          expect(transform_arguments).to eq(args)
        end
      end

      context 'with exclusion rules' do
        before do
          project.create_project_setting unless project.project_setting
          project.project_setting.update!(
            duo_context_exclusion_settings: { exclusion_rules: ['*.md', 'config/**/*.yml'] }
          )
        end

        it 'appends -filename: for simple patterns and -path: for path patterns' do
          result = transform_arguments
          expect(result[:search]).to eq('test query -filename:*.md -path:config/**/*.yml')
        end

        it 'preserves other arguments' do
          result = transform_arguments
          expect(result[:scope]).to eq('blobs')
          expect(result[:id]).to eq(project.id.to_s)
        end
      end

      context 'with path-based exclusion rules' do
        before do
          project.create_project_setting unless project.project_setting
          project.project_setting.update!(
            duo_context_exclusion_settings: { exclusion_rules: ['ruby/server.rb', 'ruby/*.rb', 'ruby/*'] }
          )
        end

        it 'uses -path: filter for patterns with /' do
          result = transform_arguments
          expect(result[:search]).to eq('test query -path:ruby/server.rb -path:ruby/*.rb -path:ruby/*')
        end
      end

      context 'with filename-based exclusion rules' do
        before do
          project.create_project_setting unless project.project_setting
          project.project_setting.update!(
            duo_context_exclusion_settings: { exclusion_rules: ['server.rb', '*.rb'] }
          )
        end

        it 'uses -filename: filter for simple patterns' do
          result = transform_arguments
          expect(result[:search]).to eq('test query -filename:server.rb -filename:*.rb')
        end
      end

      context 'with empty exclusion rules array' do
        before do
          project.create_project_setting unless project.project_setting
          project.project_setting.update!(
            duo_context_exclusion_settings: { exclusion_rules: [] }
          )
        end

        it 'returns args unchanged' do
          expect(transform_arguments).to eq(args)
        end
      end

      context 'when project is not found' do
        let(:args) { { scope: 'blobs', search: 'test query', id: 'nonexistent' } }

        it 'returns args unchanged' do
          expect(transform_arguments).to eq(args)
        end
      end

      context 'when project has no settings' do
        before do
          project.project_setting&.destroy!
          project.reload
        end

        it 'returns args unchanged' do
          expect(transform_arguments).to eq(args)
        end
      end
    end

    context 'when scope is wiki_blobs' do
      let(:args) { { scope: 'wiki_blobs', search: 'test query', id: project.id.to_s } }

      context 'with filename pattern' do
        before do
          project.create_project_setting unless project.project_setting
          project.project_setting.update!(
            duo_context_exclusion_settings: { exclusion_rules: ['*.md'] }
          )
        end

        it 'appends -filename: filters to search query' do
          result = transform_arguments
          expect(result[:search]).to eq('test query -filename:*.md')
        end
      end

      context 'with path pattern' do
        before do
          project.create_project_setting unless project.project_setting
          project.project_setting.update!(
            duo_context_exclusion_settings: { exclusion_rules: ['docs/index.md', 'docs/*'] }
          )
        end

        it 'appends -path: filters to search query' do
          result = transform_arguments
          expect(result[:search]).to eq('test query -path:docs/index.md -path:docs/*')
        end
      end
    end

    context 'when scope is not blobs or wiki_blobs' do
      let(:args) { { scope: 'issues', search: 'test query', id: project.id.to_s } }

      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: ['*.md'] }
        )
      end

      it 'does not apply exclusion' do
        expect(transform_arguments).to eq(args)
      end
    end

    context 'when using project full_path' do
      let(:args) { { scope: 'blobs', search: 'test query', id: project.full_path } }

      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: ['*.md', 'docs/*'] }
        )
      end

      it 'finds project by full_path and applies exclusion' do
        result = transform_arguments
        expect(result[:search]).to eq('test query -filename:*.md -path:docs/*')
      end
    end

    context 'when search query is empty' do
      let(:args) { { scope: 'blobs', search: '', id: project.id.to_s } }

      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: { exclusion_rules: ['*.md'] }
        )
      end

      it 'adds filters without leading space' do
        result = transform_arguments
        expect(result[:search]).to eq('-filename:*.md')
      end
    end

    context 'when args[:id] is nil' do
      let(:args) { { scope: 'blobs', search: 'test query', id: nil } }

      it 'returns args unchanged' do
        expect(transform_arguments).to eq(args)
      end
    end

    context 'when project settings exist but exclusion_rules key is missing' do
      let(:args) { { scope: 'blobs', search: 'test query', id: project.id.to_s } }

      before do
        project.create_project_setting unless project.project_setting
        project.project_setting.update!(
          duo_context_exclusion_settings: {}
        )
      end

      it 'returns args unchanged' do
        expect(transform_arguments).to eq(args)
      end
    end
  end
end

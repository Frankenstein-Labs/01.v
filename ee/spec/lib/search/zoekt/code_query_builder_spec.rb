# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::CodeQueryBuilder, feature_category: :global_search do
  subject(:result) { described_class.build(query: query, options: options) }

  let(:query) { 'test' }
  let(:current_user) { create(:user) }
  let(:auth) { instance_double(::Search::AuthorizationContext) }
  let(:fixtures_path) { 'ee/spec/fixtures/search/zoekt/' }
  let(:expected_extracted_result) do
    json_result = File.read(Rails.root.join(fixtures_path, extracted_result_path))
    ::Gitlab::Json.safe_parse(json_result).deep_symbolize_keys
  end

  before do
    allow(Search::AuthorizationContext).to receive(:new).and_return(auth)

    allow(auth).to receive(:get_access_levels_for_feature).with('repository')
        .and_return({ project: ::Gitlab::Access::GUEST, private_project: ::Gitlab::Access::REPORTER })

    stub_zoekt_features(traversal_id_search: true)
  end

  describe '#build' do
    context 'when project search' do
      let(:extracted_result_path) { 'search_project.json' }

      let(:options) do
        {
          features: 'repository',
          group_ids: [],
          project_id: 1,
          search_level: :project,
          use_traversal_id_queries: true
        }
      end

      it 'builds the correct object' do
        expect(result).to eq(expected_extracted_result)
      end
    end

    context 'when group search' do
      let(:extracted_result_path) { 'search_group_meta_project_id.json' }
      let_it_be(:group) { create(:group) }
      let(:large_project_id_1) { ::Search::Zoekt::Filters::MAX_32BIT_INTEGER + 1 }
      let(:large_project_id_2) { ::Search::Zoekt::Filters::MAX_32BIT_INTEGER + 2 }
      let(:large_project_id_3) { ::Search::Zoekt::Filters::MAX_32BIT_INTEGER + 3 }

      let(:options) do
        {
          features: 'repository',
          current_user: current_user,
          group_id: group.id,
          search_level: :group,
          use_traversal_id_queries: true
        }
      end

      before do
        guest_projects = class_double(
          ApplicationRecord,
          exists?: true,
          pluck_primary_key: [large_project_id_1, large_project_id_2, large_project_id_3]
        )
        allow(auth).to receive(:get_projects_for_user)
          .with(hash_including(search_level: :group, group_ids: [group.id]))
          .and_return(guest_projects)

        allow(auth).to receive(:get_traversal_ids_for_group)
          .with(group.id)
          .and_return("9970-")

        no_groups = class_double(ApplicationRecord, exists?: false)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::GUEST,
            group_ids: [group.id],
            project_ids: [],
            search_level: :group))
          .and_return(no_groups)

        reporter_groups = class_double(ApplicationRecord, exists?: true)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::REPORTER,
            group_ids: [group.id],
            project_ids: [],
            search_level: :group))
          .and_return(reporter_groups)

        allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
          .with(reporter_groups,
            group_ids: [group.id],
            project_ids: [],
            search_level: :group)
          .and_return(%w[9970-457- 9970-123-])

        no_projects = class_double(ApplicationRecord, exists?: false)
        allow(auth).to receive(:get_projects_with_custom_roles)
          .with(guest_projects)
          .and_return(no_projects)

        allow(auth).to receive(:get_groups_with_custom_roles)
          .with(no_groups)
          .and_return(no_groups)
      end

      it 'builds the correct object' do
        expect(result).to eq(expected_extracted_result)
      end

      context 'when traversal id search is disabled' do
        let(:extracted_result_path) { 'search_group_repo_ids.json' }
        let(:options) do
          {
            features: 'repository',
            current_user: current_user,
            group_id: group.id,
            use_traversal_id_queries: false,
            repo_ids: repo_ids
            # No search level needed when using repo ids
          }
        end

        context 'and repo ids are not provided' do
          let(:repo_ids) { nil }

          it 'raises an ArgumentError' do
            expect { result }.to raise_error(ArgumentError, 'Repo ids cannot be empty')
          end
        end

        context 'and repo ids are provided' do
          let(:repo_ids) { [1, 2, 3, 4, 5, 6] }

          it 'builds the correct object' do
            expect(result).to eq(expected_extracted_result)
          end
        end
      end
    end

    context 'when global search' do
      let(:extracted_result_path) { 'search_global_meta_project_id.json' }
      let(:large_project_id_1) { ::Search::Zoekt::Filters::MAX_32BIT_INTEGER + 1 }
      let(:large_project_id_2) { ::Search::Zoekt::Filters::MAX_32BIT_INTEGER + 2 }
      let(:large_project_id_3) { ::Search::Zoekt::Filters::MAX_32BIT_INTEGER + 3 }

      let(:options) do
        {
          features: 'repository',
          current_user: current_user,
          search_level: :global,
          use_traversal_id_queries: true
        }
      end

      before do
        guest_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [large_project_id_1])
        allow(auth).to receive(:get_projects_for_user)
          .with(
            hash_including(
              min_access_level: ::Gitlab::Access::GUEST,
              group_ids: [],
              project_ids: [],
              search_level: :global
            )
          ).and_return(guest_projects)

        reporter_projects = class_double(
          ApplicationRecord,
          exists?: true,
          pluck_primary_key: [large_project_id_2, large_project_id_3]
        )
        allow(auth).to receive(:get_projects_for_user)
          .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER, group_ids: [],
            project_ids: [], search_level: :global))
          .and_return(reporter_projects)

        guest_groups = class_double(ApplicationRecord, exists?: true)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::GUEST,
            group_ids: [],
            project_ids: [],
            search_level: :global))
          .and_return(guest_groups)

        reporter_groups = class_double(ApplicationRecord, exists?: true)
        allow(auth).to receive(:get_groups_for_user)
          .with(a_hash_including(min_access_level: ::Gitlab::Access::REPORTER,
            group_ids: [],
            project_ids: [],
            search_level: :global))
          .and_return(reporter_groups)

        allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
          .with(guest_groups,
            group_ids: [],
            project_ids: [],
            search_level: :global)
          .and_return(%w[2270-])

        allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
          .with(reporter_groups,
            group_ids: [],
            project_ids: [],
            search_level: :global)
          .and_return(%w[9970-457- 9970-123-])

        no_projects = class_double(ApplicationRecord, exists?: false)
        allow(auth).to receive(:get_projects_with_custom_roles)
          .with(guest_projects)
          .and_return(no_projects)

        no_groups = class_double(ApplicationRecord, exists?: false)
        allow(auth).to receive(:get_groups_with_custom_roles)
          .with(guest_groups)
          .and_return(no_groups)
      end

      it 'builds the correct object' do
        expect(result).to eq(expected_extracted_result)
      end
    end

    context 'when search_level is not recognized' do
      let(:options) do
        {
          features: 'repository',
          group_ids: [],
          project_id: 1,
          search_level: :unrecognized,
          use_traversal_id_queries: true
        }
      end

      it 'raises the exception' do
        expect { result }.to raise_error(
          ArgumentError, "Unsupported search level for zoekt search: #{options[:search_level]}"
        )
      end
    end

    context 'when project IDs exceed uint32' do
      let(:large_project_id) { ::Search::Zoekt::Filters::MAX_32BIT_INTEGER + 1 }
      let(:extracted_result_path) { 'search_project_meta_project_id.json' }

      let(:options) do
        {
          features: 'repository',
          group_ids: [],
          project_id: large_project_id,
          search_level: :project,
          use_traversal_id_queries: true
        }
      end

      it 'uses meta project_id filter' do
        project_filter = result[:and][:children].find do |child|
          child.dig(:_context, :name) == 'project_id_search'
        end

        expect(project_filter).to have_key(:meta)
        expect(project_filter[:meta][:key]).to eq('project_id')
      end
    end

    context 'when project ID is within uint32 range' do
      let(:extracted_result_path) { 'search_project.json' }
      let(:options) do
        {
          features: 'repository',
          group_ids: [],
          project_id: 1,
          search_level: :project,
          use_traversal_id_queries: true
        }
      end

      it 'uses repo_ids filter' do
        project_filter = result[:and][:children].find do |child|
          child.dig(:_context, :name) == 'project_id_search'
        end

        expect(project_filter).to have_key(:repo_ids)
        expect(project_filter[:repo_ids]).to eq([1])
      end
    end

    describe 'filter ordering' do
      # Placing meta filters (like archived) between query_string and scoping filters
      # (repo_ids/traversal_ids) causes significant performance regression.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/586416
      def filter_names(result)
        result.dig(:and, :children).map do |child|
          child.dig(:_context, :name) || child.each_key.first.to_s
        end
      end

      context 'for project search' do
        let(:options) do
          {
            features: 'repository',
            group_ids: [],
            project_id: 1,
            search_level: :project,
            filters: { exclude_forks: false },
            use_traversal_id_queries: true
          }
        end

        before do
          stub_feature_flags(zoekt_search_meta_project_ids: false)
        end

        it 'places scoping filter before archived filter' do
          expect(filter_names(result)).to eq(%w[query_string project_id_search meta access_branches])
        end
      end

      context 'for group search' do
        let_it_be(:group) { create(:group) }

        let(:options) do
          {
            features: 'repository',
            current_user: current_user,
            group_id: group.id,
            search_level: :group,
            filters: { exclude_forks: false },
            use_traversal_id_queries: true
          }
        end

        before do
          stub_feature_flags(zoekt_search_meta_project_ids: false)

          guest_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [1, 56, 99])
          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(search_level: :group, group_ids: [group.id]))
            .and_return(guest_projects)

          allow(auth).to receive(:get_traversal_ids_for_group)
            .with(group.id)
            .and_return("9970-")

          no_groups = class_double(ApplicationRecord, exists?: false)
          allow(auth).to receive(:get_groups_for_user)
            .with(a_hash_including(min_access_level: ::Gitlab::Access::GUEST,
              group_ids: [group.id],
              project_ids: [],
              search_level: :group))
            .and_return(no_groups)

          reporter_groups = class_double(ApplicationRecord, exists?: true)
          allow(auth).to receive(:get_groups_for_user)
            .with(a_hash_including(min_access_level: ::Gitlab::Access::REPORTER,
              group_ids: [group.id],
              project_ids: [],
              search_level: :group))
            .and_return(reporter_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(reporter_groups,
              group_ids: [group.id],
              project_ids: [],
              search_level: :group)
            .and_return(%w[9970-457- 9970-123-])

          no_projects = class_double(ApplicationRecord, exists?: false)
          allow(auth).to receive(:get_projects_with_custom_roles)
            .with(guest_projects)
            .and_return(no_projects)

          allow(auth).to receive(:get_groups_with_custom_roles)
            .with(no_groups)
            .and_return(no_groups)
        end

        it 'places scoping filter before archived filter' do
          expect(filter_names(result)).to eq(%w[query_string traversal_ids_for_group meta access_branches])
        end
      end
    end

    describe 'language filter (apply_language_filter)' do
      def query_string_from(payload)
        first_child = payload.dig(:and, :children).first
        first_child.dig(:query_string, :query)
      end

      let_it_be(:project) { create(:project) }

      let(:base_options) do
        {
          features: 'repository',
          current_user: current_user,
          project_id: project.id,
          search_level: :project,
          use_traversal_id_queries: true
        }
      end

      before do
        empty_relation = class_double(ApplicationRecord, exists?: false, pluck_primary_key: [])

        allow(auth).to receive_messages(
          get_groups_for_user: empty_relation,
          get_projects_for_user: empty_relation,
          get_groups_with_custom_roles: empty_relation,
          get_projects_with_custom_roles: empty_relation,
          get_formatted_traversal_ids_for_groups: [],
          get_traversal_ids_for_group: nil
        )
      end

      context 'when no language filter is set' do
        let(:options) { base_options.merge(filters: {}) }

        it 'does not append a lang: atom to the query' do
          expect(query_string_from(result)).not_to include('lang:')
        end
      end

      context 'when a single language is selected' do
        let(:options) { base_options.merge(filters: { language: ['Ruby'] }) }

        it 'appends the lang: atom bare (no parentheses)' do
          expect(query_string_from(result)).to end_with(' lang:Ruby')
        end
      end

      context 'when multiple languages are selected' do
        let(:options) { base_options.merge(filters: { language: %w[Ruby Go] }) }

        it 'appends the languages as an OR clause' do
          expect(query_string_from(result)).to end_with(' (lang:Ruby or lang:Go)')
        end
      end

      context 'when a language name contains a space' do
        let(:options) { base_options.merge(filters: { language: ['Objective C'] }) }

        it 'shell-quotes the language name' do
          expect(query_string_from(result)).to end_with(' lang:"Objective C"')
        end
      end

      context 'when the language array is empty or contains blank values' do
        let(:options) { base_options.merge(filters: { language: [nil, ''] }) }

        it 'does not append a lang: atom' do
          expect(query_string_from(result)).not_to include('lang:')
        end
      end

      context 'when a language name contains Zoekt-significant characters' do
        {
          'Ruby)' => ' lang:"Ruby)"',
          '(Ruby' => ' lang:"(Ruby"',
          'Ruby or lang:Foo' => ' lang:"Ruby or lang:Foo"',
          'Ruby"Go' => ' lang:"Ruby\\"Go"',
          'back\\slash' => ' lang:"back\\\\slash"'
        }.each do |input, expected_suffix|
          context "with input #{input.inspect}" do
            let(:options) { base_options.merge(filters: { language: [input] }) }

            it 'quotes and escapes the value so it cannot break out of the lang: atom' do
              expect(query_string_from(result)).to end_with(expected_suffix)
            end
          end
        end
      end

      context 'when the zoekt_language_aggregations feature flag is disabled' do
        before do
          stub_feature_flags(zoekt_language_aggregations: false)
        end

        let(:options) { base_options.merge(filters: { language: ['Ruby'] }) }

        it 'does not apply the language filter even if present' do
          expect(query_string_from(result)).not_to include('lang:')
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::SearchResults, :zoekt_cache_disabled, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group_1) { create(:group) }
  let_it_be(:group_2) { create(:group) }
  let_it_be(:project_1) { create(:project, :public, :repository, group: group_1) }
  let_it_be(:project_2) { create(:project, :public, :repository, group: group_2) }

  let(:query) { 'hello world' }
  let(:limit_projects) { nil }
  let(:node_id) { ::Search::Zoekt::Node.last.id }
  let(:filters) { {} }
  let(:source) { :api }
  let(:results) { described_class.new(user, query, nil, **params) }

  let(:params) do
    {
      node_id: node_id,
      filters: filters,
      source: source,
      modes: { regex: true }
    }
  end

  # Ensure offset pagination is off by default across the whole spec so that
  # Rails.cache pollution from other spec files doesn't silently change
  # max_file_match_results / file_match_offset for tests that expect standard
  # (non-offset) Zoekt behaviour. The 'when offset pagination is active'
  # context re-stubs this to true.
  before do
    allow(Search::Zoekt::OffsetPagination).to receive(:active?).and_return(false)
  end

  before_all do
    zoekt_ensure_project_indexed!(project_1)
    zoekt_ensure_project_indexed!(project_2)
  end

  describe '#initialize' do
    context 'when options has search_level' do
      it 'raises an error' do
        expect { described_class.new(nil, 'test', nil, search_level: :project) }
          .to raise_error('Specifying search level is not supported. Pass group_id or project_id instead.')
      end
    end
  end

  describe '#objects' do
    using RSpec::Parameterized::TableSyntax
    let(:query) { 'use.*egex' }

    subject(:objects) { results.objects('blobs') }

    # These three tests use deterministic stubs instead of live Zoekt results to prevent
    # order-dependent failures: other spec files (e.g. node_spec.rb) create extra
    # for_search.online nodes that change search counts when tests share the same process.
    context 'with stubbed Zoekt client' do
      # 10 line-matches across 4 files, matching real Zoekt data for query 'use.*egex'
      let(:line_match_username_regex) do
        {
          LineNumber: 5,
          Line: Base64.strict_encode64("def username_regex\n      default_regex"),
          LineFragments: [{ LineOffset: 0, MatchLength: 10 }]
        }
      end

      let(:line_match_regexp_group) do
        {
          LineNumber: 12,
          Line: Base64.strict_encode64("regexp group matches\n  (`$1`, `$2`, etc)"),
          LineFragments: [{ LineOffset: 0, MatchLength: 6 }]
        }
      end

      let(:stub_files) do
        [
          {
            RepositoryID: project_1.id.to_s,
            FileName: 'lib/gitlab/regex.rb',
            LineMatches: [
              line_match_username_regex,
              { LineNumber: 6, Line: Base64.strict_encode64('regex_match_a'), LineFragments: [] },
              { LineNumber: 7, Line: Base64.strict_encode64('regex_match_b'), LineFragments: [] }
            ]
          },
          {
            RepositoryID: project_1.id.to_s,
            FileName: 'doc/development/regex.md',
            LineMatches: [
              line_match_regexp_group,
              { LineNumber: 13, Line: Base64.strict_encode64('regex_match_c'), LineFragments: [] },
              { LineNumber: 14, Line: Base64.strict_encode64('regex_match_d'), LineFragments: [] }
            ]
          },
          {
            RepositoryID: project_2.id.to_s,
            FileName: 'app/validators/regex_validator.rb',
            LineMatches: [
              { LineNumber: 1, Line: Base64.strict_encode64('regex_match_e'), LineFragments: [] },
              { LineNumber: 2, Line: Base64.strict_encode64('regex_match_f'), LineFragments: [] }
            ]
          },
          {
            RepositoryID: project_2.id.to_s,
            FileName: 'spec/regex_spec.rb',
            LineMatches: [
              { LineNumber: 10, Line: Base64.strict_encode64('regex_match_g'), LineFragments: [] },
              { LineNumber: 11, Line: Base64.strict_encode64('regex_match_h'), LineFragments: [] }
            ]
          }
        ]
      end

      before do
        mock_response = instance_double(
          ::Gitlab::Search::Zoekt::Response,
          failure?: false,
          match_count: 10,
          file_count: 4
        )
        allow(mock_response).to receive(:each_file) do |&block|
          stub_files.each { |file| block.call(file) }
        end
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_return(mock_response)
      end

      it 'finds blobs by regex search' do
        expect(objects.map(&:data).join).to include("def username_regex\n      default_regex")
        expect(results.blobs_count).to eq 10
      end

      it 'sets file_count on the instance equal to the count of files with matches' do
        objects
        expect(results).to have_attributes(file_count: 4)
      end

      it 'correctly handles pagination' do
        per_page = 2

        blobs_page1 = results.objects('blobs', page: 1, per_page: per_page)
        blobs_page2 = results.objects('blobs', page: 2, per_page: per_page)

        expect(blobs_page1.map(&:data).join).to include("def username_regex\n      default_regex")
        expect(blobs_page2.map(&:data).join).to include("regexp group matches\n  (`$1`, `$2`, etc)")
        expect(results.blobs_count).to eq 10
      end
    end

    describe 'caching' do
      context 'when source is :api' do
        it 'instantiates zoekt cache with correct arguments' do
          expect(Search::Zoekt::Cache).to receive(:new).with(
            query,
            current_user: user,
            page: 1,
            per_page: described_class::DEFAULT_PER_PAGE,
            max_per_page: described_class::DEFAULT_PER_PAGE * 2,
            project_id: nil,
            group_id: nil,
            search_mode: :regex,
            chunk_size: nil,
            filters: {},
            count_only: false
          ).and_call_original

          objects
        end
      end

      context 'when source is not :api' do
        let(:source) { nil }

        it 'instantiates zoekt cache with correct arguments' do
          expect(Search::Zoekt::Cache).to receive(:new).with(
            query,
            current_user: user,
            page: 1,
            per_page: described_class::DEFAULT_PER_PAGE,
            max_per_page: described_class::DEFAULT_PER_PAGE * 2,
            project_id: nil,
            group_id: nil,
            search_mode: :regex,
            chunk_size: 3,
            filters: { exclude_forks: false },
            count_only: false
          ).and_call_original

          objects
        end
      end
    end

    it 'returns empty result when request is out of page range' do
      blobs_page = results.objects('blobs', page: 256, per_page: 2)

      expect(blobs_page).to be_empty
    end

    context 'when offset pagination is active' do
      let(:per_page) { described_class::DEFAULT_PER_PAGE }
      let(:max_pages) { ::Search::Zoekt::Cache::MAX_PAGES }

      # Stub the client so these specs test our Rails-side logic only, not real Zoekt.
      # Hitting real Zoekt with offset payloads can affect subsequent tests that share
      # the same indexed data and expect specific result counts.
      let(:page1_results) do
        { 0 => [{ project_id: project_1.id, path: 'file_a.rb', content: 'a', line: 1 }] }
      end

      let(:deep_page_results) do
        { 0 => [{ project_id: project_1.id, path: 'file_b.rb', content: 'b', line: 1 }] }
      end

      before do
        allow(Search::Zoekt::OffsetPagination).to receive(:active?).and_return(true)
      end

      it 'returns results for a deep page without returning page 1 results' do
        call_count = 0
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search) do
          call_count += 1
          results_data = call_count == 1 ? page1_results : deep_page_results
          instance_double(
            ::Gitlab::Search::Zoekt::Response,
            success?: true,
            failure?: false,
            error_message: nil,
            file_count: 1,
            match_count: 1,
            each_file: nil
          ).tap do |r|
            allow(r).to receive(:each_page).and_yield(results_data)
          end
        end

        # Verify the payload sent for page 1 vs deep page via Params
        params_p1   = ::Search::Zoekt::Params.new(limit: per_page, page: 1, per_page: per_page)
        params_deep = ::Search::Zoekt::Params.new(limit: per_page, page: max_pages + 1, per_page: per_page)

        expect(params_p1.file_match_offset).to eq(0)
        expect(params_p1.max_file_match_results).to eq(max_pages * per_page)
        expect(params_deep.file_match_offset).to eq(max_pages * per_page)
        expect(params_deep.max_file_match_results).to eq(per_page)
      end

      it 'does not write to cache when requesting a deep page' do
        cache_double = instance_double(::Search::Zoekt::Cache)
        allow(::Search::Zoekt::Cache).to receive(:new).and_return(cache_double)

        # Cache bypasses itself for deep pages - yields directly with page_limit=page
        allow(cache_double).to receive(:fetch).and_yield(max_pages + 1)

        expect(cache_double).not_to receive(:update_cache!)

        results.objects('blobs', page: max_pages + 1, per_page: per_page)
      end
    end

    describe 'regex mode' do
      where(:param_regex_mode, :source, :search_mode_sent_to_client) do
        nil     | :api  | :regex
        nil     | :web  | :exact
        true    | :api  | :regex
        true    | :web  | :regex
        false   | :api  | :exact
        false   | :web  | :exact
        'true'  | :api  | :regex
        'true'  | :web  | :regex
        'false' | :api  | :exact
        'false' | :web  | :exact
      end

      with_them do
        it 'calls search on Gitlab::Search::Zoekt::Client with correct parameters' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            hash_including(
              num: described_class::ZOEKT_COUNT_LIMIT,
              node_id: node_id,
              search_mode: search_mode_sent_to_client,
              source: source)
          ).and_call_original

          described_class.new(user, query, limit_projects, group_id: group_1.id, node_id: node_id, source: source,
            modes: { regex: param_regex_mode }).objects('blobs')
        end

        context 'when a node id is not specified' do
          context 'and traversal ids feature is unavailable' do
            let(:limit_projects) { ::Project.id_in([project_1.id]) }

            before do
              stub_zoekt_features(traversal_id_search: false)
            end

            it 'calls search on Gitlab::Search::Zoekt::Client with correct parameters' do
              expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
                query,
                hash_including(
                  num: described_class::ZOEKT_COUNT_LIMIT,
                  search_mode: search_mode_sent_to_client,
                  targets: ::Search::Zoekt::RoutingService.execute(limit_projects),
                  source: source
                )
              ).and_call_original

              described_class.new(user, query, limit_projects, group_id: group_1.id, source: source,
                modes: { regex: param_regex_mode }).objects('blobs')
            end
          end

          it 'calls search on Gitlab::Search::Zoekt::Client with correct parameters' do
            expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
              query,
              hash_including(
                num: described_class::ZOEKT_COUNT_LIMIT,
                search_mode: search_mode_sent_to_client,
                targets: nil,
                source: source
              )
            ).and_call_original

            described_class.new(user, query, limit_projects, group_id: group_1.id, source: source,
              modes: { regex: param_regex_mode }).objects('blobs')
          end
        end
      end

      context 'when modes is not passed' do
        it 'calls search on Gitlab::Search::Zoekt::Client with correct parameters' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            hash_including(
              num: described_class::ZOEKT_COUNT_LIMIT,
              node_id: node_id,
              search_mode: :exact,
              source: nil
            )
          ).and_call_original
          described_class.new(user, query, limit_projects, group_id: group_1.id, node_id: node_id,
            source: nil).objects('blobs')
        end
      end
    end

    context 'when searching with special characters', :aggregate_failures do
      let_it_be(:examples) do
        {
          'perlMethodCall' => '$my_perl_object->perlMethodCall',
          '"absolute_with_specials.txt"' => '/a/longer/file-path/absolute_with_specials.txt',
          '"components-within-slashes"' => '/file-path/components-within-slashes/',
          'bar\(x\)' => 'Foo.bar(x)',
          'someSingleColonMethodCall' => 'LanguageWithSingleColon:someSingleColonMethodCall',
          'javaLangStaticMethodCall' => 'MyJavaClass::javaLangStaticMethodCall',
          'tokenAfterParentheses' => 'ParenthesesBetweenTokens)tokenAfterParentheses',
          'ruby_call_method_123' => 'RubyClassInvoking.ruby_call_method_123(with_arg)',
          'ruby_method_call' => 'RubyClassInvoking.ruby_method_call(with_arg)',
          '#ambitious-planning' => 'We [plan ambitiously](#ambitious-planning).',
          'ambitious-planning' => 'We [plan ambitiously](#ambitious-planning).',
          'tokenAfterCommaWithNoSpace' => 'WouldHappenInManyLanguages,tokenAfterCommaWithNoSpace',
          'missing_token_around_equals' => 'a.b.c=missing_token_around_equals',
          'and;colons:too\$' => 'and;colons:too$',
          '"differeñt-lønguage.txt"' => 'another/file-path/differeñt-lønguage.txt',
          '"relative-with-specials.txt"' => 'another/file-path/relative-with-specials.txt',
          'ruby_method_123' => 'def self.ruby_method_123(ruby_another_method_arg)',
          'ruby_method_name' => 'def self.ruby_method_name(ruby_method_arg)',
          '"dots.also.neeeeed.testing"' => 'dots.also.neeeeed.testing',
          '.testing' => 'dots.also.neeeeed.testing',
          'dots' => 'dots.also.neeeeed.testing',
          'also.neeeeed' => 'dots.also.neeeeed.testing',
          'neeeeed' => 'dots.also.neeeeed.testing',
          'tests-image' => 'extends: .gitlab-tests-image',
          'gitlab-tests' => 'extends: .gitlab-tests-image',
          'gitlab-tests-image' => 'extends: .gitlab-tests-image',
          'foo/bar' => 'https://s3.amazonaws.com/foo/bar/baz.png',
          'https://test.or.dev.com/repository' => 'https://test.or.dev.com/repository/maven-all',
          'test.or.dev.com/repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
          'repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
          'https://test.or.dev.com/repository/maven-all' => 'https://test.or.dev.com/repository/maven-all',
          'bar-baz-conventions' => 'id("foo.bar-baz-conventions")',
          'baz-conventions' => 'id("foo.bar-baz-conventions")',
          'baz' => 'id("foo.bar-baz-conventions")',
          'bikes-3.4' => 'include "bikes-3.4"',
          'sql_log_bin' => 'q = "SET @@session.sql_log_bin=0;"',
          'sql_log_bin=0' => 'q = "SET @@session.sql_log_bin=0;"',
          'v3/delData' => 'uri: "v3/delData"',
          '"us-east-2"' => 'us-east-2'
        }
      end

      before_all do
        examples.values.uniq.each do |file_content|
          file_name = Digest::SHA256.hexdigest(file_content)
          project_1.repository.create_file(user, file_name, file_content, message: 'Some commit message',
            branch_name: 'master')
        end

        zoekt_ensure_project_indexed!(project_1)
      end

      [:api, nil].each do |source|
        context "when source is #{source}" do
          it 'finds all examples' do
            examples.each do |search_term, file_content|
              file_name = Digest::SHA256.hexdigest(file_content)

              search_results_instance = described_class.new(
                user,
                search_term,
                limit_projects,
                group_id: group_1.id,
                node_id: node_id,
                modes: { regex: true },
                source: source
              )

              results = search_results_instance.objects('blobs').map(&:path)
              expect(results).to include(file_name)
            end
          end
        end
      end
    end

    context 'when source is not :api' do
      let(:source) { nil }

      it 'returns just one blob of kind Search::FoundMultiLineBlob' do
        expect(results.objects('blobs', per_page: 1)).to contain_exactly(a_kind_of(Search::FoundMultiLineBlob))
      end

      context 'when projects are deleted' do
        let(:limit_projects) { Project.where(id: [project_1.id, project_2.id]) }

        it 'removes the results from the deleted projects' do
          project_2.destroy!
          results_project_paths = results.objects.map(&:project_path).uniq
          expect(results_project_paths).to contain_exactly(project_1.full_path)
        end
      end
    end

    describe 'filtering' do
      include ProjectForksHelper

      let_it_be(:archived_project) { create(:project, :public, :archived, :repository) }
      let!(:forked_project) { fork_project(project_1) }
      let(:filters) { {} }
      let(:normalized_filters) { filters.merge(exclude_forks: filters[:exclude_forks] || false) }

      subject(:search) do
        described_class.new(user, query, limit_projects, group_id: group_1.id, node_id: node_id,
          filters: filters).objects('blobs')
      end

      shared_examples 'a non-filtered search' do
        it 'calls search on Gitlab::Search::Zoekt::Client with all project ids' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            hash_including(
              num: described_class::ZOEKT_COUNT_LIMIT,
              node_id: node_id,
              search_mode: :exact,
              filters: normalized_filters
            )
          ).and_call_original

          search
        end
      end

      context 'without N+1 queries' do
        it 'does not have N+1 queries for projects' do
          projects = [project_1, project_2]

          collection = ::Project.id_in(projects.map(&:id))

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            described_class.new(user, query, collection, group_id: group_1.id, node_id: node_id,
              filters: filters).objects('blobs')
          end

          projects << create(:project, group: create(:group))
          projects << create(:project, :mirror)

          collection = ::Project.id_in(projects.map(&:id))

          expect do
            described_class.new(user, query, collection, group_id: group_1.id, node_id: node_id,
              filters: filters).objects('blobs')
          end.not_to issue_same_number_of_queries_as(control)
        end
      end

      context 'when no filters are passed' do
        it 'calls search on Gitlab::Search::Zoekt::Client with non archived project ids' do
          expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
            query,
            hash_including(
              num: described_class::ZOEKT_COUNT_LIMIT,
              node_id: node_id,
              search_mode: :exact
            )
          ).and_call_original

          search
        end
      end

      describe 'archive filters' do
        context 'when include_archived filter is set to true' do
          let(:filters) { { include_archived: true } }

          it_behaves_like 'a non-filtered search'
        end

        context 'when include_archived filter is set to false' do
          let(:filters) { { include_archived: false } }

          it 'calls search on Gitlab::Search::Zoekt::Client with correct filter' do
            expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
              query,
              hash_including(
                num: described_class::ZOEKT_COUNT_LIMIT,
                search_mode: :exact,
                filters: normalized_filters
              )
            ).and_call_original

            search
          end

          context 'and all projects are archived' do
            before do
              Project.update_all(archived: true)
            end

            it 'returns an empty result set' do
              expect(search).to be_empty
            end
          end
        end
      end

      describe 'fork filters' do
        using RSpec::Parameterized::TableSyntax

        # Web callers omit the param when the box is unchecked, so nil means "include forks".
        # The API keeps nil meaning "exclude forks", which is its documented contract.
        where(:source, :exclude_forks, :expected) do
          nil   | nil   | false
          nil   | true  | true
          nil   | false | false
          'api' | nil   | nil
          'api' | true  | true
          'api' | false | false
        end

        with_them do
          let(:filters) { { exclude_forks: exclude_forks } }

          it 'passes the resolved exclude_forks to Zoekt' do
            expect(Gitlab::Search::Zoekt::Client).to receive(:search).with(
              query, hash_including(filters: { exclude_forks: expected })
            ).and_call_original

            described_class.new(user, query, limit_projects, group_id: group_1.id,
              node_id: node_id, source: source, filters: filters).objects('blobs')
          end
        end
      end
    end

    context 'when search_level is project and node_id is nil' do
      let(:logger) { instance_double(Search::Zoekt::Logger) }
      let(:results) { described_class.new(user, query, limit_projects, project_id: project_1.id) }

      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
      end

      context 'when project is empty_repo' do
        let_it_be(:project_1) { create(:project, :public, :empty_repo) }

        it 'returns empty results, does not log and does not index' do
          expect(logger).not_to receive(:info).with({
            'class' => described_class.to_s, 'query' => query, 'project_id' => project_1.id,
            'message' => 'zoekt repository is not found for this search'
          })
          expect(Search::Zoekt).not_to receive(:index_async).with(project_1.id)
          expect(objects).to eq []
          expect(results).to have_attributes(file_count: 0)
        end
      end

      context 'when project is non empty_repo' do
        it 'returns empty results, logs and index the project' do
          expect(logger).to receive(:info).with({
            'class' => described_class.to_s, 'query' => query, 'project_id' => project_1.id,
            'message' => 'zoekt repository is not found for this search'
          })
          expect(Search::Zoekt).to receive(:index_async).with(project_1.id)
          expect(objects).to eq []
          expect(results).to have_attributes(file_count: 0)
        end
      end
    end

    context 'when LineMatches in zoekt response is nil' do
      let(:logger) { instance_double(Search::Zoekt::Logger) }
      let(:file_with_nil_matches) do
        { RepositoryID: project_1.id.to_s, FileName: 'test.rb', LineMatches: nil }
      end

      let(:mock_response) do
        instance_double(
          ::Gitlab::Search::Zoekt::Response,
          match_count: 1,
          file_count: 1,
          failure?: false,
          parsed_response: {}
        )
      end

      before do
        allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
        allow(mock_response).to receive(:each_file).and_yield(file_with_nil_matches)
        allow(Gitlab::Search::Zoekt::Client).to receive(:search).and_return(mock_response)
      end

      it 'raises exception and logs error' do
        expect(logger).to receive(:error).with(
          hash_including(
            'class' => described_class.to_s,
            'message' => 'LineMatches is missing',
            'error' => mock_response.parsed_response[:Error],
            'failures' => mock_response.parsed_response[:Failures],
            'timed_out' => mock_response.parsed_response[:TimedOut],
            'file' => file_with_nil_matches
          )
        )
        expect { objects }.to raise_error(NoMethodError)
      end
    end

    context 'when Zoekt response uses Repository field instead of RepositoryID' do
      let(:file_with_repository_field) do
        {
          Repository: project_1.id.to_s,
          FileName: 'test.rb',
          LineMatches: [
            {
              LineNumber: 1,
              Line: Base64.encode64('test content'),
              LineFragments: [{ LineOffset: 0, MatchLength: 4 }]
            }
          ]
        }
      end

      let(:mock_response) do
        instance_double(
          ::Gitlab::Search::Zoekt::Response,
          match_count: 1,
          file_count: 1,
          failure?: false,
          parsed_response: {}
        )
      end

      before do
        allow(mock_response).to receive(:each_file).and_yield(file_with_repository_field)
        allow(Gitlab::Search::Zoekt::Client).to receive(:search).and_return(mock_response)
      end

      it 'extracts project_id from Repository field' do
        blobs = objects
        expect(blobs).not_to be_empty
        expect(blobs.first.project_id).to eq(project_1.id)
      end
    end

    context 'when Zoekt response has RepositoryID as zero and Repository field present' do
      let(:file_with_zero_repository_id) do
        {
          RepositoryID: '0',
          Repository: project_2.id.to_s,
          FileName: 'large_id_test.rb',
          LineMatches: [
            {
              LineNumber: 5,
              Line: Base64.encode64('large project id test'),
              LineFragments: [{ LineOffset: 0, MatchLength: 5 }]
            }
          ]
        }
      end

      let(:mock_response) do
        instance_double(
          ::Gitlab::Search::Zoekt::Response,
          match_count: 1,
          file_count: 1,
          failure?: false,
          parsed_response: {}
        )
      end

      before do
        allow(mock_response).to receive(:each_file).and_yield(file_with_zero_repository_id)
        allow(Gitlab::Search::Zoekt::Client).to receive(:search).and_return(mock_response)
      end

      it 'falls back to Repository field when RepositoryID is zero' do
        blobs = objects
        expect(blobs).not_to be_empty
        expect(blobs.first.project_id).to eq(project_2.id)
      end
    end

    context 'when Zoekt response has valid RepositoryID' do
      let(:file_with_repository_id) do
        {
          RepositoryID: project_1.id.to_s,
          Repository: '999999',
          FileName: 'legacy_format.rb',
          LineMatches: [
            {
              LineNumber: 10,
              Line: Base64.encode64('legacy format test'),
              LineFragments: [{ LineOffset: 0, MatchLength: 6 }]
            }
          ]
        }
      end

      let(:mock_response) do
        instance_double(
          ::Gitlab::Search::Zoekt::Response,
          match_count: 1,
          file_count: 1,
          failure?: false,
          parsed_response: {}
        )
      end

      before do
        allow(mock_response).to receive(:each_file).and_yield(file_with_repository_id)
        allow(Gitlab::Search::Zoekt::Client).to receive(:search).and_return(mock_response)
      end

      it 'prefers RepositoryID over Repository field' do
        blobs = objects
        expect(blobs).not_to be_empty
        expect(blobs.first.project_id).to eq(project_1.id)
      end
    end

    context 'when error is raised by client' do
      it 'returns zero when error is raised by client' do
        client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)
        expect(objects).to be_empty
        expect(results.error).to eq(client_error.message)
        expect(results.error_type).to eq(Search::Zoekt::Errors::ClientConnectionError)
      end
    end
  end

  describe '#blobs_count' do
    using RSpec::Parameterized::TableSyntax

    where(:query, :source, :regex_mode, :expected_count, :expected_file_count) do
      'use.*egex' | nil   | false | 0   | 0
      'use.*egex' | nil   | true  | 5   | 2
      'use.*egex' | :api  | false | 0   | 0
      'use.*egex' | :api  | true  | 5   | 2
      'asdfg'     | nil   | false | 0   | 0
      'asdfg'     | nil   | true  | 0   | 0
      'asdfg'     | :api  | false | 0   | 0
      'asdfg'     | :api  | true  | 0   | 0
      '# good'    | nil   | false | 134 | 1
      '# good'    | nil   | true  | 564 | 3
      '# good'    | :api  | false | 134 | 1
      '# good'    | :api  | true  | 564 | 3
    end

    with_them do
      let(:results) do
        described_class.new(user,
          query,
          limit_projects,
          project_id: project_1.id,
          node_id: node_id,
          source: source,
          modes: { regex: regex_mode }
        )
      end

      subject(:blobs_count) { results.blobs_count }

      it 'returns the expected match count and file count' do
        results.objects('blobs')
        expect(blobs_count).to eq(expected_count)
        expect(results.file_count).to eq(expected_file_count)
      end

      context 'when error is raised by client' do
        it 'returns zero when error is raised by client' do
          client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
          allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)

          expect(blobs_count).to eq 0
          expect(results.error).to eq(client_error.message)
          expect(results.error_type).to eq(Search::Zoekt::Errors::ClientConnectionError)
        end
      end

      it 'limits to the zoekt count limit' do
        stub_const("#{described_class}::ZOEKT_COUNT_LIMIT", 2)

        limited_count = [2, expected_count].min
        expect(blobs_count).to eq(limited_count)
      end
    end

    it 'does not call zoekt_extract_result_pages_multi_match' do
      # Stub the client to avoid depending on live Zoekt result counts, which vary
      # based on which other nodes/projects exist in the DB at test time.
      mock_response = instance_double(
        ::Gitlab::Search::Zoekt::Response,
        failure?: false,
        match_count: 2,
        file_count: 1
      )
      allow(mock_response).to receive(:each_file)
      allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_return(mock_response)

      expect_next_instance_of(Search::Zoekt::MultiMatch) do |instance|
        expect(instance).not_to receive(:zoekt_extract_result_pages_multi_match)
      end

      count = described_class.new(user, 'hello', limit_projects, source: :web).blobs_count
      expect(count).to eq 2
    end
  end

  describe '#failed?' do
    let(:scope) { 'blobs' }

    subject(:results) { described_class.new(user, 'test', limit_projects, group_id: group_1.id, node_id: node_id) }

    context 'when no error raised by client' do
      it 'returns false' do
        results.objects(scope)
        expect(results.failed?(scope)).to be false
      end
    end

    context 'when error raised by client' do
      before do
        client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)
      end

      it 'returns true' do
        results.objects(scope)
        expect(results.failed?(scope)).to be true
      end
    end
  end

  describe '#error' do
    let(:scope) { 'blobs' }

    subject(:results) { described_class.new(user, 'test', limit_projects, group_id: group_1.id, node_id: node_id) }

    context 'when no error raised by client' do
      it 'returns nil' do
        results.objects(scope)
        expect(results.error(scope)).to be_nil
      end
    end

    context 'when error raised by client' do
      before do
        client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)
      end

      it 'returns the error message' do
        results.objects(scope)
        expect(results.error(scope)).to eq('test')
      end
    end
  end

  describe '#server_error?' do
    let(:scope) { 'blobs' }

    subject(:results) { described_class.new(user, 'test', limit_projects, group_id: group_1.id, node_id: node_id) }

    context 'when is_server_error present' do
      before do
        client_error = ::Search::Zoekt::Errors::ClientConnectionError.new('test')
        allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_raise(client_error)
      end

      it 'returns true' do
        results.objects(scope)
        expect(results.server_error?).to be true
      end
    end

    context 'when no error raised by client' do
      it 'returns nil' do
        results.objects(scope)
        expect(results.server_error?).to be false
      end
    end
  end

  describe '#aggregations' do
    let(:zoekt_response) do
      instance_double(::Gitlab::Search::Zoekt::Response,
        failure?: false,
        match_count: 42,
        file_count: 3,
        parsed_response: { Result: { Files: [] } }
      ).tap { |r| allow(r).to receive(:each_file) }
    end

    let(:aggregation_cache) do
      instance_double(::Search::Zoekt::AggregationCache, read: nil, write: nil)
    end

    before do
      allow(::Search::Zoekt::AggregationCache).to receive(:new).and_return(aggregation_cache)
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_language_aggregations: false)
      end

      it 'returns an empty array' do
        expect(results.aggregations('blobs')).to eq([])
      end
    end

    context 'when the scope is not blobs' do
      it 'returns an empty array' do
        expect(results.aggregations('issues')).to eq([])
      end
    end

    context 'when the aggregation cache has data' do
      let(:cached_tally) { { 'Ruby' => 42, 'JavaScript' => 10 } }

      before do
        allow(aggregation_cache).to receive(:read).and_return(cached_tally)
      end

      it 'returns a language aggregation with buckets sorted by count desc' do
        aggs = results.aggregations('blobs')

        expect(aggs.size).to eq(1)
        expect(aggs.first.name).to eq('language')
        expect(aggs.first.buckets).to eq([{ key: 'Ruby', count: 42 }, { key: 'JavaScript', count: 10 }])
      end

      it 'does not issue any Zoekt call' do
        expect(::Gitlab::Search::Zoekt::Client).not_to receive(:search)
        results.aggregations('blobs')
      end
    end

    context 'when the aggregation cache is empty' do
      before do
        allow(aggregation_cache).to receive(:read).and_return(nil)
      end

      shared_examples 'defers without issuing a Zoekt call' do
        it 'returns an empty array and does not issue a Zoekt call' do
          expect(::Gitlab::Search::Zoekt::Client).not_to receive(:search)

          expect(results.aggregations('blobs')).to eq([])
        end
      end

      shared_examples 'issues a dedicated aggregation-mode Zoekt call' do
        before do
          allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_return(zoekt_response)
        end

        it 'strips the language filter and enables aggregation_mode' do
          expect(::Gitlab::Search::Zoekt::Client).to receive(:search) do |_query, options|
            expect(options).to include(
              filters: hash_not_including(:language),
              aggregation_mode: true
            )
            zoekt_response
          end

          results.aggregations('blobs')
        end

        it 'writes the tally to the aggregation cache' do
          allow(zoekt_response).to receive(:each_file).and_yield(
            { Language: 'Ruby', LineMatches: [{ LineNumber: 1, LineFragments: [{}] }] }
          )
          expect(aggregation_cache).to receive(:write).with({ 'Ruby' => 1 })

          results.aggregations('blobs')
        end
      end

      context 'when no language filter is active' do
        context 'and :language is missing from filters' do
          let(:filters) { {} }

          it_behaves_like 'issues a dedicated aggregation-mode Zoekt call'
        end

        context 'and :language is nil' do
          let(:filters) { { language: nil } }

          it_behaves_like 'issues a dedicated aggregation-mode Zoekt call'
        end

        context 'and :language is an empty array' do
          let(:filters) { { language: [] } }

          it_behaves_like 'issues a dedicated aggregation-mode Zoekt call'
        end

        context 'and :language is an array of blanks' do
          let(:filters) { { language: [nil, ''] } }

          it_behaves_like 'issues a dedicated aggregation-mode Zoekt call'
        end
      end

      context 'when a language filter is active' do
        let(:filters) { { language: ['Ruby'] } }

        it_behaves_like 'issues a dedicated aggregation-mode Zoekt call'
      end
    end
  end

  describe 'display query does not warm the aggregation cache' do
    let(:response) do
      instance_double(::Gitlab::Search::Zoekt::Response,
        failure?: false,
        match_count: 10,
        file_count: 1,
        parsed_response: { Result: { Files: [] } }
      ).tap do |r|
        allow(r).to receive(:each_file).and_yield(
          { Language: 'Ruby', LineMatches: [{ LineNumber: 1, LineFragments: [{}] }] }
        )
      end
    end

    let(:aggregation_cache) do
      instance_double(::Search::Zoekt::AggregationCache, read: nil, write: nil)
    end

    before do
      allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_return(response)
      allow(::Search::Zoekt::AggregationCache).to receive(:new).and_return(aggregation_cache)
    end

    # Regression coverage: the display query caps LineMatches per file, so any tally derived from it
    # would undercount files that exceed the cap. Cache writes must only happen through the dedicated
    # aggregation-mode call in #aggregations.
    it 'never writes to the aggregation cache during a results fetch' do
      expect(aggregation_cache).not_to receive(:write)

      results.objects('blobs')
    end
  end

  describe 'language tally computation (observed via #aggregations)' do
    subject(:results) { described_class.new(user, 'test', limit_projects, group_id: group_1.id, node_id: node_id) }

    let(:file_ruby) do
      {
        Language: 'Ruby', LineMatches: [{ LineNumber: 1, LineFragments: [{}] }, { LineNumber: 2, LineFragments: [{}] }]
      }
    end

    let(:file_js) do
      {
        Language: 'JavaScript', LineMatches: [{ LineNumber: 3, LineFragments: [{}] }]
      }
    end

    let(:file_no_language) do
      {
        Language: nil, LineMatches: [{ LineNumber: 1, LineFragments: [{}] }]
      }
    end

    let(:file_only_path_match) do
      {
        Language: 'Ruby', LineMatches: [{ FileName: true }]
      }
    end

    let(:response) do
      instance_double(::Gitlab::Search::Zoekt::Response,
        failure?: false,
        match_count: 4,
        file_count: 4,
        parsed_response: { Result: { Files: [] } }
      ).tap do |r|
        allow(r).to receive(:each_file).and_yield(file_ruby)
                                       .and_yield(file_js)
                                       .and_yield(file_no_language)
                                       .and_yield(file_only_path_match)
      end
    end

    let(:aggregation_cache) do
      instance_double(::Search::Zoekt::AggregationCache, read: nil, write: nil)
    end

    before do
      allow(::Gitlab::Search::Zoekt::Client).to receive(:search).and_return(response)
      allow(::Search::Zoekt::AggregationCache).to receive(:new).and_return(aggregation_cache)
    end

    it 'attributes every match (content and filename) to the file language, skipping files with no language' do
      # Ruby: 2 content-line matches from file_ruby + 1 filename match from
      #       file_only_path_match = 3.
      # JavaScript: 1 content-line match.
      # file_no_language is skipped so its match does not appear in any bucket.
      # Buckets sum to 4, matching response.match_count.
      expect(aggregation_cache).to receive(:write) do |tally|
        expect(tally).to eq('Ruby' => 3, 'JavaScript' => 1)
        expect(tally).not_to have_key(nil)
        expect(tally).not_to have_key('')
      end

      results.aggregations('blobs')
    end

    context 'when a file has more matches than the display-query per-file cap' do
      let(:per_file_cap) do
        ::Search::Zoekt::MultiMatch::MAX_CHUNKS_PER_FILE * ::Search::Zoekt::Params::LINE_MATCHES_FACTOR
      end

      let(:untruncated_match_count) { per_file_cap + 42 }

      let(:file_ruby_over_cap) do
        {
          Language: 'Ruby',
          LineMatches: Array.new(untruncated_match_count) { |i| { LineNumber: i + 1, LineFragments: [{}] } }
        }
      end

      let(:response) do
        instance_double(::Gitlab::Search::Zoekt::Response,
          failure?: false,
          match_count: untruncated_match_count,
          file_count: 1,
          parsed_response: { Result: { Files: [] } }
        ).tap { |r| allow(r).to receive(:each_file).and_yield(file_ruby_over_cap) }
      end

      # Regression coverage for the display-query truncation bug: the aggregation Zoekt call passes
      # aggregation_mode: true, which lifts the per-file cap, so the untruncated total reaches the
      # tally instead of being clipped to per_file_cap.
      it 'writes the untruncated per-file match count to the cache' do
        expect(aggregation_cache).to receive(:write).with({ 'Ruby' => untruncated_match_count })

        results.aggregations('blobs')
      end

      it 'issues the underlying Zoekt call with aggregation_mode: true' do
        expect(::Gitlab::Search::Zoekt::Client).to receive(:search) do |_query, options|
          expect(options).to include(aggregation_mode: true)
          response
        end

        results.aggregations('blobs')
      end
    end
  end
end

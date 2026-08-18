# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'constants' do
    it 'EPIC_TYPE_ID matches the epic type ID from database' do
      epic_type = ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:epic)
      expect(described_class::EPIC_TYPE_ID).to eq(epic_type&.id)
    end
  end

  describe '#highlight_map' do
    using RSpec::Parameterized::TableSyntax

    let(:proxy_response) do
      [{ _source: { id: 1 }, highlight: 'test <span class="gl-font-bold">highlight</span>' }]
    end

    let(:es_empty_response) { ::Search::EmptySearchResults.new }
    let(:es_client_response) { instance_double(::Search::Elastic::ResponseMapper, highlight_map: map) }
    let(:results) { described_class.new(user, query) }
    let(:map) { { 1 => 'test <span class="gl-font-bold">highlight</span>' } }

    where(:scope, :results_method, :results_response, :expected) do
      'projects'        | :projects       | ref(:proxy_response)      | ref(:map)
      'milestones'      | :milestones     | ref(:proxy_response)      | ref(:map)
      'notes'           | :notes          | ref(:proxy_response)      | ref(:map)
      'issues'          | :issues         | ref(:es_client_response)  | ref(:map)
      'issues'          | :issues         | ref(:es_empty_response)   | {}
      'merge_requests'  | :merge_requests | ref(:proxy_response)      | ref(:map)
      'blobs'       | nil | nil | {}
      'wiki_blobs'  | nil | nil | {}
      'commits'     | nil | nil | {}
      'epics'       | nil | nil | {}
      'users'       | nil | nil | {}
      'epics'       | nil | nil | {}
      'unknown'     | nil | nil | {}
    end

    with_them do
      it 'returns the expected highlight map' do
        expect(results).to receive(results_method).and_return(results_response) if results_method

        expect(results.highlight_map(scope)).to eq(expected)
      end
    end

    context 'when scope is work_items' do
      it 'returns the work_items highlight_map' do
        work_items_double = instance_double(Search::Elastic::ResponseMapper, highlight_map: { 1 => 'highlight' })
        allow(results).to receive(:work_items).and_return(work_items_double)

        expect(results.highlight_map('work_items')).to eq({ 1 => 'highlight' })
      end
    end

    it 'handles ::Gitlab::Search::Client::ConnectionError errors' do
      allow(results).to receive('merge_requests').and_raise(::Gitlab::Search::Client::ConnectionError.new('error'))

      expect(results.highlight_map('merge_requests')).to eq({})
    end
  end

  describe '#formatted_count' do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query) }

    where(:scope, :count_method, :value, :expected) do
      'projects'       | :projects_count       | 0     | '0'
      'notes'          | :notes_count          | 100   | '100'
      'blobs'          | :blobs_count          | 1000  | '1,000'
      'wiki_blobs'     | :wiki_blobs_count     | 1111  | '1,111'
      'commits'        | :commits_count        | 9999  | '9,999'
      'issues'         | :issues_count         | 10000 | '10,000+'
      'merge_requests' | :merge_requests_count | 20000 | '10,000+'
      'milestones'     | :milestones_count     | nil   | '0'
      'epics'          | :epics_count          | 200   | '200'
      'users'          | :users_count          | 100   | '100'
      'work_items'     | :work_items_count     | 333   | '333'
      'unknown'        | nil                   | nil   | nil
    end

    with_them do
      it 'returns the expected formatted count limited and delimited' do
        expect(results).to receive(count_method).and_return(value) if count_method
        expect(results.formatted_count(scope)).to eq(expected)
      end
    end

    it 'handles ::Gitlab::Search::Client::ConnectionError errors' do
      allow(results).to receive(:projects_count).and_raise(::Gitlab::Search::Client::ConnectionError.new('error'))

      expect(results.formatted_count('projects')).to eq('0')
    end
  end

  describe '#aggregations', :elastic_delete_by_query do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query) }

    subject(:aggregations) { results.aggregations(scope) }

    # Note: feature_flag column is retained for future feature-flagged aggregations.
    # When adding a new scope behind a feature flag, set feature_flag to the flag name
    # and add appropriate before block to stub the flag.
    where(:scope, :expected_aggregation_name, :feature_flag) do
      'projects'       | nil        | false
      'milestones'     | nil        | false
      'notes'          | nil        | false
      'issues'         | 'labels'   | false
      'merge_requests' | 'labels'   | false
      'wiki_blobs'     | nil        | false
      'commits'        | nil        | false
      'users'          | nil        | false
      'epics'          | nil        | false
      'unknown'        | nil        | false
      'blobs'          | 'language' | false
      'work_items'     | 'labels'   | false
    end

    with_them do
      before do
        stub_feature_flags(feature_flag => true) if feature_flag
        results.objects(scope) # run search to populate aggregations
      end

      it_behaves_like 'loads expected aggregations'

      context 'when feature flag is disabled' do
        before do
          skip unless feature_flag
          stub_feature_flags(feature_flag => false)
          results.objects(scope) # run search to populate aggregations
        end

        it_behaves_like 'loads expected aggregations'
      end
    end
  end

  describe '#counts' do
    let(:results) { described_class.new(user, query) }

    it 'returns an empty array' do
      expect(results.counts).to be_empty
    end
  end

  describe 'parse_search_result' do
    let_it_be(:project) { create(:project) }
    let(:content) { "foo\nbar\nbaz\n" }
    let(:path) { 'path/file.ext' }
    let(:source) do
      {
        'project_id' => project.id,
        'blob' => {
          'commit_sha' => 'sha',
          'content' => content,
          'path' => path
        }
      }
    end

    it 'returns an unhighlighted blob when no highlight data is present' do
      parsed = described_class.parse_search_result({ '_source' => source }, project)

      expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
      expect(parsed).to have_attributes(
        startline: 1,
        highlight_line: nil,
        project: project,
        data: "foo\nbar\nbaz\n"
      )
    end

    it 'parses the blob with highlighting' do
      result = {
        '_source' => source,
        'highlight' => {
          'blob.content' =>
            ["foo\n#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}" \
              "bar#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG}\nbaz\n"]
        }
      }

      parsed = described_class.parse_search_result(result, project)

      expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
      expect(parsed).to have_attributes(
        id: nil,
        path: 'path/file.ext',
        basename: 'path/file',
        ref: 'sha',
        startline: 2,
        highlight_line: 2,
        project: project,
        data: "bar\n"
      )
    end

    context 'when the highlighting finds the same terms multiple times' do
      let(:content) do
        <<~CONTENT
          bar
          bar
          foo
          bar # this is the highlighted bar
          baz
          boo
          bar
        CONTENT
      end

      it 'does not mistake a line that happens to include the same term that was highlighted on a later line' do
        highlighted_content = <<~CONTENT
          bar
          bar
          foo
          #{::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG}bar#{::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG} # this is the highlighted bar
          baz
          boo
          bar
        CONTENT

        result = {
          '_source' => source,
          'highlight' => {
            'blob.content' => [highlighted_content]
          }
        }

        parsed = described_class.parse_search_result(result, project)

        expected_data = <<~EXPECTED_DATA
          bar
          foo
          bar # this is the highlighted bar
          baz
          boo
        EXPECTED_DATA

        expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
        expect(parsed).to have_attributes(
          id: nil,
          path: 'path/file.ext',
          basename: 'path/file',
          ref: 'sha',
          startline: 2,
          highlight_line: 4,
          project: project,
          data: expected_data
        )
      end
    end

    context 'when file path in the blob contains potential backtracking regex attack pattern' do
      let(:path) { '/group/project/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab.(a+)+$' }

      it 'still parses the basename from the path with reasonable amount of time' do
        Timeout.timeout(3.seconds) do
          parsed = described_class.parse_search_result({ '_source' => source }, project)

          expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
          expect(parsed).to have_attributes(
            basename: '/group/project/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab'
          )
        end
      end
    end

    context 'when blob is a group level result' do
      let_it_be(:group) { create(:group) }
      let_it_be(:source) do
        {
          'type' => 'wiki_blob',
          'group_id' => group.id,
          'commit_sha' => 'sha',
          'content' => 'Test',
          'path' => 'home.md'
        }
      end

      it 'returns an instance of Gitlab::Search::FoundBlob with group_level_blob as true' do
        parsed = described_class.parse_search_result({ '_source' => source }, group)

        expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
        expect(parsed).to have_attributes(group: group, project: nil, group_level_blob: true)
      end
    end

    context 'when project_id is absent in the source (no_join_project documents) but container is a Project' do
      # Regression test for https://gitlab.com/gitlab-org/gitlab/-/issues/593543
      # Previously, API::Entities::Blob received a FoundBlob with a Project as the
      # group attribute, causing the missing basename attribute when the blob
      # belonged to a project context.
      let(:source_without_project_id) do
        {
          'blob' => {
            'commit_sha' => 'sha',
            'content' => content,
            'path' => path,
            'rid' => project.id.to_s
          }
        }
      end

      it 'returns a project-level FoundBlob with group: nil, not a group-level one' do
        parsed = described_class.parse_search_result({ '_source' => source_without_project_id }, project)

        expect(parsed).to be_kind_of(::Gitlab::Search::FoundBlob)
        expect(parsed).to have_attributes(project: project, group: nil, group_level_blob: false)
        expect(parsed.group).not_to be_a(::Project)
      end
    end
  end

  describe '.group_level_result?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project) }

    context 'when container is a Group' do
      it 'returns true' do
        expect(described_class.group_level_result?({}, group)).to be(true)
      end
    end

    context 'when container is a Project' do
      it 'returns false' do
        expect(described_class.group_level_result?({}, project)).to be(false)
      end
    end

    context 'when no container is given' do
      it 'returns true when project_id is blank' do
        expect(described_class.group_level_result?({ 'project_id' => nil })).to be(true)
      end

      it 'returns false when project_id is present' do
        expect(described_class.group_level_result?({ 'project_id' => 123 })).to be(false)
      end
    end
  end

  describe '#failed?' do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query) }

    context 'for scopes that response to failed? method' do
      where(:failed, :expected) do
        true  | true
        false | false
      end

      with_them do
        let(:response_mapper) { instance_double(::Search::Elastic::ResponseMapper, failed?: failed) }

        before do
          allow(results).to receive(:merge_requests).and_return(response_mapper)
        end

        let(:scope) { 'merge_requests' }

        it 'returns expected result' do
          expect(results.failed?(scope)).to be expected
        end
      end
    end

    context 'for scopes that do not respond to failed? method' do
      before do
        allow(results).to receive(:merge_requests).and_return(Kaminari.paginate_array([]))
      end

      let(:scope) { 'merge_requests' }

      it 'returns false' do
        expect(results.failed?(scope)).to be false
      end
    end
  end

  describe '#server_error?' do
    it 'returns false' do
      expect(described_class.new(user, query).server_error?).to be false
    end
  end

  describe '#error' do
    using RSpec::Parameterized::TableSyntax
    let(:results) { described_class.new(user, query) }

    context 'for scopes that response to error method' do
      where(:error, :expected) do
        'ES Error' | 'ES Error'
        nil        | nil
      end

      with_them do
        let(:response_mapper) { instance_double(::Search::Elastic::ResponseMapper, error: error) }

        before do
          allow(results).to receive(:merge_requests).and_return(response_mapper)
        end

        let(:scope) { 'merge_requests' }

        it 'returns expected result' do
          expect(results.error(scope)).to be expected
        end
      end
    end

    context 'for scopes that do not respond to error method' do
      before do
        allow(results).to receive(:merge_requests).and_return(Kaminari.paginate_array([]))
      end

      let(:scope) { 'merge_requests' }

      it 'returns false' do
        expect(results.error(scope)).to be false
      end
    end
  end

  describe '#work_items_count' do
    let(:results) { described_class.new(user, query) }

    context 'when work_items are not memoized' do
      it 'calls issues with work_items scope and count_only' do
        work_items = instance_double(Search::Elastic::ResponseMapper, total_count: 5)
        expect(results).to receive(:work_items).with(count_only: true).and_return(work_items)

        expect(results.work_items_count).to eq(5)
      end
    end

    context 'when work_items are already memoized' do
      it 'uses memoized issues total_count' do
        work_items = instance_double(Search::Elastic::ResponseMapper, total_count: 10)
        allow(results).to receive(:strong_memoized?).with(:work_items).and_return(true)
        allow(results).to receive(:work_items).and_return(work_items)

        expect(results.work_items_count).to eq(10)
      end
    end
  end

  describe '#objects' do
    let(:results) { described_class.new(user, query) }
    let(:response_mapper) { instance_double(::Search::Elastic::ResponseMapper, paginated_array: []) }
    let(:base_options) do
      {
        current_user: user,
        public_and_internal_projects: true,
        order_by: nil,
        sort: nil,
        search_level: 'global'
      }
    end

    before do
      allow(results).to receive(:related_ids_for_notes).and_return([])
    end

    context 'when scope is issues' do
      let(:expected_options) do
        base_options.merge(
          klass: WorkItem,
          index_name: ::Search::Elastic::References::WorkItem.index,
          not_work_item_type_ids: [described_class::EPIC_TYPE_ID],
          related_ids: [],
          count_only: false,
          page: 1,
          per_page: 20,
          preload_method: nil
        )
      end

      it 'searches WorkItems excluding epics' do
        captured_options = nil
        allow(::Gitlab::Search::Client).to receive(:execute_search) do |query:, options:| # rubocop:disable Lint/UnusedBlockArgument -- intentionally ignored
          captured_options = options
          response_mapper
        end

        results.objects('issues')

        expect(captured_options).to eq(expected_options)
      end

      it 'does not add related_ids on Saas', :saas do
        captured_options = nil
        allow(::Gitlab::Search::Client).to receive(:execute_search) do |query:, options:| # rubocop:disable Lint/UnusedBlockArgument -- intentionally ignored
          captured_options = options
          response_mapper
        end

        results.objects('issues')

        expect(captured_options).to eq(expected_options.except(:related_ids))
      end
    end

    context 'when scope is work_items' do
      let(:expected_options) do
        base_options.merge(
          klass: WorkItem,
          index_name: ::Search::Elastic::References::WorkItem.index,
          not_work_item_type_ids: nil,
          related_ids: [],
          count_only: false,
          page: 1,
          per_page: 20,
          preload_method: nil
        )
      end

      it 'searches WorkItems without type restriction' do
        captured_options = nil
        allow(::Gitlab::Search::Client).to receive(:execute_search) do |query:, options:| # rubocop:disable Lint/UnusedBlockArgument -- intentionally ignored
          captured_options = options
          response_mapper
        end

        results.objects('work_items')

        expect(captured_options).to eq(expected_options)
      end

      it 'does not add related_ids on Saas', :saas do
        captured_options = nil
        allow(::Gitlab::Search::Client).to receive(:execute_search) do |query:, options:| # rubocop:disable Lint/UnusedBlockArgument -- intentionally ignored
          captured_options = options
          response_mapper
        end

        results.objects('work_items')

        expect(captured_options).to eq(expected_options.except(:related_ids))
      end
    end

    context 'when scope is epics' do
      let(:epic_type) { WorkItems::TypesFramework::Provider.new.find_by_base_type(:epic) }
      let(:expected_options) do
        base_options.merge(
          klass: WorkItem,
          index_name: ::Search::Elastic::References::WorkItem.index,
          not_work_item_type_ids: nil,
          work_item_type_ids: [epic_type.id],
          count_only: false,
          page: 1,
          per_page: 20,
          preload_method: nil
        )
      end

      it 'searches WorkItems scoped to the epic type' do
        captured_options = nil
        allow(::Gitlab::Search::Client).to receive(:execute_search) do |query:, options:| # rubocop:disable Lint/UnusedBlockArgument -- intentionally ignored
          captured_options = options
          response_mapper
        end

        results.objects('epics')

        expect(captured_options).to eq(expected_options)
      end
    end

    context 'when scope is milestones' do
      let(:expected_options) do
        base_options.merge(
          features: [:issues, :merge_requests],
          count_only: false
        )
      end

      it 'passes features for project feature availability checks' do
        captured_options = nil
        es_result = instance_double(
          Elasticsearch::Model::Response::Response,
          page: instance_double(
            Elasticsearch::Model::Response::Response,
            per: instance_double(
              Elasticsearch::Model::Response::Response,
              records: instance_double(ActiveRecord::Relation,
                includes: instance_double(ActiveRecord::Relation, to_a: [])),
              total_count: 0
            )
          )
        )
        allow(Milestone).to receive(:elastic_search) do |_, options:|
          captured_options = options
          es_result
        end

        results.objects('milestones')

        expect(captured_options).to eq(expected_options)
      end
    end

    context 'when scope is users' do
      let(:expected_options) do
        base_options.merge(
          admin: false,
          routing_disabled: true,
          count_only: false
        )
      end

      before do
        allow(results).to receive(:allowed_to_read_users?).and_return(true)
      end

      it 'disables routing' do
        captured_options = nil
        es_result = instance_double(
          Elasticsearch::Model::Response::Response,
          page: instance_double(
            Elasticsearch::Model::Response::Response,
            per: instance_double(
              Elasticsearch::Model::Response::Response,
              records: instance_double(ActiveRecord::Relation,
                includes: instance_double(ActiveRecord::Relation, to_a: [])),
              total_count: 0
            )
          )
        )
        allow(User).to receive(:elastic_search) do |_, options:|
          captured_options = options
          es_result
        end

        results.objects('users')

        expect(captured_options).to eq(expected_options)
      end
    end

    context 'when scope is wiki_blobs' do
      let(:expected_options) do
        base_options.merge(
          root_ancestor_ids: nil,
          count_only: false
        )
      end

      it 'passes root_ancestor_ids in options' do
        expect(Wiki.__elasticsearch__).to receive(:elastic_search_as_wiki_page)
          .with(anything, page: anything, per: anything, options: expected_options)
          .and_return([])

        results.objects('wiki_blobs')
      end
    end
  end

  describe 'work_item_type_ids filter' do
    let(:task_type) { WorkItems::TypesFramework::Provider.new.find_by_base_type(:task) }

    context 'when work_item_type_ids filter is present' do
      it 'includes work_item_type_ids in options and removes not_work_item_type_ids' do
        results = described_class.new(user, query, filters: { work_item_type_ids: [task_type.id] })
        options = results.send(:work_item_scope_options, scope: 'work_items')

        expect(options[:work_item_type_ids]).to eq([task_type.id])
        expect(options[:not_work_item_type_ids]).to be_nil
      end
    end

    context 'when work_item_type_ids filter is not present' do
      it 'does not include work_item_type_ids in options' do
        results = described_class.new(user, query)
        options = results.send(:work_item_scope_options, scope: 'work_items')

        expect(options[:work_item_type_ids]).to be_nil
      end
    end

    context 'when scope is not work_items' do
      it 'does not process work_item_type_ids filter and keeps not_work_item_type_ids' do
        results = described_class.new(user, query, filters: { work_item_type_ids: [task_type.id] })
        options = results.send(:work_item_scope_options, scope: 'issues')

        # work_item_type_ids is included from filters but not processed (not converted to integers)
        expect(options[:work_item_type_ids]).to eq([task_type.id])
        # not_work_item_type_ids is set for 'issues' scope (excludes epics)
        expect(options[:not_work_item_type_ids]).to eq([described_class::EPIC_TYPE_ID])
      end
    end
  end
end

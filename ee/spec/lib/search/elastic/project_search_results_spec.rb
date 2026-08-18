# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::ProjectSearchResults, :elastic, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:project) { create(:project, :public, :repository) }

  let_it_be(:query) { 'hello world' }
  let(:repository_ref) { nil }
  let(:filters) { {} }

  subject(:results) do
    described_class.new(user, query, project: project, repository_ref: repository_ref, filters: filters)
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'initialize with empty ref' do
    let(:repository_ref) { '' }

    it { expect(results.project).to eq(project) }
    it { expect(results.repository_ref).to eq('master') }
    it { expect(results.query).to eq('hello world') }
  end

  describe 'initialize with ref' do
    let(:repository_ref) { 'refs/heads/test' }

    it { expect(results.project).to eq(project) }
    it { expect(results.repository_ref).to eq(repository_ref) }
    it { expect(results.query).to eq('hello world') }
  end

  describe "search", :sidekiq_inline do
    let_it_be_with_reload(:project) { create(:project, :public, :repository, :wiki_repo) }
    let_it_be_with_reload(:private_project) { create(:project, :repository, :wiki_repo) }

    before do
      [project, private_project].each do |p|
        create(:note, note: 'bla-bla term', project: p)
        p.wiki.create_page('index_page', 'term')
        p.wiki.index_wiki_blobs
        p.repository.index_commits_and_blobs
      end

      ensure_elasticsearch_index!
    end

    it "returns correct amounts" do
      result = described_class.new(user, 'term', project: project)
      expect(result.notes_count).to eq(1)
      expect(result.wiki_blobs_count).to eq(1)
      expect(result.blobs_count).to eq(1)

      result = described_class.new(user, 'initial', project: project)
      expect(result.commits_count).to eq(1)
    end

    context 'for visibility checks' do
      let(:query) { 'term' }

      before_all do
        project.add_guest(user)
      end

      it 'shows wiki for guests' do
        expect(results.wiki_blobs_count).to eq(1)
      end
    end

    context 'when filtering' do
      let(:query) { 'foo' }

      let_it_be_with_reload(:project) { create(:project, :public, :repository, developers: user) }

      before do
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
        ensure_elasticsearch_index!
      end

      context 'for issues' do
        let(:scope) { 'issues' }

        let_it_be_with_reload(:project) { create(:project, :public, developers: [user]) }
        let_it_be(:closed_result) { create(:issue, :closed, project: project, title: 'foo closed') }
        let_it_be(:opened_result) { create(:issue, :opened, project: project, title: 'foo opened') }
        let_it_be(:confidential_result) { create(:issue, :confidential, project: project, title: 'foo confidential') }

        before do
          ::Elastic::ProcessInitialBookkeepingService.track!(opened_result)
          ::Elastic::ProcessInitialBookkeepingService.track!(closed_result)
          ::Elastic::ProcessInitialBookkeepingService.track!(confidential_result)
          ensure_elasticsearch_index!
        end

        context 'when advanced search query syntax is used' do
          let(:query) { 'foo -banner' }

          include_examples 'search results filtered by state'
          include_examples 'search results filtered by confidential'
          include_examples 'search results filtered by labels'
        end

        include_examples 'search results filtered by state'
        include_examples 'search results filtered by confidential'
        include_examples 'search results filtered by labels'
      end

      context 'for merge_requests' do
        let(:scope) { 'merge_requests' }
        let!(:note_merge_request) do
          create(:merge_request, source_project: project, source_branch: 'open-1', title: 'Hello world, here I am!')
        end

        let!(:note) do
          create(:note_on_merge_request, note: 'Goodbye foo', noteable: note_merge_request,
            project: note_merge_request.project)
        end

        let_it_be(:opened_result) { create(:merge_request, :opened, source_project: project, title: 'foo opened') }
        let_it_be(:closed_result) { create(:merge_request, :closed, source_project: project, title: 'foo closed') }

        before do
          ::Elastic::ProcessInitialBookkeepingService.track!(opened_result)
          ::Elastic::ProcessInitialBookkeepingService.track!(closed_result)
          ensure_elasticsearch_index!
        end

        include_examples 'search results filtered by state'
        context 'on self hosted' do
          include_examples 'searching notable entries in merge requests'
        end

        context 'on SAAS', :saas do
          include_examples 'searching notable entries in merge requests'
        end
      end

      context 'for blobs' do
        it_behaves_like 'search results filtered by language'
      end
    end
  end

  describe 'confidential issues', :sidekiq_might_not_need_inline do
    include_examples 'access restricted confidential issues' do
      before do
        ensure_elasticsearch_index!
      end
    end
  end

  describe 'users' do
    let(:query) { 'john' }
    let(:scope) { 'users' }
    let(:results) { described_class.new(user, query, project: project) }

    it 'returns an empty list' do
      create_list(:user, 3, name: "Sarah John")

      ensure_elasticsearch_index!

      users = results.objects('users')

      expect(users).to eq([])
      expect(results.users_count).to eq 0
    end

    context 'with project members' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: parent_group) }
      let_it_be(:child_group) { create(:group, parent: group) }
      let_it_be(:child_of_parent_group) { create(:group, parent: parent_group) }
      let_it_be(:project_in_group) { create(:project, namespace: group) }
      let_it_be(:project_in_child_group) { create(:project, namespace: child_group) }
      let_it_be(:project_in_parent_group) { create(:project, namespace: parent_group) }
      let_it_be(:project_in_child_of_parent_group) { create(:project, namespace: child_of_parent_group) }

      let(:results) { described_class.new(user, query, project: project_in_group) }

      it 'returns matching users who have access to the project' do
        users = create_list(:user, 8, name: "Sarah John")

        project_in_group.add_developer(users[0])
        project_in_child_group.add_developer(users[1])
        project_in_parent_group.add_developer(users[2])
        project_in_child_of_parent_group.add_developer(users[3])

        group.add_developer(users[4])
        parent_group.add_developer(users[5])
        child_group.add_developer(users[6])
        child_of_parent_group.add_developer(users[7])

        ensure_elasticsearch_index!

        expect(results.objects('users')).to contain_exactly(users[0], users[4], users[5])
        expect(results.users_count).to eq 3
      end
    end
  end

  describe 'notes' do
    before do
      Elastic::ProcessBookkeepingService.track!(note)
      ensure_elasticsearch_index!
    end

    context 'when project is archived' do
      let_it_be(:project) { create(:project, :archived, :public) }
      let_it_be(:note) { create(:note, note: query, project: project) }

      context 'when filters contains include_archived as true' do
        let(:filters) do
          { include_archived: true }
        end

        it 'includes the archived notes in the search results' do
          expect(results.objects('notes')).to contain_exactly note
        end
      end

      it 'includes the archived notes in the search results' do
        expect(results.objects('notes')).to contain_exactly note
      end
    end

    context 'when project is not archived' do
      let_it_be(:project) { create(:project, :public) }
      let_it_be(:note) { create(:note, note: query, project: project) }

      it 'includes the notes from the project' do
        expect(results.objects('notes')).to contain_exactly note
      end
    end
  end

  describe 'query performance' do
    let_it_be_with_reload(:project) { create(:project, :public, :repository, :wiki_repo) }
    let(:query) { '*' }

    before do
      # wiki_blobs method checks to see if there is a wiki page before doing the search
      create(:wiki_page, wiki: project.wiki)
    end

    allowed_scopes = %w[notes blobs wiki_blobs commits merge_requests milestones users]
    scopes_with_notes_query = %w[issues merge_requests]

    include_examples 'calls Elasticsearch the expected number of times',
      scopes: (allowed_scopes - scopes_with_notes_query), scopes_with_multiple: scopes_with_notes_query

    allowed_scopes_and_index_names = [
      %W[notes #{Note.index_name}],
      %W[blobs #{Repository.index_name}],
      %W[wiki_blobs #{Wiki.index_name}],
      %W[commits #{Elastic::Latest::CommitConfig.index_name}],
      %W[issues #{::Search::Elastic::References::WorkItem.index}],
      %W[merge_requests #{MergeRequest.index_name}],
      %W[milestones #{Milestone.index_name}],
      %W[users #{User.index_name}]
    ]
    include_examples 'does not load results for count only queries', allowed_scopes_and_index_names
  end

  describe '#aggregations' do
    using RSpec::Parameterized::TableSyntax

    let(:results) { described_class.new(user, query, project: project) }

    subject(:aggregations) { results.aggregations(scope) }

    where(:scope, :expected_aggregation_name, :feature_flag) do
      'milestones'     | nil        | false
      'notes'          | nil        | false
      'issues'         | 'labels'   | false
      'merge_requests' | 'labels'   | false
      'wiki_blobs'     | nil        | false
      'commits'        | nil        | false
      'users'          | nil        | false
      'unknown'        | nil        | false
      'blobs'          | 'language' | false
    end

    with_them do
      context 'when feature flag is enabled for user' do
        let(:feature_enabled) { true }

        before do
          stub_feature_flags(feature_flag => user) if feature_flag
        end

        it_behaves_like 'loads expected aggregations'
      end

      context 'when feature flag is disabled for user' do
        let(:feature_enabled) { false }

        before do
          stub_feature_flags(feature_flag => false) if feature_flag
        end

        it_behaves_like 'loads expected aggregations'
      end
    end

    context 'for project search specific gates for blob scope' do
      let(:scope) { 'blobs' }

      context 'when query is blank' do
        let(:query) { nil }

        it 'returns the an empty array' do
          expect(aggregations).to be_empty
        end
      end

      context 'when project has an empty repository' do
        it 'returns an empty array' do
          allow(project).to receive(:empty_repo?).and_return(true)

          expect(aggregations).to be_empty
        end
      end

      context 'when user does not have download_code permission on project' do
        it 'returns an empty array' do
          allow(Ability).to receive(:allowed?).with(user, :read_code, project).and_return(false)

          expect(aggregations).to be_empty
        end
      end
    end
  end

  describe '#scope_options' do
    let(:results) { described_class.new(user, query, project: project) }

    context 'when scope is :work_items' do
      it 'returns hash with search level project' do
        options = results.send(:scope_options, :work_items)

        expect(options).to be_a(Hash)
        expect(options[:search_level]).to eq('project')
        expect(options[:klass]).to eq(WorkItem)
      end
    end
  end

  describe '#related_ids_for_notes' do
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:project) { create(:project, :public, group: top_level_group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:note) { create(:note, noteable: issue, project: project) }

    before do
      Elastic::ProcessBookkeepingService.track!(issue, note)
      ensure_elasticsearch_index!
    end

    it 'calls elastic_search on Note model' do
      expect(Note).to receive(:elastic_search).and_call_original

      results.send(:scope_options, :merge_requests)
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::GroupSearchResults, :elastic, :sidekiq_inline, feature_category: :global_search do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:filters) { {} }
  let(:query) { '*' }

  subject(:results) do
    described_class.new(user, query, group: group, filters: filters)
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_licensed_features(epics: true, group_wikis: true)
  end

  context 'for issues' do
    let_it_be(:project) { create(:project, :public, group: group, developers: user) }
    let_it_be(:closed_result) { create(:issue, :closed, project: project, title: 'foo closed') }
    let_it_be(:opened_result) { create(:issue, :opened, project: project, title: 'foo opened') }
    let_it_be(:confidential_result) { create(:issue, :confidential, project: project, title: 'foo confidential') }

    let(:query) { 'foo' }
    let(:scope) { 'issues' }

    before do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    context 'when advanced search query syntax is used' do
      let(:query) { 'foo -banner' }

      include_examples 'search results filtered by state'
      include_examples 'search results filtered by confidential'
      include_examples 'search results filtered by labels'

      it_behaves_like 'namespace ancestry_filter for aggregations' do
        let(:query_name) { 'filters:permissions:group:private_access:ancestry_filter:descendants' }
      end
    end

    include_examples 'search results filtered by state'
    include_examples 'search results filtered by confidential'
    include_examples 'search results filtered by labels'
    it_behaves_like 'namespace ancestry_filter for aggregations' do
      let(:query_name) { 'filters:permissions:group:private_access:ancestry_filter:descendants' }
    end
  end

  context 'for merge_requests' do
    let_it_be(:project) { create(:project, :public, group: group) }
    let_it_be(:note_merge_request) do
      create(:merge_request, source_project: project, source_branch: 'open-1', title: 'Hello world, here I am!')
    end

    let_it_be(:note) do
      create(:note_on_merge_request, note: 'Goodbye foo', noteable: note_merge_request, project: project)
    end

    let_it_be(:unarchived_project) { create(:project, :public, group: group) }
    let_it_be(:archived_project) { create(:project, :public, :archived, group: group) }
    let_it_be(:opened_result) { create(:merge_request, :opened, source_project: project, title: 'foo opened') }
    let_it_be(:closed_result) { create(:merge_request, :closed, source_project: project, title: 'foo closed') }
    let_it_be(:unarchived_result) { create(:merge_request, source_project: unarchived_project, title: 'foo unarchive') }
    let_it_be(:archived_result) { create(:merge_request, source_project: archived_project, title: 'foo archived') }

    let(:query) { 'foo' }
    let(:scope) { 'merge_requests' }

    before do
      [project, unarchived_project, archived_project].each do |project|
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      end
      ensure_elasticsearch_index!
    end

    include_examples 'search results filtered by state'
    include_examples 'search results filtered by archived'

    context 'on self hosted' do
      include_examples 'searching notable entries in merge requests'
    end

    context 'on SAAS', :saas do
      include_examples 'searching notable entries in merge requests'
    end
  end

  context 'for blobs' do
    let(:scope) { 'blobs' }

    context 'when filtering by language' do
      let_it_be(:project) { create(:project, :public, :repository, group: group) }

      it_behaves_like 'search results filtered by language'
    end

    context 'when filtering by archived' do
      before do
        unarchived_project.repository.index_commits_and_blobs
        archived_project.repository.index_commits_and_blobs

        ensure_elasticsearch_index!

        allow(Gitlab::Search::FoundBlob).to receive(:new).and_return(instance_double(Gitlab::Search::FoundBlob))

        allow(Gitlab::Search::FoundBlob).to receive(:new)
          .with(a_hash_including(project_id: unarchived_project.id,
            ref: unarchived_project.commit.id)).and_return(unarchived_result)

        allow(Gitlab::Search::FoundBlob).to receive(:new)
          .with(a_hash_including(project_id: archived_project.id,
            ref: archived_project.commit.id)).and_return(archived_result)
      end

      let_it_be(:unarchived_project) { create(:project, :public, :repository, group: group) }
      let_it_be(:archived_project) { create(:project, :archived, :repository, :public, group: group) }

      let(:unarchived_result) { instance_double(Gitlab::Search::FoundBlob, project: unarchived_project) }
      let(:archived_result) { instance_double(Gitlab::Search::FoundBlob, project: archived_project) }
      let(:query) { 'something went wrong' }

      include_examples 'search results filtered by archived', nil, nil
    end

    it_behaves_like 'namespace ancestry_filter for aggregations' do
      let(:query_name) { 'filters:permissions:group:private_access:ancestry_filter:descendants' }
    end
  end

  context 'for commits' do
    let_it_be(:owner) { create(:user) }
    let_it_be(:unarchived_project) { create(:project, :public, :repository, group: group, creator: owner) }
    let_it_be(:archived_project) { create(:project, :archived, :repository, :public, group: group, creator: owner) }

    let_it_be(:unarchived_result_object) do
      unarchived_project.repository.create_file(owner, 'test.rb', '# foo bar', message: 'foo bar',
        branch_name: 'master')
    end

    let_it_be(:archived_result_object) do
      archived_project.repository.create_file(owner, 'test.rb', '# foo', message: 'foo', branch_name: 'master')
    end

    let(:unarchived_result) { unarchived_project.commit }
    let(:archived_result) { archived_project.commit }
    let(:scope) { 'commits' }
    let(:query) { 'foo' }

    before do
      unarchived_project.repository.index_commits_and_blobs
      archived_project.repository.index_commits_and_blobs
      ensure_elasticsearch_index!
    end

    include_examples 'search results filtered by archived', nil, nil
  end

  context 'for wiki_blobs' do
    let_it_be_with_reload(:owner) { create(:user) }
    let_it_be_with_reload(:group_wiki) { create(:group_wiki, group: group) }
    let_it_be_with_reload(:unarchived_project) { create(:project, :wiki_repo, :public, creator: owner) }
    let_it_be_with_reload(:archived_project) { create(:project, :archived, :wiki_repo, :public, creator: owner) }
    let(:scope) { 'wiki_blobs' }

    before do
      [unarchived_project, archived_project].each { |p| p.update!(group: group) }
      [unarchived_project.wiki, archived_project.wiki, group_wiki].each do |wiki|
        wiki.create_page('test.md', 'foo bar')
        wiki.index_wiki_blobs
      end
      ensure_elasticsearch_index!
    end

    context 'when include_archived is true' do
      let(:filters) do
        { include_archived: true }
      end

      it 'includes results from the archived project and group' do
        collection = results.objects(scope)
        expect(collection.size).to eq 3
        expect(collection.map(&:project)).to include(archived_project)
      end
    end

    it 'excludes the wikis from the archived project' do
      collection = results.objects(scope)
      expect(collection.size).to eq 2
      expect(collection.map(&:project)).not_to include(archived_project)
    end
  end

  context 'for projects' do
    let_it_be(:unarchived_result) { create(:project, :public, group: group) }
    let_it_be(:archived_result) { create(:project, :archived, :public, group: group) }

    let(:scope) { 'projects' }

    it_behaves_like 'search results filtered by archived' do
      before do
        Elastic::ProcessInitialBookkeepingService.track!(unarchived_result, archived_result)

        ensure_elasticsearch_index!
      end
    end

    context 'if the user is authorized to view the group' do
      it 'has a traversal_ids prefix filter' do
        group.add_owner(user)

        results.objects(scope)

        assert_named_queries('filters:permissions:group:ancestry_filter:descendants',
          'filters:permissions:group:visibility_level:public_and_internal',
          without: ['filters:permissions:group:project:member'])
      end
    end

    context 'if the user is authorized to view the project' do
      it 'has a project membership filter' do
        unarchived_result.add_developer(user)

        results.objects(scope)

        assert_named_queries('filters:permissions:group:project:member',
          'filters:permissions:group:visibility_level:public_and_internal',
          without: ['filters:permissions:group:ancestry_filter:descendants'])
      end
    end
  end

  context 'for group level work items' do
    let(:query) { 'foo' }
    let(:scope) { 'epics' }

    let_it_be(:public_parent_group) { create(:group, :public) }
    let_it_be(:group) { create(:group, :private, parent: public_parent_group) }
    let_it_be(:child_group) { create(:group, :private, parent: group) }
    let_it_be(:child_of_child_group) { create(:group, :private, parent: child_group) }
    let_it_be(:another_group) { create(:group, :private, parent: public_parent_group) }
    let!(:parent_group_epic) do
      create(:work_item, :group_level, :epic_with_legacy_epic, namespace: public_parent_group, title: query)
    end

    let!(:group_epic) { create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: query) }
    let!(:child_group_epic) do
      create(:work_item, :group_level, :epic_with_legacy_epic, namespace: child_group, title: query)
    end

    let!(:confidential_child_group_epic) do
      create(:work_item, :group_level, :epic_with_legacy_epic, :confidential, namespace: child_group, title: query)
    end

    let!(:confidential_child_of_child_epic) do
      create(:work_item, :group_level, :epic_with_legacy_epic, :confidential, namespace: child_of_child_group,
        title: query)
    end

    let!(:another_group_epic) do
      create(:work_item, :group_level, :epic_with_legacy_epic, namespace: another_group, title: query)
    end

    before do
      ensure_elasticsearch_index!
    end

    it 'returns no epics' do
      expect(results.objects('epics')).to be_empty
    end

    context 'when the user is a developer on the group' do
      before_all do
        group.add_developer(user)
      end

      it 'returns matching epics belonging to the group or its descendants, including confidential epics' do
        epics = results.objects('epics')

        expect(epics).to include(group_epic)
        expect(epics).to include(child_group_epic)
        expect(epics).to include(confidential_child_group_epic)

        expect(epics).not_to include(parent_group_epic)
        expect(epics).not_to include(another_group_epic)
      end

      context 'when searching from the child group' do
        it 'returns matching epics belonging to the child group, including confidential epics' do
          epics = described_class.new(user, query, group: child_group, filters: filters).objects('epics')

          expect(epics).to include(child_group_epic)
          expect(epics).to include(confidential_child_group_epic)

          expect(epics).not_to include(group_epic)
          expect(epics).not_to include(parent_group_epic)
          expect(epics).not_to include(another_group_epic)
        end
      end
    end

    context 'when the user is a guest of the child group and an owner of its child group' do
      before_all do
        child_group.add_guest(user)
      end

      it 'only returns non-confidential epics' do
        epics = described_class.new(user, query, group: child_group, filters: filters).objects('epics')

        expect(epics).to include(child_group_epic)
        expect(epics).not_to include(confidential_child_group_epic)

        assert_named_queries(
          'work_item:multi_match:and:search_terms',
          'work_item:multi_match_phrase:search_terms',
          'filters:level:group:ancestry_filter:descendants',
          'filters:confidentiality:groups:non_confidential',
          'filters:confidentiality:groups:confidential',
          'filters:confidentiality:groups:confidential:as_assignee',
          'filters:confidentiality:groups:confidential:as_author',
          without: %w[filters:confidentiality:groups:private:ancestry_filter:descendants]
        )
      end

      context 'when the user is an owner of its child group' do
        before_all do
          child_of_child_group.add_owner(user)
        end

        it 'returns confidential epics from the child group' do
          epics = described_class.new(user, query, group: child_group, filters: filters).objects('epics')

          expect(epics).to include(child_group_epic)
          expect(epics).to include(confidential_child_of_child_epic)

          expect(epics).not_to include(confidential_child_group_epic)

          assert_named_queries(
            'work_item:multi_match:and:search_terms',
            'work_item:multi_match_phrase:search_terms',
            'filters:level:group:ancestry_filter:descendants',
            'filters:confidentiality:groups:non_confidential',
            'filters:confidentiality:groups:confidential',
            'filters:confidentiality:groups:confidential:as_assignee',
            'filters:confidentiality:groups:confidential:as_author',
            'filters:confidentiality:groups:private:ancestry_filter:descendants'
          )
        end
      end
    end

    it_behaves_like 'can search by title for miscellaneous cases', 'epics'

    include_context 'with code examples' do
      before do
        code_examples.values.uniq.each do |description|
          sha = Digest::SHA256.hexdigest(description)
          create :work_item, :group_level, :epic_with_legacy_epic, namespace: public_parent_group, title: sha,
            description: description
        end

        ensure_elasticsearch_index!
      end

      it 'finds all examples' do
        code_examples.each do |query, description|
          sha = Digest::SHA256.hexdigest(description)

          epics = described_class.new(user, query, group: public_parent_group, filters: filters).objects(scope)
          expect(epics.map(&:title)).to include(sha)
        end
      end
    end
  end

  context 'for users' do
    let(:query) { 'john' }
    let(:scope) { 'users' }
    let(:results) { described_class.new(user, query, group: group) }

    it 'returns an empty list' do
      create_list(:user, 3, name: "Sarah John")

      ensure_elasticsearch_index!

      users = results.objects('users')

      expect(users).to eq([])
      expect(results.users_count).to eq 0
    end

    context 'with group members' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: parent_group) }
      let_it_be(:child_group) { create(:group, parent: group) }
      let_it_be(:child_of_parent_group) { create(:group, parent: parent_group) }
      let_it_be(:project_in_group) { create(:project, namespace: group) }
      let_it_be(:project_in_child_group) { create(:project, namespace: child_group) }
      let_it_be(:project_in_parent_group) { create(:project, namespace: parent_group) }
      let_it_be(:project_in_child_of_parent_group) { create(:project, namespace: child_of_parent_group) }

      it 'returns matching users who have access to the group' do
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

        expect(results.objects('users')).to contain_exactly(users[0], users[1], users[4], users[5], users[6])
        expect(results.users_count).to eq 5
      end
    end

    context 'when private project member searches for user in private group' do
      let_it_be(:private_group) { create(:group, :private) }
      let_it_be(:private_project) { create(:project, :private, group: private_group) }
      let_it_be(:user2) { create(:user, name: 'Sarah John') }
      let(:results) { described_class.new(user, query, group: private_group) }

      before_all do
        private_group.add_guest(user2)
        private_project.add_guest(user)
        ensure_elasticsearch_index!
      end

      it 'returns empty when user does not have read_group_member permission' do
        expect(results.objects(scope)).to be_empty
      end
    end
  end

  context 'for notes' do
    let_it_be(:query) { 'foo' }
    let_it_be(:project) { create(:project, :public, namespace: group) }
    let_it_be(:archived_project) { create(:project, :public, :archived, namespace: group) }
    let_it_be(:note) { create(:note, project: project, note: query) }
    let_it_be(:note_on_archived_project) { create(:note, project: archived_project, note: query) }

    before do
      Elastic::ProcessBookkeepingService.track!(note, note_on_archived_project)
      ensure_elasticsearch_index!
    end

    context 'when filters contains include_archived as true' do
      let(:filters) do
        { include_archived: true }
      end

      it 'includes the archived notes in the search results' do
        expect(results.objects('notes')).to match_array([note, note_on_archived_project])
      end
    end

    it 'does not includes the archived notes in the search results' do
      expect(results.objects('notes')).to match_array([note])
    end
  end

  context 'for milestones' do
    let!(:unarchived_project) { create(:project, :public, group: group) }
    let!(:archived_project) { create(:project, :public, :archived, group: group) }
    let!(:unarchived_result) { create(:milestone, project: unarchived_project, title: 'foo unarchived') }
    let!(:archived_result) { create(:milestone, project: archived_project, title: 'foo archived') }
    let(:query) { 'foo' }
    let(:scope) { 'milestones' }

    before do
      ensure_elasticsearch_index!
    end

    include_examples 'search results filtered by archived', nil
  end

  describe 'query performance' do
    allowed_scopes = %w[projects notes blobs wiki_blobs commits issues merge_requests epics milestones users]
    scopes_with_notes_query = %w[issues merge_requests]

    include_examples 'calls Elasticsearch the expected number of times',
      scopes: (allowed_scopes - scopes_with_notes_query), scopes_with_multiple: scopes_with_notes_query

    allowed_scopes_and_index_names = [
      %W[projects #{Project.index_name}],
      %W[notes #{Note.index_name}],
      %W[blobs #{Repository.index_name}],
      %W[wiki_blobs #{Wiki.index_name}],
      %W[commits #{Elastic::Latest::CommitConfig.index_name}],
      %W[issues #{::Search::Elastic::References::WorkItem.index}],
      %W[merge_requests #{MergeRequest.index_name}],
      %W[epics #{::Search::Elastic::References::WorkItem.index}],
      %W[milestones #{Milestone.index_name}],
      %W[users #{User.index_name}]
    ]
    include_examples 'does not load results for count only queries', allowed_scopes_and_index_names
  end

  describe '#scope_options' do
    context 'for user' do
      it 'has not group_ids' do
        expect(results.scope_options(:users)).not_to include :group_ids
      end
    end

    context 'for work_items' do
      it 'has root_ancestor_ids' do
        expect(results.scope_options(:work_items)).to include :root_ancestor_ids
      end
    end

    context 'for epics' do
      it 'has root_ancestor_ids' do
        expect(results.scope_options(:epics)).to include :root_ancestor_ids
      end
    end

    context 'for wiki_blobs' do
      it 'has root_ancestor_ids' do
        expect(results.scope_options(:wiki_blobs)).to include :root_ancestor_ids
      end
    end
  end

  describe '#related_ids_for_notes' do
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: top_level_group) }
    let_it_be(:project) { create(:project, :public, group: top_level_group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:note) { create(:note, noteable: issue, project: project) }

    before do
      Elastic::ProcessBookkeepingService.track!(issue, note)
      ensure_elasticsearch_index!
    end

    context 'when searching in a top-level namespace' do
      let(:results) do
        described_class.new(user, 'test', group: top_level_group)
      end

      it 'calls elastic_search on Note model' do
        expect(Note).to receive(:elastic_search).and_call_original

        results.scope_options(:merge_requests)
      end
    end

    context 'when searching in a subgroup' do
      let(:results) do
        described_class.new(user, 'test', group: subgroup)
      end

      it 'calls elastic_search on Note model' do
        expect(Note).to receive(:elastic_search).and_call_original

        results.scope_options(:merge_requests)
      end
    end
  end
end

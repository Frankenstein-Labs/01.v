# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project elastic search', :js, :elastic, :disable_rate_limiter, feature_category: :global_search do
  let_it_be(:user, freeze: false) { create(:user, maintainer_of: project) }
  let_it_be(:project, freeze: false) { create(:project, :repository, :wiki_repo, namespace: user.namespace) }

  before do
    stub_ee_application_setting(
      elasticsearch_search: true,
      elasticsearch_indexing: true
    )
    sign_in(user)
  end

  describe 'searching' do
    it 'finds work items' do
      create(:issue, project: project, title: 'Test searching for a work item')
      ensure_elasticsearch_index!

      submit_dashboard_search('Test')
      select_search_scope('Work items')

      expect(page).to have_selector('.results', text: 'Test searching for a work item')
    end

    it 'finds merge requests' do
      create(:merge_request, source_project: project, target_project: project, title: 'Test searching for an MR')
      ensure_elasticsearch_index!

      submit_dashboard_search('Test')
      select_search_scope('Merge requests')

      expect(page).to have_selector('.results', text: 'Test searching for an MR')
    end

    it 'finds milestones' do
      create(:milestone, project: project, title: 'Test searching for a milestone')
      ensure_elasticsearch_index!

      submit_dashboard_search('Test')
      select_search_scope('Milestones')

      expect(page).to have_selector('.results', text: 'Test searching for a milestone')
    end

    it 'finds wiki pages', :sidekiq_inline do
      project.wiki.create_page('test.md', 'Test searching for a wiki page')
      project.wiki.index_wiki_blobs
      ensure_elasticsearch_index!

      submit_dashboard_search('Test')
      select_search_scope('Wiki')

      expect(page).to have_selector('.results', text: 'Test searching for a wiki page')
    end

    it 'finds notes' do
      create(:note, project: project, note: 'Test searching for a comment')
      ensure_elasticsearch_index!

      submit_dashboard_search('Test')
      select_search_scope('Comments')

      expect(page).to have_selector('.results', text: 'Test searching for a comment')
    end

    it 'finds commits', :sidekiq_inline do
      project.repository.index_commits_and_blobs
      ensure_elasticsearch_index!

      submit_dashboard_search('initial')
      select_search_scope('Commits')

      expect(page).to have_selector('.results', text: 'Initial commit')
    end

    it 'finds blobs', :sidekiq_inline do
      project.repository.index_commits_and_blobs
      ensure_elasticsearch_index!

      submit_dashboard_search('def')
      select_search_scope('Code')

      expect(page).to have_selector('.results', text: 'def username_regex')
      expect(page).to have_button('Copy file path')
    end
  end

  describe 'displays Advanced Search status' do
    before do
      visit search_path(project_id: project.id, repository_ref: repository_ref, scope: scope, search: 'test')
    end

    context "when `repository_ref` is the default branch" do
      let(:repository_ref) { project.default_branch }
      let(:scope) { "" }

      it 'displays that advanced search is enabled' do
        expect(page).to have_content('Advanced search is enabled.')
      end
    end

    context "when `repository_ref` isn't the default branch" do
      let(:repository_ref) { Gitlab::Git::SHA1_BLANK_SHA }
      let(:scope) { "blobs" }

      it 'displays that exact code search is disabled' do
        expect(page).to have_content('Advanced search is disabled')
        expect(page).to have_link('Learn more.',
          href: help_page_path('user/search/advanced_search.md', anchor: 'syntax'))
      end
    end

    context "when `repository_ref` is unset" do
      let(:repository_ref) { "" }
      let(:scope) { "" }

      it 'displays that advanced search is enabled' do
        wait_for_requests
        expect(page).to have_text('Advanced search is enabled')
      end
    end
  end

  describe 'when zoekt is not enabled' do
    before do
      visit project_path(project)
      ensure_elasticsearch_index!

      submit_dashboard_search('test')
      select_search_scope('Code')
    end

    it 'does not display exact code search is enabled' do
      expect(page).to have_text('Advanced search is enabled')
      expect(page).not_to have_text('Exact code search (powered by Zoekt) is enabled')
    end
  end

  describe 'renders error when zoekt search fails', :zoekt_settings_enabled do
    let(:query) { 'test' }
    let(:search_service) do
      instance_double(Search::ProjectService,
        scope: 'blobs',
        use_elasticsearch?: true,
        use_zoekt?: true,
        elasticsearchable_scope: project,
        search_type: 'zoekt'
      )
    end

    let_it_be(:zoekt_node, freeze: false) { create(:zoekt_node) }

    let(:results) do
      Search::Zoekt::SearchResults.new(user, query, nil, project_id: project.id,
        node_id: zoekt_node.id)
    end

    before do
      sign_in(user)

      allow_next_instance_of(SearchService) do |service|
        allow(service).to receive_messages(search_service: search_service, search_results: results)
      end

      allow(::Gitlab::Search::Zoekt::Client.instance).to receive(:search)
          .and_return(Gitlab::Search::Zoekt::Response.new({ Error: 'failed to parse query' }, code: 400))
      visit search_path(search: query, project_id: project.id)
    end

    it 'renders error information' do
      expect(page).to have_content('A problem has occurred')
      expect(page).to have_link(
        'What is the supported syntax',
        href: help_page_path('user/search/exact_code_search.md', anchor: 'syntax')
      )
    end

    it 'sets tab count to 0' do
      within_testid('search-filter') do
        link = find_link 'Code'

        expect(link).to have_text('0')
      end
    end
  end
end

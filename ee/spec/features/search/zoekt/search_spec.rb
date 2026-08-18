# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Zoekt search', :js, :disable_rate_limiter, :zoekt_settings_enabled, :with_current_organization, feature_category: :global_search do
  include ListboxHelpers
  include ProjectForksHelper

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project1) { create(:project, :repository, :public, namespace: group) }
  let_it_be(:project2) { create(:project, :repository, :public, namespace: group) }
  let_it_be(:archived_project) { create(:project, :public, :archived, :repository, namespace: group) }
  let_it_be(:forked_project) { fork_project(project1, nil, repository: true, namespace: group) }
  let_it_be(:group2) { create(:group, :public) }
  let_it_be(:project3) { create(:project, :repository, :private, namespace: group2) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_owner(user)
    group2.add_owner(user)
    zoekt_ensure_project_indexed!(project1)
    zoekt_ensure_project_indexed!(project2)
    zoekt_ensure_project_indexed!(archived_project)
    zoekt_ensure_project_indexed!(forked_project)
    zoekt_ensure_project_indexed!(project3)
  end

  before do
    sign_in(user)
    visit(search_path)
    wait_for_requests
    choose_group(group)
    select_search_scope(_('Code'))
    wait_for_all_requests
  end

  shared_examples 'zoekt search results' do |result_count|
    it 'displays the expected search results with the correct UI elements' do
      expect(page).to have_selector('.file-content .blob-content', count: result_count, wait: 60)
      expect(page).to have_link(_('Exact code search (powered by Zoekt)'),
        href: help_page_path('user/search/exact_code_search.md'))
      expect(page).to have_button(_('Copy file path'))
    end
  end

  context 'with exact search' do
    before do
      submit_search('\A[a-zA-Z0-9_\-\. ]*\z')
    end

    include_examples 'zoekt search results', 3

    context 'when filtering by project' do
      before do
        choose_project(project1)
      end

      include_examples 'zoekt search results', 1
    end
  end

  context 'with regex search' do
    before do
      find_by_testid('reqular-expression-toggle').click
      submit_search('user.*egex')
    end

    include_examples 'zoekt search results', 3

    context 'when filtering by project' do
      before do
        choose_project(project1)
      end

      include_examples 'zoekt search results', 1
    end
  end

  context 'with archived projects filter' do
    before do
      submit_search('username_regex')
    end

    it 'excludes archived projects by default' do
      expect(page).to have_selector('.file-content .blob-content', count: 3, wait: 60)
    end

    context 'when including archived projects' do
      before do
        check s_('GlobalSearch|Include archived')
        wait_for_all_requests
      end

      it 'includes archived projects in search results' do
        expect(page).to have_selector('.file-content .blob-content', count: 4, wait: 60)
      end
    end
  end

  context 'with forked projects filter' do
    before do
      submit_search('username_regex')
    end

    it 'includes forks by default' do
      expect(page).to have_selector('.file-content .blob-content', count: 3, wait: 60)
    end

    context 'when excluding forks' do
      before do
        find_by_testid('tooltip-checkbox-label').click
        wait_for_all_requests
      end

      it 'excludes forked projects from search results' do
        expect(page).to have_selector('.file-content .blob-content', count: 2, wait: 60)
      end
    end
  end

  context 'with cross-project search' do
    before do
      find_by_testid('tooltip-checkbox-label').click
      wait_for_all_requests
      submit_search('username_regex')
    end

    it 'returns results from multiple projects in the group' do
      expect(page).to have_selector('.file-content .blob-content', count: 2, wait: 60)
      expect(page).to have_content(project1.full_path)
      expect(page).to have_content(project2.full_path)
      expect(page).not_to have_content(project3.full_path)
    end
  end

  context 'with group-level scope' do
    before do
      submit_search('username_regex')
    end

    it 'returns only results from the selected group' do
      expect(page).to have_selector('.file-content .blob-content', count: 3, wait: 60)
      expect(page).not_to have_content(project3.full_path)
    end

    context 'when switching to a different group' do
      before do
        choose_group(group2)
        wait_for_all_requests
      end

      it 'returns only results from the new group' do
        expect(page).to have_selector('.file-content .blob-content', count: 1, wait: 60)
        expect(page).to have_content(project3.full_path)
        expect(page).not_to have_content(project1.full_path)
        expect(page).not_to have_content(project2.full_path)
      end
    end
  end

  context 'when the user does not have the ability to read blob' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(anything, :read_blob, anything).and_return(false)
    end

    it 'does not show any search result' do
      submit_search('username_regex')

      expect(page).not_to have_selector('.file-content .blob-content')
    end
  end

  context 'with repo filter' do
    before do
      submit_search("repo:#{project1.path} username_regex")
      allow(::Search::Zoekt).to receive(:feature_available?).with(:repo_filter_search).and_return(true)
    end

    it 'searches only within the passed projects' do
      expect(page).to have_selector('.file-content .blob-content', count: 1, wait: 60)
      expect(page).to have_content(project1.full_path)
      expect(page).not_to have_content(project2.full_path)
    end
  end

  def choose_group(group)
    find_by_testid('group-filter').click
    wait_for_requests
    within_testid('group-filter') do
      select_listbox_item group.name
    end
  end

  def choose_project(project)
    find_by_testid('project-filter').click
    wait_for_requests
    within_testid('project-filter') do
      select_listbox_item project.name
    end
  end
end

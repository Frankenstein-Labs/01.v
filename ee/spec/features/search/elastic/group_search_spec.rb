# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group elastic search', :js, :elastic, :disable_rate_limiter,
  feature_category: :global_search do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :repository, :wiki_repo, group: group) }
  let_it_be(:group_wiki, freeze: false) { create(:group_wiki, group: group) }
  let_it_be(:wiki, freeze: false) { create(:project_wiki, project: project) }

  def choose_group(group)
    find_by_testid('group-filter').click
    wait_for_requests

    within_testid('group-filter') do
      select_listbox_item group.name
    end
  end

  context 'when searching for all scopes except issues and epics', :sidekiq_inline do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      project.repository.index_commits_and_blobs
      stub_licensed_features(group_wikis: true)

      Sidekiq::Worker.skipping_transaction_check do
        [group_wiki, wiki].each do |w|
          w.create_page('test.md', '# term')
          w.index_wiki_blobs
        end
      end
      ensure_elasticsearch_index!

      sign_in(user)
      visit(search_path)
      wait_for_requests
      choose_group(group)
    end

    it 'finds all the scopes' do
      # blobs
      submit_search('def')
      select_search_scope('Code')
      expect(page).to have_selector('.file-content .code')
      expect(page).to have_button('Copy file path')

      # commits
      submit_search('add')
      select_search_scope('Commits')
      expect(page).to have_selector('.commit-list > .commit')

      # wikis
      submit_search('term')
      select_search_scope('Wiki')
      expect(page).to have_selector('.search-result-row .description', text: 'term').twice
      expect(page).to have_link('test').twice
    end
  end

  context 'when we use work_items index for searching issues and epics' do
    let_it_be(:issue) { create(:work_item, project: project, title: 'chosen issue title') }
    let_it_be(:epic) do
      create(:work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: 'chosen epic title')
    end

    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      stub_licensed_features(epics: true)
      Elastic::ProcessBookkeepingService.track!(*[epic, issue])
      ensure_elasticsearch_index!
      sign_in(user)
      visit(search_path)
      wait_for_requests
      choose_group(group)
    end

    it 'finds epics and issues' do
      submit_search('chosen')
      select_search_scope('Work items')

      expect(page).to have_content('chosen epic title')
      expect(page).to have_content('chosen issue title')
    end
  end
end

RSpec.describe 'Group elastic search redactions', feature_category: :global_search do
  it_behaves_like 'a redacted search results page' do
    let(:search_path) { group_path(public_group) }
  end
end

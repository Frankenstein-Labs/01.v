# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User searches for epics', :js, :disable_rate_limiter, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }

  before do
    stub_licensed_features(epics: true)

    sign_in(user)

    visit(search_path(group_id: group.id))
  end

  include_examples 'top right search form'
  include_examples 'search timeouts', 'epics' do
    let(:additional_params) { { group_id: group.id } }
  end

  shared_examples 'searches for epics' do
    it 'finds an epic' do
      submit_search(epic1.title)
      select_search_scope('Work items')

      page.within('.results') do
        expect(page).to have_link(epic1.title)
        expect(page).to have_text('updated 6 days ago')
        expect(page).not_to have_link(epic2.title)
      end
    end

    it 'hides confidential icon for non-confidential epics' do
      submit_search(epic1.title)
      select_search_scope('Work items')

      page.within('.results') do
        expect(page).not_to have_css('[data-testid="eye-slash-icon"]')
      end
    end

    it 'shows confidential icon for confidential epics' do
      submit_search(epic2.title)
      select_search_scope('Work items')

      page.within('.results') do
        expect(page).to have_css('[data-testid="eye-slash-icon"]')
      end
    end

    it 'shows correct badge for open epics' do
      submit_search(epic1.title)
      select_search_scope('Work items')

      page.within('.results') do
        expect(page).to have_css('.badge-success')
        expect(page).not_to have_css('.badge-info')
      end
    end

    it 'shows correct badge for closed epics' do
      submit_search(epic2.title)
      select_search_scope('Work items')

      page.within('.results') do
        expect(page).not_to have_css('.badge-success')
        expect(page).to have_css('.badge-info')
      end
    end
  end

  context 'when advanced_search is enabled', :elastic do
    let_it_be(:epic1) do
      create(:work_item, :group_level, :epic_with_legacy_epic, title: 'Foo', namespace: group,
        updated_at: 6.days.ago)
    end

    let_it_be(:epic2) do
      create(:work_item, :group_level, :epic_with_legacy_epic, :closed, :confidential, title: 'Bar',
        namespace: group)
    end

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      Elastic::ProcessBookkeepingService.track!(*[epic1, epic2])
      ensure_elasticsearch_index!
    end

    include_examples 'searches for epics'

    context 'when advanced search syntax used in query' do
      it 'finds an epic' do
        submit_search("#{epic1.title}*")
        select_search_scope('Work items')

        page.within('.results') do
          expect(page).to have_link(epic1.title)
          expect(page).to have_text('updated 6 days ago')
          expect(page).not_to have_link(epic2.title)
        end
      end
    end
  end

  context 'when advanced_search is disabled' do
    let_it_be(:epic1) do
      create(:work_item, :group_level, :epic_with_legacy_epic, title: 'Foo', namespace: group,
        updated_at: 6.days.ago)
    end

    let_it_be(:epic2) do
      create(:work_item, :group_level, :epic_with_legacy_epic, :closed, :confidential, title: 'Bar',
        namespace: group)
    end

    before do
      stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
    end

    include_examples 'searches for epics'
  end
end

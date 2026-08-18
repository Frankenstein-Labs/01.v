# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User comments on epic', :js, feature_category: :portfolio_management do
  include Features::NotesHelpers

  let_it_be(:user) { create(:user, name: '💃speciąl someone💃', username: 'someone.special') }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:epic2) { create(:epic, group: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  context 'when adding comments' do
    it 'adds comment which is updated in real-time by other users' do
      visit group_epic_path(group, epic)

      using_session :other_session do
        visit group_epic_path(group, epic)

        # Ensures that discussions are loaded and the real-time subscription is initialized
        within_testid('work-item-sort') do
          expect(page).to have_selector('.gl-new-dropdown-toggle:not(.disabled)')
        end

        expect(page).not_to have_content('XML attached')
      end

      fill_in('Add a reply', with: 'XML attached')
      click_button 'Comment'

      page.within('.work-item-notes') do
        expect(page).to have_content('XML attached')
        expect(page).to be_axe_clean.within '.note'
      end

      using_session :other_session do
        expect(page).to have_content('XML attached')
      end
    end

    it 'links an issuable' do
      visit group_epic_path(group, epic)

      fill_in 'Add a reply', with: "#{epic2.to_reference(full: true)}+"
      click_button 'Comment'

      page.within('.work-item-notes') do
        expect(page).to have_link(epic2.title, href: /#{epic_path(epic2)}/)
        expect(page).to be_axe_clean.within '.md-preview-holder'
      end
    end
  end
end

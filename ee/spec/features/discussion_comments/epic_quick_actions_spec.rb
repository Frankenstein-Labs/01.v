# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic quick actions', :js, feature_category: :team_planning do
  include Features::NotesHelpers

  let(:user) { create(:user) }
  let(:group) { create(:group, developers: user) }
  let(:epic) { create(:epic, group: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)

    visit group_epic_path(group, epic)
  end

  context 'note with a quick action' do
    it 'previews a note with quick action' do
      fill_in('Add a reply', with: '/title New Title')
      click_button 'Preview'

      expect(page).to have_content('Changes the title to "New Title".')
    end

    it 'executes the quick action' do
      fill_in('Add a reply', with: '/title New Title')
      click_button 'Comment'

      expect(page).to have_content('Changed the title to "New Title".')

      page.refresh

      expect(page).to have_content('New Title')
    end
  end
end

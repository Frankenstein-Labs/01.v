# frozen_string_literal: true

require 'spec_helper'

# Epics quick actions functionality are covered on unit test specs. These
# are added just to test frontend features at least once, before adding more
# specs to this file please take into account if there is any behaviour
# different from the current ones that needs to be tested.
RSpec.describe 'Epics > User uses quick actions', :js, feature_category: :portfolio_management do
  include Features::NotesHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:epic_1) { create(:epic, group: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }

  before do
    stub_licensed_features(epics: true, subepics: true)
    sign_in(reporter)
  end

  context 'on epic note' do
    it 'applies quick action' do
      # TODO: remove threshold after epic-work item sync
      # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(140)
      epic_2 = create(:epic, group: group)
      visit group_epic_path(group, epic_2)

      fill_in('Add a reply', with: "new note \n\n/set_parent #{epic_1.to_reference}")
      click_button 'Comment'

      expect(page).to have_content("added #{epic_1.work_item.to_reference} as parent item")
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Upgrade links in user menu', :js, feature_category: :acquisition do
  context 'when eligible for upgrade on self managed', :enable_admin_mode do
    let_it_be(:user) { create(:admin) }

    before_all do
      create(:license, :ultimate_trial)
    end

    it 'shows the upgrade link' do
      sign_in(user)

      visit root_path

      find_by_testid('user-dropdown').click

      within_testid('user-dropdown') do
        expect(page).to have_button(s_('CurrentUser|Upgrade subscription'))
      end
    end
  end
end

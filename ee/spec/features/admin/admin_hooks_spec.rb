# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Hooks EE', feature_category: :webhooks do
  let_it_be(:user) { create(:admin) }

  before do
    sign_in(user)
    enable_admin_mode!(user)
  end

  describe 'New Hook', :js do
    let(:url) { generate(:url) }

    it 'renders EE hook events' do
      visit admin_hooks_path
      click_button 'Add new webhook'
      expect(page).to have_content('Member approval events')
    end

    it 'adds new Hook' do
      visit admin_hooks_path

      click_button 'Add new webhook'
      fill_in 'URL', with: url
      check 'Member approval events'

      expect do
        click_button 'Add webhook'

        expect(page).to have_current_path(admin_hooks_path, ignore_query: true)
        expect(page).to have_content(url)
      end.to change { SystemHook.count }.by(1)

      # Verify the checkbox is checked on the page
      visit admin_hooks_path
      click_link 'Edit'
      expect(page).to have_checked_field('Member approval events')
    end
  end
end
